import UIKit
import PhotosUI

@MainActor
final class GroupInfoViewController: UITableViewController, PHPickerViewControllerDelegate {
    private var chat: Chat
    private let userID: String
    private let service = ChatService()
    private var observers: [NSObjectProtocol] = []
    private var task: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var busy = false
    private var generation = UUID()

    init(chat: Chat, userID: String) {
        self.chat = chat
        self.userID = userID
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Group Info"
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorColor = ChitChatColors.divider
        tableView.register(GroupProfileCell.self, forCellReuseIdentifier: "profile")
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshGroup), for: .valueChanged)
        observers.append(NotificationCenter.default.addObserver(forName: .socketChatUpdated, object: nil, queue: .main) { [weak self] note in
            guard let self, let updated = note.object as? Chat, updated.id == self.chat.id else { return }
            self.generation = UUID()
            self.apply(updated)
        })
        for event in [Notification.Name.socketConnected, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in self?.refreshGroup() })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshGroup()
    }

    deinit {
        task?.cancel()
        loadTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    @objc private func refreshGroup() {
        guard !busy else { return }
        loadTask?.cancel()
        let token = UUID()
        generation = token
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshControl?.endRefreshing() }
            do {
                let updated = try await service.getGroup(id: chat.id)
                guard !Task.isCancelled, generation == token else { return }
                apply(updated)
            } catch {
                guard !Task.isCancelled, generation == token else { return }
                if case APIClientError.server(let code, _) = error, code == "CHAT_NOT_FOUND" { closeGroup(); return }
                showError(error.localizedDescription)
            }
        }
    }

    private func apply(_ updated: Chat) {
        guard updated.isActiveMember(userID) else { closeGroup(); return }
        chat = updated
        tableView.reloadData()
    }

    private func closeGroup() {
        task?.cancel()
        loadTask?.cancel()
        SocketService.shared.leaveChat(chat.id)
        if presentedViewController != nil { dismiss(animated: false) }
        navigationController?.popToRootViewController(animated: true)
    }

    private func run(_ operation: @escaping () async throws -> Chat) {
        guard !busy else { return }
        busy = true
        loadTask?.cancel()
        generation = UUID()
        navigationItem.prompt = "Saving..."
        tableView.reloadData()
        task = Task { [weak self] in
            guard let self else { return }
            defer { busy = false; navigationItem.prompt = nil; tableView.reloadData(); task = nil }
            do {
                let updated = try await operation()
                guard !Task.isCancelled else { return }
                NotificationCenter.default.post(name: .socketChatUpdated, object: updated)
            } catch {
                if !Task.isCancelled { showError(error.localizedDescription) }
            }
        }
    }

    private var actions: [String] { chat.canManageGroup(userID) ? ["Edit group name", "Change group photo", "Add members"] : [] }
    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section { case 0, 3: return 1; case 1: return actions.count; default: return chat.activeMembers.count }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 2 ? "Members" : nil }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "\(chat.activeMembers.count) members. Only the owner or admins can edit this group and add members." : nil
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { indexPath.section == 0 ? 100 : 64 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 || indexPath.section == 2 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "profile", for: indexPath) as? GroupProfileCell else { return UITableViewCell() }
            if indexPath.section == 0 { cell.configure(name: chat.name, detail: "Group", avatar: chat.avatarUrl) }
            else {
                let member = chat.activeMembers[indexPath.row]
                let role = ["owner", "admin", "member"].contains(member.role) ? member.role.capitalized : "Member"
                cell.configure(name: member.user?.name ?? "ChitChat user", detail: role + (member.userId == userID ? " - You" : ""), avatar: member.user?.avatarUrl ?? "")
                cell.accessoryType = memberActions(member).isEmpty ? .none : .disclosureIndicator
            }
            return cell
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = ChitChatColors.surface
        cell.textLabel?.text = indexPath.section == 3 ? "Leave Group" : actions[indexPath.row]
        cell.textLabel?.textColor = indexPath.section == 3 ? ChitChatColors.danger : ChitChatColors.accent
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cell.isUserInteractionEnabled = !busy
        cell.contentView.alpha = busy ? 0.5 : 1
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy else { return }
        if indexPath.section == 3 { confirmLeave(); return }
        if indexPath.section == 2, chat.activeMembers.indices.contains(indexPath.row) {
            showMemberMenu(chat.activeMembers[indexPath.row]); return
        }
        guard indexPath.section == 1, chat.canManageGroup(userID) else { return }
        switch indexPath.row { case 0: editName(); case 1: selectPhoto(); default: addMembers() }
    }

    private func editName() {
        let alert = UIAlertController(title: "Edit group name", message: "1 to 80 characters", preferredStyle: .alert)
        alert.addTextField { [chat] field in field.text = chat.name; field.autocapitalizationType = .sentences }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, name.utf16.count <= 80 else { self.showError("Enter a group name of 1 to 80 characters."); return }
            self.run { try await self.service.updateGroup(id: self.chat.id, input: UpdateGroupRequest(name: name)) }
        })
        present(alert, animated: true)
    }

    private func selectPhoto() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let self, self.viewIfLoaded?.window != nil else { return }
                    guard let image = object as? UIImage else { self.showError("Could not open that image."); return }
                    let preview = GroupPhotoPreviewController(image: image) { [weak self] image in self?.uploadPhoto(image) }
                    self.present(UINavigationController(rootViewController: preview), animated: true)
                }
            }
        }
    }
    private func uploadPhoto(_ image: UIImage) {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.82), data.count <= 5 * 1024 * 1024 else { showError("Choose an image smaller than 5 MB."); return }
        run { [self] in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("group-\(UUID().uuidString).jpg")
            try data.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            let upload = try await UploadService().uploadLocalFile(fileURL: url, fileName: "group.jpg", mimeType: "image/jpeg", usage: .group, resourceType: .image, progress: { [weak self] value in self?.navigationItem.prompt = "Uploading \(Int(value * 100))%" })
            return try await service.updateGroup(id: chat.id, input: UpdateGroupRequest(avatarUploadId: upload.id))
        }
    }
    private func addMembers() {
        let controller = GroupAddMembersViewController(excludedIDs: Set(chat.activeMembers.map(\.userId)).union([userID]))
        controller.onAdd = { [weak self] ids in
            guard let self else { throw APIClientError.invalidResponse }
            let updated = try await self.service.addGroupMembers(id: self.chat.id, userIDs: ids)
            self.apply(updated)
            NotificationCenter.default.post(name: .socketChatUpdated, object: updated)
        }
        present(UINavigationController(rootViewController: controller), animated: true)
    }
    private func confirmLeave() {
        if chat.activeMembers.first(where: { $0.userId == userID })?.role == "owner" {
            let candidates = chat.activeMembers.filter { $0.userId != userID }
            guard !candidates.isEmpty else { showError("You are the only active member. Empty groups cannot be archived automatically."); return }
            let sheet = UIAlertController(title: "Choose the next owner", message: "Transfer ownership before leaving this group.", preferredStyle: .actionSheet)
            for member in candidates {
                sheet.addAction(UIAlertAction(title: member.user?.name ?? "ChitChat user", style: .default) { [weak self] _ in
                    self?.confirmAdministration(member, action: "owner-leave")
                })
            }
            presentSheet(sheet); return
        }
        let alert = UIAlertController(title: "Leave this group?", message: "You will no longer receive its messages.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave Group", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.run { try await self.service.leaveGroup(id: self.chat.id).chat }
        })
        present(alert, animated: true)
    }
    private func memberActions(_ member: ChatParticipant) -> [String] {
        guard member.userId != userID, member.role != "owner" else { return [] }
        let role = chat.activeMembers.first(where: { $0.userId == userID })?.role
        if role == "owner" { return [member.role == "admin" ? "demote" : "promote", "remove", "transfer-owner"] }
        return role == "admin" && member.role == "member" ? ["remove"] : []
    }
    private func actionTitle(_ action: String) -> String {
        switch action {
        case "promote": return "Make admin"
        case "demote": return "Remove as admin"
        case "remove": return "Remove from group"
        case "owner-leave": return "Transfer and leave"
        default: return "Transfer ownership"
        }
    }
    private func presentSheet(_ sheet: UIAlertController) {
        guard !busy, presentedViewController == nil else { return }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }
    private func showMemberMenu(_ member: ChatParticipant) {
        let actions = memberActions(member)
        guard !actions.isEmpty else { return }
        let sheet = UIAlertController(title: member.user?.name ?? "Member", message: "Group administration", preferredStyle: .actionSheet)
        for action in actions {
            sheet.addAction(UIAlertAction(title: actionTitle(action), style: action == "remove" ? .destructive : .default) { [weak self] _ in
                self?.confirmAdministration(member, action: action)
            })
        }
        presentSheet(sheet)
    }
    private func confirmAdministration(_ member: ChatParticipant, action: String) {
        guard !busy else { return }
        let name = member.user?.name ?? "this member"
        let question: String
        switch action {
        case "promote": question = "Make \(name) an admin?"
        case "demote": question = "Remove \(name) as an admin?"
        case "remove": question = "Remove \(name) from this group?"
        case "owner-leave": question = "Transfer ownership to \(name) and leave this group?"
        default: question = "Transfer group ownership to \(name)? You will become an admin."
        }
        let alert = UIAlertController(title: question, message: "This change will be visible to the group.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle(action), style: action == "remove" || action == "owner-leave" ? .destructive : .default) { [weak self] _ in
            guard let self else { return }
            self.run { try await self.service.administerGroup(id: self.chat.id, userID: member.userId, action: action) }
        })
        // Wait for the member action sheet to finish dismissing before confirmation.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.viewIfLoaded?.window != nil else { return }
            if let presented = self.presentedViewController { presented.dismiss(animated: true) { self.present(alert, animated: true) } }
            else { self.present(alert, animated: true) }
        }
    }
    private func showError(_ message: String) {
        guard presentedViewController == nil else { navigationItem.prompt = message; return }
        let alert = UIAlertController(title: "Group Info", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class GroupProfileCell: UITableViewCell {
    private let avatar = UIImageView()
    private let initials = UILabel()
    private var task: URLSessionDataTask?
    private var identity = UUID()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundColor = ChitChatColors.surface
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill; avatar.clipsToBounds = true; avatar.layer.cornerRadius = 24
        avatar.backgroundColor = ChitChatColors.backgroundAlt
        initials.translatesAutoresizingMaskIntoConstraints = false; initials.textColor = ChitChatColors.accent
        initials.font = .systemFont(ofSize: 17, weight: .bold); initials.textAlignment = .center
        contentView.addSubview(avatar); avatar.addSubview(initials)
        NSLayoutConstraint.activate([avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16), avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor), avatar.widthAnchor.constraint(equalToConstant: 48), avatar.heightAnchor.constraint(equalToConstant: 48), initials.centerXAnchor.constraint(equalTo: avatar.centerXAnchor), initials.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)])
    }
    required init?(coder: NSCoder) { return nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        textLabel?.frame.origin.x = 78; detailTextLabel?.frame.origin.x = 78
        textLabel?.frame.size.width = max(0, contentView.bounds.width - 94)
        detailTextLabel?.frame.size.width = max(0, contentView.bounds.width - 94)
    }
    override func prepareForReuse() { super.prepareForReuse(); task?.cancel(); identity = UUID(); avatar.image = nil }
    deinit { task?.cancel() }
    func configure(name: String, detail: String, avatar value: String) {
        task?.cancel(); identity = UUID(); let token = identity
        avatar.image = nil; initials.isHidden = false
        initials.text = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        textLabel?.text = name; textLabel?.textColor = ChitChatColors.textPrimary
        detailTextLabel?.text = detail; detailTextLabel?.textColor = ChitChatColors.textMuted
        selectionStyle = .none
        guard !value.isEmpty, let url = APIClient.shared.resolvedURL(for: value) else { return }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { guard let self, self.identity == token else { return }; self.avatar.image = image; self.initials.isHidden = true }
        }; task?.resume()
    }
}

