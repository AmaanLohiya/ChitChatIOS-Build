import UIKit

@MainActor
final class ForwardMessageViewController: UITableViewController, UISearchResultsUpdating {
    private let message: Message
    private let userID: String
    private let clientForwardId = UUID().uuidString
    private let search = UISearchController(searchResultsController: nil)
    private var chats: [Chat] = []
    private var selected = Set<String>()
    private var sent = Set<String>()
    private var started = false
    private var busy = false
    private var task: Task<Void, Never>?
    private var filtered: [Chat] {
        let query = (search.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return chats.filter { query.isEmpty || $0.displayName(viewerUserId: userID).localizedCaseInsensitiveContains(query) }
    }

    init(message: Message, userID: String) {
        self.message = message
        self.userID = userID
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Forward message"
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = 72
        let empty = UILabel()
        empty.text = "No matching chats. Pull to refresh."
        empty.textColor = ChitChatColors.textMuted
        empty.textAlignment = .center
        empty.numberOfLines = 0
        tableView.backgroundView = empty
        empty.isHidden = true
        tableView.register(ForwardDestinationCell.self, forCellReuseIdentifier: "destination")
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search chats"
        navigationItem.searchController = search
        definesPresentationContext = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Forward", style: .done, target: self, action: #selector(send))
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(load), for: .valueChanged)
        updateControls()
        load()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { task?.cancel() }
    }

    @objc private func load() {
        guard !busy else { return }
        task?.cancel()
        navigationItem.prompt = "Loading chats..."
        task = Task { [weak self] in
            guard let self else { return }
            defer { refreshControl?.endRefreshing() }
            do {
                let values = try await ChatService().listChats()
                guard !Task.isCancelled else { return }
                var seen = Set<String>()
                chats = values.filter { $0.isActiveMember(userID) && seen.insert($0.id).inserted }
                if !started { selected.formIntersection(chats.map(\.id)) }
                tableView.reloadData()
                updateControls()
                if chats.isEmpty { navigationItem.prompt = "No chats available. Pull to retry." }
            } catch { if !Task.isCancelled { navigationItem.prompt = "Could not load chats. Pull to retry." } }
        }
    }
    @objc private func cancel() { guard !busy else { return }; dismiss(animated: true) }
    func updateSearchResults(for searchController: UISearchController) { tableView.reloadData() }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.backgroundView?.isHidden = !filtered.isEmpty
        return filtered.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard filtered.indices.contains(indexPath.row), let cell = tableView.dequeueReusableCell(withIdentifier: "destination", for: indexPath) as? ForwardDestinationCell else { return UITableViewCell() }
        let chat = filtered[indexPath.row]
        cell.configure(chat: chat, userID: userID, selected: selected.contains(chat.id), sent: sent.contains(chat.id))
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, !started, filtered.indices.contains(indexPath.row) else { return }
        let id = filtered[indexPath.row].id
        if selected.contains(id) { selected.remove(id) }
        else if selected.count < 10 { selected.insert(id) }
        else { navigationItem.prompt = "Choose at most 10 chats."; return }
        tableView.reloadData()
        updateControls()
    }
    private func updateControls() {
        navigationItem.prompt = "\(selected.count) / 10 selected" + (started ? " - selection locked for retry" : "")
        navigationItem.rightBarButtonItem?.title = busy ? "Sending..." : started ? "Retry" : "Forward"
        navigationItem.rightBarButtonItem?.isEnabled = !busy && !selected.isEmpty
        navigationItem.leftBarButtonItem?.isEnabled = !busy
        isModalInPresentation = busy
        navigationController?.isModalInPresentation = busy
    }
    @objc private func send() {
        guard !busy, !selected.isEmpty, selected.count <= 10,
              SessionManager.shared.authenticatedUser?.id == userID else { return }
        busy = true
        started = true
        task?.cancel()
        updateControls()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await MessageService().forward(chatId: message.chatId, messageId: message.id,
                                                                 targetChatIds: selected.sorted(), clientForwardId: clientForwardId)
                guard !Task.isCancelled else { return }
                sent = Set(response.results.filter { $0.status == "sent" && selected.contains($0.chatId) }.map(\.chatId))
                busy = false
                updateControls()
                tableView.reloadData()
                if sent == selected { dismiss(animated: true) }
                else { showResult("\(sent.count) of \(selected.count) sent. Other chats may be unavailable. Retry will not duplicate successful sends.") }
            } catch {
                guard !Task.isCancelled else { return }
                busy = false
                updateControls()
                showResult("Forward not confirmed. Retry safely, or close. Some destinations may already have received it.")
            }
        }
    }
    private func showResult(_ text: String) {
        let alert = UIAlertController(title: "Forward message", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class ForwardDestinationCell: UITableViewCell {
    private let avatar = ReplicaAvatarView()
    private let name = UILabel()
    private let detail = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        name.font = .systemFont(ofSize: 16, weight: .semibold)
        name.textColor = ChitChatColors.textPrimary
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = ChitChatColors.textMuted
        let labels = UIStackView(arrangedSubviews: [name, detail])
        labels.axis = .vertical; labels.spacing = 3; labels.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar); contentView.addSubview(labels)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 44), avatar.heightAnchor.constraint(equalToConstant: 44),
            labels.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            labels.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        backgroundColor = ChitChatColors.surface; tintColor = ChitChatColors.accent
    }
    required init?(coder: NSCoder) { return nil }
    func configure(chat: Chat, userID: String, selected: Bool, sent: Bool) {
        name.text = chat.displayName(viewerUserId: userID)
        detail.text = sent ? "Sent" : chat.type == .group ? "Group" : "Direct chat"
        avatar.configure(name: name.text ?? "Chat", urlString: chat.displayAvatarURL(viewerUserId: userID))
        accessoryType = selected ? .checkmark : .none
        accessibilityLabel = "\(name.text ?? "Chat"), \(selected ? "selected" : "not selected")"
    }
}
