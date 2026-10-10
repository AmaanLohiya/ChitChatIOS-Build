import UIKit

private struct GlobalSearchResult: Decodable {
    let id: String
    let category: String
    let title: String
    let subtitle: String
    let avatarUrl: String?
    let chatId: String?
    let personId: String?
    let messageId: String?
    let senderName: String?
    let createdAt: String?
    let type: String?
}
private struct GlobalSearchPage: Decodable {
    let items: [GlobalSearchResult]
    let nextCursor: String?
}

@MainActor
final class GlobalSearchViewController: UITableViewController, UISearchResultsUpdating, UISearchBarDelegate {
    private let userID: String
    private let onOpen: (Chat, String?) -> Void
    private let search = UISearchController(searchResultsController: nil)
    private let notice = UILabel()
    private let categories = ["chats", "people", "messages"]
    private var filter = "all"
    private var pages: [String: GlobalSearchPage] = [:]
    private var revision = 0
    private var busy = false
    private var opening = false
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == userID }
    private var sections: [String] { filter == "all" ? categories : [filter] }

    init(userID: String, onOpen: @escaping (Chat, String?) -> Void) {
        self.userID = userID; self.onOpen = onOpen
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search ChitChat"
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 100
        tableView.keyboardDismissMode = .onDrag
        tableView.register(GlobalSearchCell.self, forCellReuseIdentifier: "global-result")
        notice.numberOfLines = 0; notice.textAlignment = .center; notice.textColor = ChitChatColors.textMuted
        tableView.backgroundView = notice
        search.searchResultsUpdater = self; search.searchBar.delegate = self
        search.searchBar.placeholder = "Chats, known people, messages"
        search.searchBar.scopeButtonTitles = ["All", "Chats", "People", "Messages"]
        search.searchBar.autocorrectionType = .no; search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search; navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(reloadSearch), for: .valueChanged)
        let events: [Notification.Name] = [.socketMessageDeleted, .socketMessageUpdated, .socketChatUpdated,
            .socketConnected, .socketDisconnected, .socketAuthenticationError, SessionManager.currentUserDidChange,
            UIApplication.didEnterBackgroundNotification]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !currentUser || note.name == UIApplication.didEnterBackgroundNotification { cancel(); return }
                    if note.name == .socketDisconnected || note.name == .socketAuthenticationError {
                        revision += 1; task?.cancel(); pages = [:]; busy = false
                        render("Connection interrupted. Pull to retry."); return
                    }
                    reloadSearch()
                }
            }
        }
        reloadSearch()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !opening && (isBeingDismissed || navigationController?.isBeingDismissed == true) {
            revision += 1; task?.cancel(); pages = [:]; search.searchBar.text = nil
        }
    }
    @objc private func cancel() { opening = true; revision += 1; task?.cancel(); pages = [:]; search.searchBar.text = nil; dismiss(animated: true) }
    @objc private func reloadSearch() { if !opening { loadPage() } }
    func updateSearchResults(for searchController: UISearchController) { reloadSearch() }
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        let values = ["all"] + categories
        guard values.indices.contains(selectedScope) else { return }
        filter = values[selectedScope]; reloadSearch()
    }
    private func loadPage(cursor: String? = nil) {
        revision += 1; task?.cancel(); pages = [:]; busy = false
        let version = revision
        let query = (search.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentUser else { cancel(); return }
        guard (2...100).contains(query.count) else { render("Enter 2 to 100 characters."); return }
        busy = true; render("Searching...")
        var parameters = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: filter), URLQueryItem(name: "limit", value: "20")]
        if let cursor { parameters.append(URLQueryItem(name: "cursor", value: cursor)) }
        task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard let self, !Task.isCancelled else { return }
                let result: [String: GlobalSearchPage] = try await APIClient.shared.request("/api/v1/search", queryItems: parameters)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                pages = result; busy = false; render("No matches in this range.")
            } catch {
                guard let self, !Task.isCancelled, revision == version else { return }
                busy = false; pages = [:]; render("Could not search ChitChat. Pull to retry.")
            }
        }
    }
    private func render(_ message: String) {
        notice.text = message; notice.isHidden = pages.values.contains { !$0.items.isEmpty }
        navigationItem.prompt = busy ? "Loading..." : nil
        refreshControl?.endRefreshing(); tableView.reloadData()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].capitalized }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { pages[sections[section]]?.items.count ?? 0 }
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let category = sections[section]
        guard let cursor = pages[category]?.nextCursor else { return nil }
        let button = UIButton(type: .system)
        button.setTitle(filter == "all" ? "See all \(category)" : "Search more", for: .normal)
        button.isEnabled = !busy
        button.addAction(UIAction { [weak self] _ in
            guard let self, !busy else { return }
            if filter == "all", let index = categories.firstIndex(of: category) {
                filter = category; search.searchBar.selectedScopeButtonIndex = index + 1; loadPage()
            } else { loadPage(cursor: cursor) }
        }, for: .touchUpInside)
        return button
    }
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { pages[sections[section]]?.nextCursor == nil ? 0 : 44 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "global-result", for: indexPath)
        if sections.indices.contains(indexPath.section), let page = pages[sections[indexPath.section]],
           page.items.indices.contains(indexPath.row), let cell = cell as? GlobalSearchCell { cell.configure(page.items[indexPath.row]) }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, currentUser, sections.indices.contains(indexPath.section), let page = pages[sections[indexPath.section]], page.items.indices.contains(indexPath.row) else { return }
        let result = page.items[indexPath.row]; let version = revision
        busy = true; render("Opening..."); task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let chat: Chat
                if result.category == "people", let person = result.personId {
                    chat = try await APIClient.shared.request("/api/v1/search/people/\(person)/open", method: .post)
                } else if let chatID = result.chatId { chat = try await ChatService().getChat(id: chatID) }
                else { throw APIClientError.invalidResponse }
                guard !Task.isCancelled, revision == version, currentUser else { return }
                opening = true; search.isActive = false
                dismiss(animated: true) { [self] in
                    guard revision == version, currentUser else { return }
                    onOpen(chat, result.category == "messages" ? result.messageId : nil)
                }
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                busy = false; pages = [:]; render("Result is no longer available or could not be opened. Pull to retry.")
            }
        }
    }
}

