import UIKit

struct UserBlockState: Decodable {
    let userId: String
    let blockedByMe: Bool
    let canCommunicate: Bool
}
private struct BlockedUser: Decodable { let userId: String; let name: String; let avatarUrl: String }
private struct BlockedPage: Decodable { let items: [BlockedUser]; let nextCursor: String? }

@MainActor
final class DirectBlockPolicy {
    let targetID: String
    private let actorID: String
    private(set) var state: UserBlockState?
    private(set) var busy = false
    var onChange: (() -> Void)?
    var active = false { didSet { if active { reload() } else { invalidate() } } }
    var allowed: Bool { state?.canCommunicate == true && currentUser }
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == actorID }
    private var task: Task<Void, Never>?
    private var timer: Timer?
    private var revision = 0
    private var observers: [NSObjectProtocol] = []

    init(targetID: String, actorID: String) {
        self.targetID = targetID; self.actorID = actorID
        observers = [Notification.Name.socketPrivacyBlockUpdated, .socketConnected, .socketDisconnected,
            SessionManager.currentUserDidChange, UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if note.name == .socketDisconnected || note.name == UIApplication.didEnterBackgroundNotification || !currentUser { invalidate() }
                    else if !busy { reload() }
                }
            }
        }
        // Reconcile generic availability without sending another user's block decision to this account.
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reload() }
        }
    }
    deinit { task?.cancel(); timer?.invalidate(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    private func invalidate() { revision += 1; task?.cancel(); state = nil; busy = false; onChange?() }
    func reload() {
        guard active, currentUser, !busy, UIApplication.shared.applicationState == .active else { return }
        revision += 1; task?.cancel(); let version = revision
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result: UserBlockState = try await APIClient.shared.request("/api/v1/privacy/blocks/\(targetID)")
                guard !Task.isCancelled, revision == version, currentUser else { return }
                state = result; onChange?()
            } catch {
                guard !Task.isCancelled, revision == version else { return }
                state = nil; onChange?()
            }
        }
    }
    func confirm(on presenter: UIViewController, name: String) {
        guard !busy, currentUser, let state else { reload(); return }
        let blocked = !state.blockedByMe
        let menu = UIAlertController(title: "\(blocked ? "Block" : "Unblock") \(name)?", message: blocked
            ? "You won't be able to directly message or call each other. Shared groups remain unaffected."
            : "This removes your block. Failed messages will not be resent.", preferredStyle: .alert)
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.addAction(UIAlertAction(title: blocked ? "Block" : "Unblock", style: blocked ? .destructive : .default) { [weak self, weak presenter] _ in
            guard let self, currentUser, !busy else { return }
            busy = true; revision += 1; task?.cancel(); let version = revision; onChange?()
            task = Task { [weak self, weak presenter] in
                guard let self else { return }
                do {
                    let value: UserBlockState = try await APIClient.shared.request("/api/v1/privacy/blocks/\(targetID)", method: blocked ? .post : .delete)
                    guard !Task.isCancelled, revision == version, currentUser else { return }
                    self.state = value; busy = false; onChange?()
                } catch {
                    guard !Task.isCancelled, revision == version, currentUser else { return }
                    busy = false; self.state = nil; onChange?()
                    let error = UIAlertController(title: "Could not update privacy", message: "Please try again.", preferredStyle: .alert)
                    error.addAction(UIAlertAction(title: "OK", style: .default)); presenter?.present(error, animated: true)
                }
            }
        })
        presenter.present(menu, animated: true)
    }
}

@MainActor
final class BlockingPrivacyViewController: UITableViewController {
    private let actorID: String
    init(actorID: String) { self.actorID = actorID; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { return nil }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Privacy"; tableView.backgroundColor = ChitChatColors.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
    }
    @objc private func close() { dismiss(animated: true) }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Blocked Users"; cell.textLabel?.textColor = ChitChatColors.textPrimary
        cell.backgroundColor = ChitChatColors.background; cell.accessoryType = .disclosureIndicator; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(BlockedUsersViewController(actorID: actorID), animated: true)
    }
}

