import UIKit

struct ChatPin: Decodable {
    let messageId: String
    let pinnedAt: String
    let preview: String
    let forwarded: Bool
}

struct ChatPins: Decodable {
    let pins: [ChatPin]
    let canManage: Bool
    let maxPins: Int
    static let empty = ChatPins(pins: [], canManage: false, maxPins: 3)
}

@MainActor
final class PinnedMessagesCoordinator {
    let banner = UIView()
    private let summary = UIButton(type: .system)
    private let listButton = UIButton(type: .system)
    private var height: NSLayoutConstraint?
    private let chatID: String
    private let userID: String
    private weak var presenter: UIViewController?
    private weak var list: PinnedMessagesViewController?
    private weak var preview: PinnedMessagePreviewController?
    private var observers: [NSObjectProtocol] = []
    private var loadTask: Task<Void, Never>?
    private var changeTask: Task<Void, Never>?
    private var openTask: Task<Void, Never>?
    private var revision = 0
    private(set) var state = ChatPins.empty
    private(set) var busy = false
    var openLoaded: ((Message) -> Bool)?
    var openMedia: ((Message) -> Void)?
    var statusForMessage: ((Message) -> MessageStatus)?
    private var path: String { "/api/v1/chats/\(chatID)/pins" }
    private var isCurrentUser: Bool { SessionManager.shared.authenticatedUser?.id == userID }

    init(chatID: String, userID: String) {
        self.chatID = chatID
        self.userID = userID
    }