private final class GlobalSearchCell: UITableViewCell {
    private let avatar = AvatarView()
    private let photo = UIImageView()
    private let name = UILabel()
    private let summary = UILabel()
    private let context = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedID = ""
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        photo.translatesAutoresizingMaskIntoConstraints = false; photo.contentMode = .scaleAspectFill
        avatar.addSubview(photo); photo.pinEdges(to: avatar)
        name.font = .systemFont(ofSize: 15, weight: .semibold); name.numberOfLines = 1
        summary.font = .systemFont(ofSize: 14); summary.numberOfLines = 2
        context.font = .systemFont(ofSize: 12); context.numberOfLines = 2
        name.textColor = ChitChatColors.textPrimary; summary.textColor = ChitChatColors.textPrimary; context.textColor = ChitChatColors.textMuted
        let text = UIStackView(arrangedSubviews: [name, summary, context]); text.axis = .vertical; text.spacing = 4
        let row = UIStackView(arrangedSubviews: [avatar, text]); row.spacing = 12; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12), row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            avatar.widthAnchor.constraint(equalToConstant: 42), avatar.heightAnchor.constraint(equalToConstant: 42)])
        backgroundColor = ChitChatColors.background; accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { return nil }
    deinit { imageTask?.cancel() }
    func configure(_ result: GlobalSearchResult) {
        imageTask?.cancel(); representedID = result.id; photo.image = nil
        avatar.configure(name: result.title); name.text = result.title; summary.text = result.subtitle
        context.text = [result.senderName, result.type?.capitalized, result.createdAt.map { ChitChatDateFormatter.listTimestamp(from: $0) }].compactMap { $0 }.joined(separator: " | ")
        context.isHidden = context.text?.isEmpty != false
        guard let raw = result.avatarUrl, let url = APIClient.shared.resolvedURL(for: raw) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, representedID == result.id else { return }; photo.image = image
            }
        }
        imageTask?.resume()
    }
}
