import UIKit

private struct MessageStarState: Decodable { let messageId: String; let starred: Bool }
private struct StarredItem: Decodable {
    let messageId: String
    let chatId: String
    let chatName: String
    let senderName: String
    let preview: String
    let createdAt: String
    let starredAt: String
    let type: String
}
private struct StarredPage: Decodable { let items: [StarredItem]; let nextCursor: String? }
private enum MessageStarsAPI {
    static func state(chatID: String, messageID: String, method: HTTPMethod = .get) async throws -> MessageStarState {
        try await APIClient.shared.request("/api/v1/starred-messages/\(chatID)/\(messageID)", method: method)
    }
}

@MainActor
final class MessageStarAction {
    private let chatID: String
    private let messageID: String
    private let userID: String
    private let onError: () -> Void
    private weak var action: UIAlertAction?
    private weak var menu: UIAlertController?
    private var state: MessageStarState?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var revision = 0
    private var writing = false
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == userID }

    init(menu: UIAlertController, message: Message, userID: String, onError: @escaping () -> Void) {
        chatID = message.chatId; messageID = message.id; self.userID = userID; self.onError = onError
        self.menu = menu; menu.message = "Loading saved state..."
        let events: [Notification.Name] = [.socketMessageStarUpdated, .socketMessageDeleted, .socketChatUpdated,
            .socketConnected, .socketDisconnected, SessionManager.currentUserDidChange,
            UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !currentUser || note.name == .socketDisconnected || note.name == UIApplication.didEnterBackgroundNotification {
                        revision += 1; task?.cancel(); state = nil; action?.isEnabled = false; return
                    }
                    if !writing { reload() }
                }
            }
        }
        reload()
    }
    deinit { task?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    private func reload() {
        revision += 1; task?.cancel(); state = nil; action?.isEnabled = false
        let version = revision
        guard currentUser, menu != nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await MessageStarsAPI.state(chatID: chatID, messageID: messageID)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                state = result
                let title = result.starred ? "Unstar" : "Star"
                // UIAlertAction titles are immutable. Close a stale menu rather than offer the wrong action.
                if let action {
                    if action.title != title { menu?.dismiss(animated: true); return }
                    action.isEnabled = true
                } else {
                    let button = UIAlertAction(title: title, style: .default) { [weak self] _ in self?.change() }
                    action = button; menu?.addAction(button)
                }
                menu?.message = nil
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                menu?.message = "Saved state unavailable. Reopen to retry."
            }
        }
    }
    private func change() {
        guard !writing, currentUser, let state else { return }
        writing = true; action?.isEnabled = false; revision += 1; task?.cancel()
        let version = revision
        task = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await MessageStarsAPI.state(chatID: chatID, messageID: messageID, method: state.starred ? .delete : .post)
            } catch {
                if !Task.isCancelled, revision == version, currentUser { onError() }
            }
            writing = false
        }
    }
}

@MainActor
final class StarredMessagesViewController: UITableViewController {
    private let userID: String
    private let onOpen: (Chat, String) -> Void
    private let notice = UILabel()
    private var items: [StarredItem] = []
    private var nextCursor: String?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var revision = 0
    private var busy = false
    private var opening = false
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == userID }

    init(userID: String, onOpen: @escaping (Chat, String) -> Void) {
        self.userID = userID; self.onOpen = onOpen; super.init(style: .plain)
    }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Starred Messages"
        tableView.backgroundColor = ChitChatColors.background; tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 110
        notice.textAlignment = .center; notice.numberOfLines = 0; notice.textColor = ChitChatColors.textMuted
        tableView.backgroundView = notice
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        let events: [Notification.Name] = [.socketMessageStarUpdated, .socketMessageDeleted, .socketMessageUpdated, .socketChatUpdated,
            .socketConnected, .socketDisconnected, .socketAuthenticationError, SessionManager.currentUserDidChange,
            UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !currentUser { close(); return }
                    if note.name == .socketDisconnected || note.name == .socketAuthenticationError || note.name == UIApplication.didEnterBackgroundNotification {
                        revision += 1; task?.cancel(); items = []; nextCursor = nil; busy = false
                        render("Connection interrupted. Pull to retry."); return
                    }
                    if !opening { refresh() }
                }
            }
        }
        refresh()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !opening && (isBeingDismissed || navigationController?.isBeingDismissed == true) { revision += 1; task?.cancel(); items = [] }
    }
    @objc private func close() { opening = true; revision += 1; task?.cancel(); items = []; dismiss(animated: true) }
    @objc private func refresh() { if !opening { load() } }
    @objc private func more() { if !busy, let nextCursor { load(cursor: nextCursor) } }
    private func load(cursor: String? = nil) {
        revision += 1; task?.cancel(); items = []; nextCursor = nil
        guard currentUser else { close(); return }
        let version = revision; busy = true; render("Loading starred messages...")
        var parameters = [URLQueryItem(name: "limit", value: "20")]
        if let cursor { parameters.append(URLQueryItem(name: "cursor", value: cursor)) }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let page: StarredPage = try await APIClient.shared.request("/api/v1/starred-messages", queryItems: parameters)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                items = page.items; nextCursor = page.nextCursor; busy = false
                render(nextCursor == nil ? "No starred messages yet" : "No available messages on this page. Load more.")
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                busy = false; render("Could not load starred messages. Pull to retry.")
            }
        }
    }
    private func render(_ message: String) {
        notice.text = message; notice.isHidden = !items.isEmpty
        navigationItem.prompt = busy ? "Loading..." : nil; refreshControl?.endRefreshing()
        if nextCursor != nil {
            let button = UIButton(type: .system); button.setTitle("Load more", for: .normal)
            button.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 48)
            button.isEnabled = !busy; button.addTarget(self, action: #selector(more), for: .touchUpInside); tableView.tableFooterView = button
        } else { tableView.tableFooterView = nil }
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "starred") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "starred")
        guard items.indices.contains(indexPath.row) else { return cell }
        let item = items[indexPath.row]
        cell.textLabel?.text = item.chatName; cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cell.textLabel?.textColor = ChitChatColors.textPrimary
        cell.detailTextLabel?.text = "\(item.senderName)\n\(item.preview)\n\(ChitChatDateFormatter.listTimestamp(from: item.createdAt))"
        cell.detailTextLabel?.numberOfLines = 5; cell.detailTextLabel?.textColor = ChitChatColors.textMuted
        cell.imageView?.image = UIImage(systemName: "star.fill"); cell.imageView?.tintColor = ChitChatColors.accent
        cell.backgroundColor = ChitChatColors.background; cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, currentUser, items.indices.contains(indexPath.row) else { return }
        let item = items[indexPath.row]; let version = revision
        busy = true; render("Opening..."); task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let chat = try await ChatService().getChat(id: item.chatId)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                opening = true
                dismiss(animated: true) { [self] in
                    guard currentUser, revision == version else { return }; onOpen(chat, item.messageId)
                }
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                items = []; nextCursor = nil; busy = false; render("Message is no longer available or could not be opened. Pull to retry.")
            }
        }
    }
}