    deinit {
        loadTask?.cancel(); changeTask?.cancel(); openTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func install(on controller: UIViewController, below header: UIView) {
        presenter = controller
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.backgroundColor = ChitChatColors.surface
        banner.clipsToBounds = true
        controller.view.addSubview(banner)
        summary.translatesAutoresizingMaskIntoConstraints = false
        summary.contentHorizontalAlignment = .leading
        summary.titleLabel?.numberOfLines = 2
        summary.titleLabel?.lineBreakMode = .byTruncatingTail
        summary.titleLabel?.font = .systemFont(ofSize: 13)
        summary.tintColor = ChitChatColors.textPrimary
        summary.addTarget(self, action: #selector(openLatest), for: .touchUpInside)
        listButton.translatesAutoresizingMaskIntoConstraints = false
        listButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        listButton.tintColor = ChitChatColors.accent
        listButton.accessibilityLabel = "Show pinned messages"
        listButton.addTarget(self, action: #selector(showList), for: .touchUpInside)
        banner.addSubview(summary); banner.addSubview(listButton)
        let h = banner.heightAnchor.constraint(equalToConstant: 0)
        height = h
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: header.bottomAnchor),
            banner.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor), h,
            summary.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            summary.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            summary.trailingAnchor.constraint(equalTo: listButton.leadingAnchor, constant: -8),
            summary.heightAnchor.constraint(equalToConstant: 48),
            listButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            listButton.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            listButton.widthAnchor.constraint(equalToConstant: 64), listButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        let events: [Notification.Name] = [.socketChatPinsUpdated, .socketChatUpdated, .socketMessageUpdated,
            .socketMessageDeleted, .socketConnected, .socketDisconnected, .socketAuthenticationError,
            UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification,
            SessionManager.currentUserDidChange]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in self?.receive(note) }
            }
        }
        render()
    }

    private func receive(_ note: Notification) {
        if let id = note.object as? String, id != chatID { return }
        if let chat = note.object as? Chat, chat.id != chatID { return }
        if let event = note.object as? SocketMessageEvent, event.chatId != chatID { return }
        revision += 1; openTask?.cancel(); openTask = nil
        preview?.invalidate()
        state = .empty; render()
        if !isCurrentUser || note.name == .socketDisconnected || note.name == .socketAuthenticationError || note.name == UIApplication.didEnterBackgroundNotification {
            loadTask?.cancel(); state = .empty; render(); return
        }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        guard isCurrentUser else { state = .empty; render(); return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result: ChatPins = try await APIClient.shared.request(path)
                guard !Task.isCancelled, isCurrentUser else { return }
                state = result; render()
            } catch {
                guard !Task.isCancelled else { return }
                // Hide cached previews on any failed authorization/refresh, never leak stale content.
                state = .empty; preview?.invalidate(); render()
            }
        }
    }

    func isPinned(_ messageID: String) -> Bool { state.pins.contains { $0.messageId == messageID } }

    func change(_ messageID: String, remove: Bool) {
        guard state.canManage, !busy, isCurrentUser else { return }
        busy = true; render()
        changeTask = Task { [weak self] in
            guard let self else { return }
            defer { busy = false; render() }
            do {
                struct PinRequest: Encodable { let messageId: String }
                if remove {
                    let result: ChatPins = try await APIClient.shared.request("\(path)/\(messageID)", method: .delete)
                    _ = result
                } else {
                    let result: ChatPins = try await APIClient.shared.request(path, method: .post, body: PinRequest(messageId: messageID))
                    _ = result
                }
                guard !Task.isCancelled, isCurrentUser else { return }
                reload()
            } catch {
                guard !Task.isCancelled, isCurrentUser else { return }
                showError(error.localizedDescription); reload()
            }
        }
    }

    private func render() {
        let latest = state.pins.first
        height?.constant = latest == nil ? 0 : 56
        banner.isHidden = latest == nil
        summary.setImage(UIImage(systemName: "pin.fill"), for: .normal)
        summary.setTitle(latest.map { "  Pinned message\($0.forwarded ? " - Forwarded" : "")\n  \($0.preview)" }, for: .normal)
        listButton.setTitle("\(state.pins.count)/3  List", for: .normal)
        list?.update(state, busy: busy)
    }

    @objc private func openLatest() { if let pin = state.pins.first { open(pin.messageId) } }
    @objc private func showList() {
        guard let presenter, presenter.presentedViewController == nil else { return }
        let controller = PinnedMessagesViewController(coordinator: self)
        list = controller
        controller.update(state, busy: busy)
        presenter.present(UINavigationController(rootViewController: controller), animated: true)
    }

    func open(_ messageID: String) {
        guard openTask == nil, isCurrentUser else { return }
        let version = revision
        openTask = Task { [weak self] in
            guard let self else { return }
            defer { openTask = nil }
            do {
                let message: Message = try await APIClient.shared.request("\(path)/\(messageID)")
                guard !Task.isCancelled, isCurrentUser, version == revision else { return }
                let show = { [weak self] in
                    guard let self, self.isCurrentUser, version == self.revision else { return }
                    if self.openLoaded?(message) == true { return }
                    let controller = PinnedMessagePreviewController(message: message, userID: self.userID, status: self.statusForMessage?(message) ?? .sent)
                    controller.openMedia = { [weak self, weak controller] message in
                        controller?.dismiss(animated: true) { self?.openMedia?(message) }
                    }
                    self.preview = controller
                    self.presenter?.present(UINavigationController(rootViewController: controller), animated: true)
                }
                if let list, list.presentingViewController != nil || list.navigationController?.presentingViewController != nil {
                    list.dismiss(animated: true, completion: show)
                } else if presenter?.presentedViewController == nil { show() }
            } catch { if !Task.isCancelled, isCurrentUser { showError("This pinned message is no longer available."); reload() } }
        }
    }

    private func showError(_ text: String) {
        let host = list?.navigationController ?? presenter
        guard let host, host.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Pinned messages", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); host.present(alert, animated: true)
    }
}