@MainActor
private final class GroupAddMembersViewController: UITableViewController, UISearchResultsUpdating {
    let excludedIDs: Set<String>
    var onAdd: (([String]) async throws -> Void)?
    private var contacts: [Contact] = []
    private var selected = Set<String>()
    private let search = UISearchController(searchResultsController: nil)
    private var task: Task<Void, Never>?
    private var busy = false
    init(excludedIDs: Set<String>) { self.excludedIDs = excludedIDs; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel() }
    private var filtered: [Contact] { let q = search.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; return contacts.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) } }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Add members"; tableView.backgroundColor = ChitChatColors.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(add))
        search.searchResultsUpdater = self; search.obscuresBackgroundDuringPresentation = false; navigationItem.searchController = search
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(load), for: .valueChanged)
        load()
    }
    @objc private func load() {
        guard !busy else { return }; task?.cancel(); navigationItem.prompt = "Loading contacts..."
        task = Task { [weak self] in
            guard let self else { return }
            defer { refreshControl?.endRefreshing() }
            do {
                let values = try await ContactService().listContacts(); guard !Task.isCancelled else { return }
                var seen = excludedIDs
                contacts = values.filter { contact in guard !contact.isBlocked, let id = contact.contactUserId, seen.insert(id).inserted else { return false }; return true }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                selected.formIntersection(contacts.compactMap(\.contactUserId))
                navigationItem.prompt = contacts.isEmpty ? "No eligible contacts available." : "Select contacts, then Add."
                tableView.reloadData()
            } catch { if !Task.isCancelled { navigationItem.prompt = "Could not load contacts. Pull to retry." } }
        }
    }
    @objc private func cancel() { guard !busy else { return }; dismiss(animated: true) }
    func updateSearchResults(for searchController: UISearchController) { tableView.reloadData() }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contact = filtered[indexPath.row]; let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = contact.name; cell.textLabel?.textColor = ChitChatColors.textPrimary; cell.backgroundColor = ChitChatColors.surface
        cell.accessoryType = selected.contains(contact.contactUserId ?? "") ? .checkmark : .none; cell.tintColor = ChitChatColors.accent
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !busy, let id = filtered[indexPath.row].contactUserId else { return }
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }; tableView.reloadData()
        navigationItem.rightBarButtonItem?.title = "Add (\(selected.count))"
    }
    @objc private func add() {
        guard !busy, !selected.isEmpty, let onAdd else { return }
        let alert = UIAlertController(title: "Add \(selected.count) members?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self, !self.busy else { return }; self.busy = true; self.isModalInPresentation = true
            self.navigationItem.rightBarButtonItem?.isEnabled = false; self.navigationItem.prompt = "Adding members..."
            self.task?.cancel()
            self.task = Task { [weak self] in
                guard let self else { return }
                defer { busy = false; isModalInPresentation = false; navigationItem.rightBarButtonItem?.isEnabled = true }
                do { try await onAdd(Array(selected)); dismiss(animated: true) }
                catch { navigationItem.prompt = error.localizedDescription }
            }
        }); present(alert, animated: true)
    }
}

@MainActor
private final class GroupPhotoPreviewController: UIViewController {
    private let image: UIImage
    private let onSave: (UIImage) -> Void
    init(image: UIImage, onSave: @escaping (UIImage) -> Void) { self.image = image; self.onSave = onSave; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { return nil }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Use this group photo?"; view.backgroundColor = ChitChatColors.background
        let photo = UIImageView(image: image); photo.contentMode = .scaleAspectFit; photo.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(photo)
        NSLayoutConstraint.activate([photo.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16), photo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16), photo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), photo.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)])
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))
    }
    @objc private func cancel() { dismiss(animated: true) }
    @objc private func save() { let callback = onSave; let selected = image; navigationItem.rightBarButtonItem?.isEnabled = false; dismiss(animated: true) { callback(selected) } }
}
