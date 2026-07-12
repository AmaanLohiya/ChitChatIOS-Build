import UIKit

private struct GroupContactsSection {
    let title: String
    let contacts: [Contact]
}

private enum GroupCreationError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "The group could not be created. Please try again."
    }
}

private final class GroupContactAvatarView: UIView {
    private static let cache = NSCache<NSString, UIImage>()

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.contactsCard
        clipsToBounds = true

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        addSubview(initialsLabel)
        addSubview(imageView)
        initialsLabel.pinEdges(to: self)
        imageView.pinEdges(to: self)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func configure(contact: Contact) {
        imageTask?.cancel()
        imageView.image = nil
        imageView.isHidden = true
        initialsLabel.text = Self.initials(from: contact.name)

        let avatarValue = contact.avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !avatarValue.isEmpty, let url = APIClient.shared.resolvedURL(for: avatarValue) else {
            representedURL = nil
            return
        }

        let cacheKey = url.absoluteString
        representedURL = cacheKey
        if let cached = Self.cache.object(forKey: cacheKey as NSString) {
            imageView.image = cached
            imageView.isHidden = false
            return
        }

        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: cacheKey as NSString)
            DispatchQueue.main.async {
                guard self?.representedURL == cacheKey else { return }
                self?.imageView.image = image
                self?.imageView.isHidden = false
            }
        }
        imageTask?.resume()
    }

    func cancelImageLoad() {
        imageTask?.cancel()
        imageTask = nil
        representedURL = nil
    }

    private static func initials(from name: String) -> String {
        let value = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "C" : value
    }
}

private final class GroupMemberCell: UITableViewCell {
    static let reuseIdentifier = "GroupMemberCell"

    private let avatarView = GroupContactAvatarView()
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let selectionCircle = UIView()
    private let checkmark = UIImageView()
    private let divider = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelImageLoad()
    }

    private func buildUI() {
        backgroundColor = ChitChatColors.contactsScreen
        contentView.backgroundColor = ChitChatColors.contactsScreen
        selectionStyle = .none

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ChitChatTypography.contactsName
        nameLabel.textColor = ChitChatColors.textPrimary
        nameLabel.numberOfLines = 1

        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.font = ChitChatTypography.contactsStatus
        phoneLabel.textColor = ChitChatColors.textMuted
        phoneLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [nameLabel, phoneLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 2

        selectionCircle.translatesAutoresizingMaskIntoConstraints = false
        selectionCircle.layer.cornerRadius = 12
        selectionCircle.layer.borderWidth = 2

        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        )
        checkmark.tintColor = ChitChatColors.background
        checkmark.contentMode = .scaleAspectFit
        selectionCircle.addSubview(checkmark)

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.contactsRowBorder

        contentView.addSubview(avatarView)
        contentView.addSubview(textStack)
        contentView.addSubview(selectionCircle)
        contentView.addSubview(divider)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChitChatSpacing.contactsRowHorizontal
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsAvatar),
            avatarView.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsAvatar),

            textStack.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: ChitChatSpacing.contactsAvatarGap
            ),
            textStack.trailingAnchor.constraint(
                lessThanOrEqualTo: selectionCircle.leadingAnchor,
                constant: -12
            ),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: 19),
            phoneLabel.heightAnchor.constraint(equalToConstant: 16),

            selectionCircle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            selectionCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionCircle.widthAnchor.constraint(equalToConstant: 24),
            selectionCircle.heightAnchor.constraint(equalToConstant: 24),
            checkmark.centerXAnchor.constraint(equalTo: selectionCircle.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: selectionCircle.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 14),
            checkmark.heightAnchor.constraint(equalToConstant: 14),

            divider.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func configure(contact: Contact, isSelected: Bool) {
        avatarView.configure(contact: contact)
        nameLabel.text = contact.name
        phoneLabel.text = contact.phoneNumber
        selectionCircle.backgroundColor = isSelected ? ChitChatColors.accent : .clear
        selectionCircle.layer.borderColor = (
            isSelected ? ChitChatColors.accent : ChitChatColors.textMuted
        ).cgColor
        checkmark.isHidden = !isSelected
        accessibilityLabel = "\(contact.name), \(isSelected ? "selected" : "not selected")"
    }
}

final class GroupMemberSelectionViewController: BaseViewController {
    private static let minimumParticipantCount = 2

    private let currentUser: User
    private let contactService: ContactService
    private let chatService: ChatService
    private let onChatCreated: (Chat) -> Void

    private let searchContainer = UIView()
    private let searchField = UITextField()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var nextButton: UIBarButtonItem?