@MainActor
final class PinnedMessagesViewController: UITableViewController {
    private weak var coordinator: PinnedMessagesCoordinator?
    private var state = ChatPins.empty
    private var busy = false
    init(coordinator: PinnedMessagesCoordinator) { self.coordinator = coordinator; super.init(style: .plain) }
    required init?(coder: NSCoder) { return nil }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Pinned messages"
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 76
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
    }
    @objc private func done() { dismiss(animated: true) }
    @objc private func refresh() { coordinator?.reload() }
    func update(_ state: ChatPins, busy: Bool) {
        self.state = state; self.busy = busy
        if isViewLoaded { refreshControl?.endRefreshing(); tableView.reloadData(); navigationItem.prompt = state.pins.isEmpty ? "No available pinned messages" : "\(state.pins.count) / 3 pinned" }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { state.pins.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard state.pins.indices.contains(indexPath.row) else { return UITableViewCell() }
        let pin = state.pins[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = ChitChatColors.surface
        cell.textLabel?.textColor = ChitChatColors.textPrimary; cell.textLabel?.numberOfLines = 2
        cell.textLabel?.text = pin.preview; cell.detailTextLabel?.textColor = ChitChatColors.textMuted
        cell.detailTextLabel?.text = pin.forwarded ? "Forwarded - Tap to open" : "Tap to open"
        if state.canManage {
            let unpin = UIButton(type: .system); unpin.setTitle("Unpin", for: .normal); unpin.tintColor = ChitChatColors.accent
            unpin.isEnabled = !busy
            unpin.addAction(UIAction { [weak self] _ in self?.coordinator?.change(pin.messageId, remove: true) }, for: .touchUpInside)
            unpin.frame = CGRect(x: 0, y: 0, width: 64, height: 44); cell.accessoryView = unpin
        } else { cell.accessoryType = .disclosureIndicator }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard state.pins.indices.contains(indexPath.row) else { return }
        coordinator?.open(state.pins[indexPath.row].messageId)
    }
}

@MainActor
private final class PinnedMessagePreviewController: UITableViewController {
    private let message: Message
    private let userID: String
    private let status: MessageStatus
    private let playback = VoiceNotePlaybackCoordinator()
    private var available = true
    var openMedia: ((Message) -> Void)?
    init(message: Message, userID: String, status: MessageStatus) { self.message = message; self.userID = userID; self.status = status; super.init(style: .plain) }
    required init?(coder: NSCoder) { return nil }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Pinned message preview"
        tableView.backgroundColor = ChitChatColors.chatDetailScreen; tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 180
        tableView.register(MessageBubbleCell.self, forCellReuseIdentifier: MessageBubbleCell.reuseIdentifier)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        playback.onStateChanged = { [weak self] state in
            guard let self, let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? MessageBubbleCell else { return }
            cell.updateVoicePlayback(state, messageID: self.message.id)
        }
    }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); playback.stop() }
    @objc private func done() { dismiss(animated: true) }
    func invalidate() { available = false; playback.stop(); if isViewLoaded { tableView.reloadData(); navigationItem.prompt = "Pin changed. Reopen it to refresh." } }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { available ? 1 : 0 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageBubbleCell.reuseIdentifier, for: indexPath) as? MessageBubbleCell else { return UITableViewCell() }
        cell.configure(message: message, isOutgoing: message.senderId == userID, replyPreview: nil, currentUserId: userID,
                       status: status, voicePlaybackState: playback.state,
                       onVoiceToggle: { [weak self] in self?.toggleVoice() },
                       onVoiceSeek: { [weak self] seconds in
                           guard let self else { return }
                           if self.playback.state.sourceID != self.message.id { self.toggleVoice() }
                           self.playback.seek(to: seconds)
                       },
                       onVoiceStop: { [weak self] in self?.playback.stop() })
        return cell
    }
    private func toggleVoice() {
        guard available, let attachment = message.primaryAttachment, let url = URL(string: attachment.url) else { return }
        do { try playback.toggle(sourceID: message.id, url: url, declaredDuration: attachment.duration ?? 0) }
        catch { navigationItem.prompt = "Could not play voice message. Try again." }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if available { openMedia?(message) }
    }
}
