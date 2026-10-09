import UIKit

private struct ConversationSearchResult: Decodable {
    let messageId: String
    let createdAt: String
    let type: String
    let preview: String
    let matchField: String
}
private struct ConversationSearchPage: Decodable {
    let items: [ConversationSearchResult]
    let nextCursor: String?
}

@MainActor
final class ConversationSearchViewController: UITableViewController, UISearchResultsUpdating {
    private let chatID: String
    private let userID: String
    private let onOpen: (Message) -> Void
    private let search = UISearchController(searchResultsController: nil)
    private let notice = UILabel()
    private var results: [ConversationSearchResult] = []
    private var cursors: [String?] = [nil]
    private var pageIndex = 0
    private var nextCursor: String?
    private var selected = 0
    private var busy = false
    private var openingResult = false
    private var revision = 0
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var previousButton: UIBarButtonItem?
    private var nextButton: UIBarButtonItem?
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == userID }
    private var path: String { "/api/v1/chats/\(chatID)" }

    init(chatID: String, userID: String, onOpen: @escaping (Message) -> Void) {
        self.chatID = chatID; self.userID = userID; self.onOpen = onOpen
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search this chat"
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 86
        tableView.keyboardDismissMode = .onDrag
        notice.numberOfLines = 0; notice.textAlignment = .center
        notice.font = .systemFont(ofSize: 15); notice.textColor = ChitChatColors.textMuted
        tableView.backgroundView = notice
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search messages"
        search.searchBar.autocorrectionType = .no
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Open", style: .done, target: self, action: #selector(openSelected))
        previousButton = UIBarButtonItem(title: "Previous", style: .plain, target: self, action: #selector(previousResult))
        nextButton = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextResult))
        if let previousButton, let nextButton {
            toolbarItems = [previousButton, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), nextButton]
        }
        navigationController?.setToolbarHidden(false, animated: false)
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshSearch), for: .valueChanged)
        let events: [Notification.Name] = [.socketMessageDeleted, .socketMessageUpdated, .socketChatUpdated,
            .socketConnected, .socketDisconnected, .socketAuthenticationError,
            SessionManager.currentUserDidChange, UIApplication.didEnterBackgroundNotification]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in self?.reconcile(note) }
            }
        }
        loadPage()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !openingResult && (isBeingDismissed || navigationController?.isBeingDismissed == true) { revision += 1; task?.cancel() }
    }
    @objc private func cancel() { revision += 1; task?.cancel(); dismiss(animated: true) }
    @objc private func refreshSearch() { cursors = [nil]; pageIndex = 0; loadPage() }
    func updateSearchResults(for searchController: UISearchController) { refreshSearch() }

    private func reconcile(_ note: Notification) {
        if let event = note.object as? SocketMessageEvent, event.chatId != chatID { return }
        if let chat = note.object as? Chat, chat.id != chatID { return }
        if let id = note.object as? String, id != chatID { return }
        if !currentUser || note.name == UIApplication.didEnterBackgroundNotification { cancel(); return }
        if note.name == .socketDisconnected || note.name == .socketAuthenticationError {
            revision += 1; task?.cancel(); results = []; nextCursor = nil; busy = false
            render("Connection interrupted. Pull to retry."); return
        }
        refreshSearch()
    }

    private func loadPage(selectLast: Bool = false) {
        revision += 1; task?.cancel()
        let version = revision
        results = []; nextCursor = nil; selected = 0; busy = false
        let query = (search.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentUser else { cancel(); return }
        guard (2...100).contains(query.count) else { render("Enter 2 to 100 characters."); return }
        busy = true; render("Searching...")
        var parameters = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "20")]
        if cursors.indices.contains(pageIndex), let cursor = cursors[pageIndex] {
            parameters.append(URLQueryItem(name: "cursor", value: cursor))
        }
        task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard let self, !Task.isCancelled else { return }
                let page: ConversationSearchPage = try await APIClient.shared.request("\(path)/search", queryItems: parameters)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                results = page.items; nextCursor = page.nextCursor; busy = false
                selected = selectLast ? max(0, results.count - 1) : 0
                render(results.isEmpty ? (nextCursor == nil ? "No matches in this range." : "No matches in this range.\nSearch older messages.") : nil)
                revealSelection()
            } catch {
                guard let self, !Task.isCancelled, revision == version else { return }
                busy = false; results = []; render("Could not search this chat. Pull to retry.")
            }
        }
    }

    private func render(_ text: String? = nil) {
        notice.text = text; notice.isHidden = !results.isEmpty
        navigationItem.prompt = busy ? "Loading..." : results.isEmpty ? nil : "Result \(selected + 1) on this page"
        previousButton?.isEnabled = !busy && (selected > 0 || pageIndex > 0)
        nextButton?.isEnabled = !busy && (selected + 1 < results.count || nextCursor != nil)
        nextButton?.title = results.isEmpty && nextCursor != nil ? "Search older" : "Next"
        navigationItem.rightBarButtonItem?.isEnabled = !busy && results.indices.contains(selected)
        refreshControl?.endRefreshing(); tableView.reloadData()
    }
    private func revealSelection() {
        guard results.indices.contains(selected) else { return }
        tableView.scrollToRow(at: IndexPath(row: selected, section: 0), at: .middle, animated: true)
    }
    @objc private func nextResult() {
        guard !busy else { return }
        if selected + 1 < results.count { selected += 1; render(); revealSelection() }
        else if let nextCursor {
            cursors = Array(cursors.prefix(pageIndex + 1)) + [nextCursor]
            pageIndex += 1; loadPage()
        }
    }
    @objc private func previousResult() {
        guard !busy else { return }
        if selected > 0 { selected -= 1; render(); revealSelection() }
        else if pageIndex > 0 { pageIndex -= 1; loadPage(selectLast: true) }
    }
    @objc private func openSelected() {
        guard !busy, currentUser, results.indices.contains(selected) else { return }
        let target = results[selected].messageId
        let version = revision
        busy = true; render()
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let message: Message = try await APIClient.shared.request("\(path)/message-target/\(target)")
                guard !Task.isCancelled, revision == version, currentUser else { return }
                guard message.chatId == chatID, message.id == target, !message.isDeletedForEveryone, !message.isDeletedForMe else {
                    busy = false; results = []; render("Message is no longer available."); return
                }
                openingResult = true
                search.isActive = false
                dismiss(animated: true) { [self] in
                    guard currentUser, revision == version else { return }
                    onOpen(message)
                }
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                busy = false; results = []; nextCursor = nil
                render("Message is no longer available or could not be loaded. Pull to retry.")
            }
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { results.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "search-result") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "search-result")
        guard results.indices.contains(indexPath.row) else { return cell }
        let result = results[indexPath.row]
        cell.textLabel?.text = result.preview; cell.textLabel?.numberOfLines = 3
        cell.textLabel?.font = .systemFont(ofSize: 15); cell.textLabel?.textColor = ChitChatColors.textPrimary
        cell.detailTextLabel?.text = result.createdAt.replacingOccurrences(of: "T", with: " ").prefix(16).description
        cell.detailTextLabel?.textColor = ChitChatColors.textMuted
        cell.backgroundColor = selected == indexPath.row ? ChitChatColors.surface : ChitChatColors.background
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !busy, results.indices.contains(indexPath.row) else { return }
        selected = indexPath.row; openSelected()
    }
}