    private var contacts: [Contact] = []
    private var sections: [GroupContactsSection] = []
    private var selectedParticipantIDs: [String] = []
    private var loadTask: Task<Void, Never>?
    private var loadError: String?
    private var isLoading = false

    init(
        currentUser: User,
        contactService: ContactService = ContactService(),
        chatService: ChatService = ChatService(),
        onChatCreated: @escaping (Chat) -> Void
    ) {
        self.currentUser = currentUser
        self.contactService = contactService
        self.chatService = chatService
        self.onChatCreated = onChatCreated
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Group"
        view.backgroundColor = ChitChatColors.contactsScreen
        configureNavigation()
        configureSearch()
        configureTable()
        loadContacts()
    }

    deinit {
        loadTask?.cancel()
    }

    private func configureNavigation() {
        let button = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(showGroupDetails))
        button.tintColor = ChitChatColors.accent
        button.isEnabled = false
        navigationItem.rightBarButtonItem = button
        nextButton = button
    }

    private func configureSearch() {
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.backgroundColor = ChitChatColors.contactsSearch
        searchContainer.layer.cornerRadius = ChitChatSpacing.contactsSearchRadius
        searchContainer.layer.cornerCurve = .continuous

        let icon = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
            )
        )
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.textMuted
        icon.contentMode = .scaleAspectFit

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.backgroundColor = .clear
        searchField.textColor = ChitChatColors.textPrimary
        searchField.tintColor = ChitChatColors.accent
        searchField.font = ChitChatTypography.contactsSearch
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search contacts...",
            attributes: [.foregroundColor: ChitChatColors.chatsPlaceholder]
        )
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = ChitChatTypography.contactsStatus
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.numberOfLines = 2

        view.addSubview(searchContainer)
        searchContainer.addSubview(icon)
        searchContainer.addSubview(searchField)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsSearchHeight),

            icon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -14),
            searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 2),
            statusLabel.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -2)
        ])
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = ChitChatColors.contactsScreen
        tableView.separatorStyle = .none
        tableView.rowHeight = ChitChatSpacing.contactsRowHeight
        tableView.estimatedRowHeight = ChitChatSpacing.contactsRowHeight
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(GroupMemberCell.self, forCellReuseIdentifier: GroupMemberCell.reuseIdentifier)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        let refresh = UIRefreshControl()
        refresh.tintColor = ChitChatColors.accent
        refresh.addTarget(self, action: #selector(refreshContacts), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func loadContacts() {
        guard loadTask == nil else { return }
        isLoading = true
        loadError = nil
        updateState()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await contactService.listContacts()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.contacts = self.validContacts(from: loaded)
                    let validIDs = Set(self.contacts.compactMap(\.contactUserId))
                    self.selectedParticipantIDs.removeAll { !validIDs.contains($0) }
                    self.isLoading = false
                    self.loadError = nil
                    self.loadTask = nil
                    self.applySearch()
                    self.tableView.refreshControl?.endRefreshing()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.contacts = []
                    self.sections = []
                    self.isLoading = false
                    self.loadError = error.localizedDescription
                    self.loadTask = nil
                    self.tableView.reloadData()
                    self.tableView.refreshControl?.endRefreshing()
                    self.updateState()
                }
            }
        }
    }

    private func validContacts(from loaded: [Contact]) -> [Contact] {
        var seenUserIDs = Set<String>()
        return loaded
            .filter { contact in
                guard
                    !contact.isBlocked,
                    let userID = contact.contactUserId,
                    userID != currentUser.id,
                    seenUserIDs.insert(userID).inserted
                else {
                    return false
                }
                return true
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applySearch() {
        let query = searchField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let filtered = contacts.filter { contact in
            query.isEmpty
                || contact.name.lowercased().contains(query)
                || contact.phoneNumber.lowercased().contains(query)
        }

        var grouped: [String: [Contact]] = [:]
        filtered.forEach { contact in
            let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.first.map { String($0).uppercased() } ?? "#"
            grouped[key, default: []].append(contact)
        }
        sections = grouped.keys.sorted().map {
            GroupContactsSection(title: $0, contacts: grouped[$0] ?? [])
        }
        tableView.reloadData()
        updateState()
    }

    private func updateState() {
        let count = selectedParticipantIDs.count
        nextButton?.isEnabled = count >= Self.minimumParticipantCount

        if isLoading {
            statusLabel.textColor = ChitChatColors.textMuted
            statusLabel.text = "Loading contacts..."
        } else if let loadError, !loadError.isEmpty {
            statusLabel.textColor = ChitChatColors.danger
            statusLabel.text = loadError
        } else {
            statusLabel.textColor = ChitChatColors.textMuted
            statusLabel.text = "\(count) selected - select at least \(Self.minimumParticipantCount)"
        }

        if sections.isEmpty, !isLoading {
            let label = UILabel()
            label.text = contacts.isEmpty ? "No ChitChat contacts available" : "No contacts found"
            label.textColor = ChitChatColors.textMuted
            label.font = ChitChatTypography.contactsEmptyText
            label.textAlignment = .center
            label.numberOfLines = 0
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    private func toggleSelection(for contact: Contact) {
        guard let participantID = contact.contactUserId, participantID != currentUser.id else { return }
        if let index = selectedParticipantIDs.firstIndex(of: participantID) {
            selectedParticipantIDs.remove(at: index)
        } else {
            selectedParticipantIDs.append(participantID)
        }
        tableView.reloadData()
        updateState()
    }

    @objc private func searchChanged() {
        applySearch()
    }

    @objc private func refreshContacts() {
        loadContacts()
    }

    @objc private func showGroupDetails() {
        dismissKeyboard()
        let selectedSet = Set(selectedParticipantIDs)
        let selectedContacts = contacts.filter {
            guard let participantID = $0.contactUserId else { return false }
            return selectedSet.contains(participantID)
        }
        guard selectedContacts.count >= Self.minimumParticipantCount else {
            showAlert(message: "Select at least 2 contacts to create a group.")
            return
        }

        let controller = GroupDetailsViewController(
            currentUser: currentUser,
            selectedContacts: selectedContacts,
            chatService: chatService,
            onChatCreated: onChatCreated
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension GroupMemberSelectionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension GroupMemberSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].contacts.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.contentView.backgroundColor = ChitChatColors.contactsCard
        header.textLabel?.textColor = ChitChatColors.accent
        header.textLabel?.font = ChitChatTypography.contactsSection
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: GroupMemberCell.reuseIdentifier,
            for: indexPath
        ) as? GroupMemberCell else {
            return UITableViewCell()
        }
        let contact = sections[indexPath.section].contacts[indexPath.row]
        let selected = contact.contactUserId.map { selectedParticipantIDs.contains($0) } ?? false
        cell.configure(contact: contact, isSelected: selected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        toggleSelection(for: sections[indexPath.section].contacts[indexPath.row])
    }
}

final class GroupDetailsViewController: BaseViewController {
    private static let minimumParticipantCount = 2
    private static let maximumNameLength = 80

    private let currentUser: User
    private let selectedContacts: [Contact]
    private let chatService: ChatService
    private let onChatCreated: (Chat) -> Void

    private let nameField = RoundedTextField(placeholder: "Group name")
    private let countLabel = UILabel()
    private let errorLabel = UILabel()
    private let createButton = PrimaryButton(title: "Create group")
    private var createTask: Task<Void, Never>?
    private var isCreating = false

    init(
        currentUser: User,
        selectedContacts: [Contact],
        chatService: ChatService,
        onChatCreated: @escaping (Chat) -> Void
    ) {
        self.currentUser = currentUser
        self.selectedContacts = selectedContacts
        self.chatService = chatService
        self.onChatCreated = onChatCreated
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Group details"
        view.backgroundColor = ChitChatColors.authBackground
        buildUI()
        updateCreateState()
    }

    deinit {
        createTask?.cancel()
    }

    private var participantIDs: [String] {
        var seen = Set<String>()
        return selectedContacts.compactMap { contact in
            guard
                let userID = contact.contactUserId,
                userID != currentUser.id,
                seen.insert(userID).inserted
            else {
                return nil
            }
            return userID
        }
    }

    private func buildUI() {
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)

        nameField.autocapitalizationType = .words
        nameField.autocorrectionType = .yes
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        let instruction = UILabel()
        instruction.text = "Choose a name for this group."
        instruction.font = ChitChatTypography.body
        instruction.textColor = ChitChatColors.textMuted
        instruction.numberOfLines = 0

        countLabel.font = ChitChatTypography.caption
        countLabel.textColor = ChitChatColors.textMuted
        countLabel.textAlignment = .right
        countLabel.text = "0/\(Self.maximumNameLength)"

        let membersCard = UIView()
        membersCard.backgroundColor = ChitChatColors.surface
        membersCard.layer.cornerRadius = ChitChatSpacing.cardRadius
        membersCard.layer.borderWidth = 1
        membersCard.layer.borderColor = ChitChatColors.border.cgColor

        let membersTitle = UILabel()
        membersTitle.translatesAutoresizingMaskIntoConstraints = false
        membersTitle.text = "\(participantIDs.count) members selected"
        membersTitle.font = ChitChatTypography.bodySemibold
        membersTitle.textColor = ChitChatColors.textPrimary

        let memberNames = UILabel()
        memberNames.translatesAutoresizingMaskIntoConstraints = false
        memberNames.text = selectedContacts.map(\.name).joined(separator: ", ")
        memberNames.font = ChitChatTypography.body
        memberNames.textColor = ChitChatColors.textMuted
        memberNames.numberOfLines = 0

        membersCard.addSubview(membersTitle)
        membersCard.addSubview(memberNames)
        NSLayoutConstraint.activate([
            membersTitle.topAnchor.constraint(equalTo: membersCard.topAnchor, constant: 18),
            membersTitle.leadingAnchor.constraint(equalTo: membersCard.leadingAnchor, constant: 18),
            membersTitle.trailingAnchor.constraint(equalTo: membersCard.trailingAnchor, constant: -18),
            memberNames.topAnchor.constraint(equalTo: membersTitle.bottomAnchor, constant: 8),
            memberNames.leadingAnchor.constraint(equalTo: membersCard.leadingAnchor, constant: 18),
            memberNames.trailingAnchor.constraint(equalTo: membersCard.trailingAnchor, constant: -18),
            memberNames.bottomAnchor.constraint(equalTo: membersCard.bottomAnchor, constant: -18)
        ])

        errorLabel.font = ChitChatTypography.caption
        errorLabel.textColor = ChitChatColors.danger
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [instruction, nameField, countLabel, membersCard, errorLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(stack)

        createButton.addTarget(self, action: #selector(createGroup), for: .touchUpInside)

        view.addSubview(scrollView)
        view.addSubview(createButton)

        let keyboardBottom = createButton.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -16
        )
        keyboardBottom.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: ChitChatSpacing.screenHorizontal
            ),
            stack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -ChitChatSpacing.screenHorizontal
            ),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),

            createButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: ChitChatSpacing.screenHorizontal
            ),
            createButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -ChitChatSpacing.screenHorizontal
            ),
            createButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
            keyboardBottom
        ])
    }

    private func updateCreateState() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        countLabel.text = "\((nameField.text ?? "").count)/\(Self.maximumNameLength)"
        createButton.isEnabled = !isCreating
            && !name.isEmpty
            && name.count <= Self.maximumNameLength
            && participantIDs.count >= Self.minimumParticipantCount
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message?.isEmpty ?? true
    }

    @objc private func nameChanged() {
        setError(nil)
        updateCreateState()
    }

    @objc private func createGroup() {
        dismissKeyboard()
        guard !isCreating, createTask == nil else { return }

        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let participants = participantIDs
        guard !name.isEmpty else {
            setError("Group name is required.")
            return
        }
        guard name.count <= Self.maximumNameLength else {
            setError("Group name cannot exceed 80 characters.")
            return
        }
        guard participants.count >= Self.minimumParticipantCount else {
            setError("Select at least 2 contacts to create a group.")
            return
        }

        isCreating = true
        setError(nil)
        createButton.setTitle("Creating...", for: .normal)
        updateCreateState()

        createTask = Task { [weak self] in
            guard let self else { return }
            do {
                let chat = try await chatService.createGroupChat(
                    name: name,
                    participantUserIds: participants
                )
                guard !Task.isCancelled else { return }
                guard chat.type == .group, !chat.id.isEmpty else {
                    throw GroupCreationError.invalidResponse
                }
                await MainActor.run {
                    self.finishCreation(chat)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isCreating = false
                    self.createTask = nil
                    self.createButton.setTitle("Create group", for: .normal)
                    self.setError(error.localizedDescription)
                    self.updateCreateState()
                }
            }
        }
    }

    private func finishCreation(_ chat: Chat) {
        isCreating = false
        createTask = nil
        createButton.setTitle("Create group", for: .normal)
        onChatCreated(chat)

        let detail = ChatDetailViewController(chat: chat, currentUser: currentUser)
        guard let navigationController else { return }
        let preservedStack = navigationController.viewControllers.filter {
            !($0 is GroupMemberSelectionViewController) && !($0 is GroupDetailsViewController)
        }
        if preservedStack.isEmpty {
            navigationController.pushViewController(detail, animated: true)
        } else {
            navigationController.setViewControllers(preservedStack + [detail], animated: true)
        }
    }
}

extension GroupDetailsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard
            let current = textField.text,
            let textRange = Range(range, in: current)
        else {
            return false
        }
        return current.replacingCharacters(in: textRange, with: string).count <= Self.maximumNameLength
    }
}