@MainActor
final class BlockedUsersViewController: UITableViewController {
    private let actorID: String
    private var items: [BlockedUser] = []
    private var nextCursor: String?
    private let notice = UILabel()
    private var task: Task<Void, Never>?
    private var revision = 0
    private var busy = false
    private var writing = false
    private var observers: [NSObjectProtocol] = []
    private var currentUser: Bool { SessionManager.shared.authenticatedUser?.id == actorID }
    init(actorID: String) { self.actorID = actorID; super.init(style: .plain) }
    required init?(coder: NSCoder) { return nil }
    deinit { task?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Blocked Users"; tableView.rowHeight = 76
        tableView.backgroundColor = ChitChatColors.background; tableView.separatorColor = ChitChatColors.divider
        notice.textAlignment = .center; notice.numberOfLines = 0; notice.textColor = ChitChatColors.textMuted
        tableView.backgroundView = notice
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        observers = [Notification.Name.socketPrivacyBlockUpdated, .socketConnected, .socketDisconnected,
            SessionManager.currentUserDidChange, UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !currentUser { revision += 1; task?.cancel(); items = []; dismiss(animated: true); return }
                    if note.name == .socketDisconnected || note.name == UIApplication.didEnterBackgroundNotification {
                        revision += 1; task?.cancel(); items = []; nextCursor = nil; busy = false; writing = false; render("Pull to retry.")
                    } else if !writing { refresh() }
                }
            }
        }
        refresh()
    }
    @objc private func refresh() { if !writing { load() } }
    @objc private func more() { if !busy, let nextCursor { load(cursor: nextCursor) } }
    private func load(cursor: String? = nil) {
        guard currentUser else { return }
        revision += 1; task?.cancel(); let version = revision
        busy = true; items = []; nextCursor = nil; render("Loading...")
        var query = [URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let page: BlockedPage = try await APIClient.shared.request("/api/v1/privacy/blocks", queryItems: query)
                guard !Task.isCancelled, version == revision, currentUser else { return }
                items = page.items; nextCursor = page.nextCursor; busy = false; render("No blocked users")
            } catch {
                guard !Task.isCancelled, version == revision else { return }
                busy = false; render("Could not load blocked users. Pull to retry.")
            }
        }
    }
    private func render(_ text: String) {
        notice.text = text; notice.isHidden = !items.isEmpty; refreshControl?.endRefreshing()
        navigationItem.prompt = busy ? "Loading..." : nil
        if nextCursor != nil {
            let button = UIButton(type: .system); button.setTitle("Next page", for: .normal)
            button.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 52)
            button.addTarget(self, action: #selector(more), for: .touchUpInside); tableView.tableFooterView = button
        } else { tableView.tableFooterView = nil }
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        guard items.indices.contains(indexPath.row) else { return cell }
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration(); content.text = item.name; content.secondaryText = "Unblock"
        content.textProperties.color = ChitChatColors.textPrimary; content.secondaryTextProperties.color = ChitChatColors.accent
        cell.contentConfiguration = content; cell.backgroundColor = ChitChatColors.background
        let avatar = ReplicaAvatarView(frame: CGRect(x: 0, y: 0, width: 42, height: 42))
        avatar.configure(name: item.name, urlString: item.avatarUrl); cell.accessoryView = avatar
        cell.accessibilityLabel = "\(item.name), Unblock"; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, currentUser, items.indices.contains(indexPath.row) else { return }
        let item = items[indexPath.row]
        let menu = UIAlertController(title: "Unblock \(item.name)?", message: "Failed messages will not be resent.", preferredStyle: .alert)
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.addAction(UIAlertAction(title: "Unblock", style: .default) { [weak self] _ in self?.unblock(item) })
        present(menu, animated: true)
    }
    private func unblock(_ item: BlockedUser) {
        guard !busy, currentUser else { return }; busy = true; writing = true; revision += 1; task?.cancel(); let version = revision
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let _: UserBlockState = try await APIClient.shared.request("/api/v1/privacy/blocks/\(item.userId)", method: .delete)
                guard !Task.isCancelled, revision == version, currentUser else { return }
                busy = false; writing = false; load()
            } catch {
                guard !Task.isCancelled, revision == version, currentUser else { return }
                busy = false; writing = false; navigationItem.prompt = "Could not unblock. Please retry."
            }
        }
    }
}
