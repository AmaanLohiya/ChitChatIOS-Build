import QuartzCore
import UIKit

private final class StatusViewerListViewController: BaseViewController, UITableViewDataSource {
    private let viewers: [StatusViewer]
    private let onClose: () -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(viewers: [StatusViewer], onClose: @escaping () -> Void) {
        self.viewers = viewers
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Viewed by \(viewers.count)"
        view.backgroundColor = ChitChatColors.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = ChitChatColors.divider
        tableView.rowHeight = 68
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(1, viewers.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        guard viewers.indices.contains(indexPath.row) else {
            cell.textLabel?.text = "No views yet"
            cell.textLabel?.textColor = ChitChatColors.textMuted
            cell.textLabel?.textAlignment = .center
            return cell
        }

        let viewer = viewers[indexPath.row]
        let avatar = ReplicaAvatarView()
        avatar.frame = CGRect(x: 16, y: 10, width: 48, height: 48)
        avatar.configure(name: viewer.name, urlString: viewer.avatarUrl)
        cell.contentView.addSubview(avatar)
        cell.textLabel?.text = viewer.name
        cell.textLabel?.textColor = ChitChatColors.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        cell.detailTextLabel?.text = "Viewed at \(Self.time(viewer.viewedAt))"
        cell.detailTextLabel?.textColor = ChitChatColors.textMuted
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
        cell.indentationLevel = 6
        return cell
    }

    @objc private func doneTapped() {
        dismiss(animated: true, completion: onClose)
    }

    private static func time(_ value: String) -> String {
        guard let date = ChitChatDateFormatter.date(from: value) else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

final class StatusViewerViewController: BaseViewController, UIAdaptivePresentationControllerDelegate {
    private let initialOwnerID: String
    private let ownerStatusesOnly: Bool
    private let initialStatusID: String?
    private let statusService = StatusService()
    private let imageView = UIImageView()
    private let textLabel = UILabel()
    private let avatarView = ReplicaAvatarView()
    private let ownerLabel = UILabel()
    private let timeLabel = UILabel()
    private let progressStack = UIStackView()
    private let leftTap = UIButton(type: .custom)
    private let rightTap = UIButton(type: .custom)
    private let ownerActions = UIStackView()
    private let viewsButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var groups: [StatusGroup] = []
    private var groupIndex = 0
    private var statusIndex = 0
    private var timer: Timer?
    private var progress: Float = 0
    private var holdStartedAt: CFTimeInterval?
    private var isForeground = true
    private var isHolding = false
    private var isLoading = false
    private var reloadRequested = false
    private var reloadStatusID: String?
    private var isDeleting = false
    private var acknowledgedStatusIDs = Set<String>()
    private var observers: [NSObjectProtocol] = []
    private var imageTask: URLSessionDataTask?

    init(ownerID: String, ownerStatusesOnly: Bool = false, initialStatusID: String? = nil) {
        initialOwnerID = ownerID
        self.ownerStatusesOnly = ownerStatusesOnly
        self.initialStatusID = initialStatusID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        stopTimer()
        imageTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        observeLifecycleAndRealtime()
        loadGroups(preservingCurrentStatusID: initialStatusID)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTimerIfNeeded()
    }

    private var currentGroup: StatusGroup? {
        guard groups.indices.contains(groupIndex) else { return nil }
        return groups[groupIndex]
    }

    private var currentStatus: StatusItem? {
        guard let group = currentGroup, group.statuses.indices.contains(statusIndex) else { return nil }
        return group.statuses[statusIndex]
    }

    private var isOwner: Bool {
        ownerStatusesOnly || currentGroup?.owner.id == SessionManager.shared.authenticatedUser?.id
    }

    private func buildUI() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.clipsToBounds = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: 29, weight: .bold)
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0

        let topShade = UIView()
        topShade.translatesAutoresizingMaskIntoConstraints = false
        topShade.backgroundColor = UIColor.black.withAlphaComponent(0.24)

        progressStack.translatesAutoresizingMaskIntoConstraints = false
        progressStack.axis = .horizontal
        progressStack.spacing = 5
        progressStack.distribution = .fillEqually

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.borderWidth = 1
        avatarView.layer.borderColor = UIColor.white.cgColor
        ownerLabel.translatesAutoresizingMaskIntoConstraints = false
        ownerLabel.textColor = .white
        ownerLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        let ownerText = UIStackView(arrangedSubviews: [ownerLabel, timeLabel])
        ownerText.translatesAutoresizingMaskIntoConstraints = false
        ownerText.axis = .vertical
        ownerText.spacing = 2

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        leftTap.translatesAutoresizingMaskIntoConstraints = false
        leftTap.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        leftTap.addTarget(self, action: #selector(holdBegan), for: [.touchDown, .touchDragEnter])
        leftTap.addTarget(self, action: #selector(holdEnded), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        rightTap.translatesAutoresizingMaskIntoConstraints = false
        rightTap.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        rightTap.addTarget(self, action: #selector(holdBegan), for: [.touchDown, .touchDragEnter])
        rightTap.addTarget(self, action: #selector(holdEnded), for: [.touchUpOutside, .touchCancel, .touchDragExit])

        configureActionButton(viewsButton, title: "0 views", symbol: "eye", selector: #selector(viewersTapped))
        configureActionButton(deleteButton, title: "Delete", symbol: "trash", selector: #selector(deleteTapped))
        ownerActions.translatesAutoresizingMaskIntoConstraints = false
        ownerActions.axis = .horizontal
        ownerActions.distribution = .fillEqually
        ownerActions.spacing = 18
        ownerActions.addArrangedSubview(viewsButton)
        ownerActions.addArrangedSubview(deleteButton)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = ChitChatColors.accent

        view.addSubview(imageView)
        view.addSubview(textLabel)
        view.addSubview(topShade)
        view.addSubview(progressStack)
        view.addSubview(avatarView)
        view.addSubview(ownerText)
        view.addSubview(closeButton)
        view.addSubview(leftTap)
        view.addSubview(rightTap)
        view.addSubview(ownerActions)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            textLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            topShade.topAnchor.constraint(equalTo: view.topAnchor),
            topShade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topShade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topShade.heightAnchor.constraint(equalToConstant: 150),
            progressStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            progressStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            progressStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            progressStack.heightAnchor.constraint(equalToConstant: 3),
            avatarView.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 12),
            avatarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            avatarView.widthAnchor.constraint(equalToConstant: 42),
            avatarView.heightAnchor.constraint(equalToConstant: 42),
            ownerText.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            ownerText.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            ownerText.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            leftTap.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 6),
            leftTap.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftTap.bottomAnchor.constraint(equalTo: ownerActions.topAnchor, constant: -4),
            leftTap.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            rightTap.topAnchor.constraint(equalTo: leftTap.topAnchor),
            rightTap.leadingAnchor.constraint(equalTo: leftTap.trailingAnchor),
            rightTap.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rightTap.bottomAnchor.constraint(equalTo: leftTap.bottomAnchor),
            ownerActions.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ownerActions.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ownerActions.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            ownerActions.heightAnchor.constraint(equalToConstant: 48),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureActionButton(_ button: UIButton, title: String, symbol: String, selector: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        button.layer.cornerRadius = 24
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    private func observeLifecycleAndRealtime() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isForeground = false
            self?.stopTimer()
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isForeground = true
            self?.startTimerIfNeeded()
            self?.acknowledgeCurrentStatusIfNeeded()
        })
        let statusNotifications: [Notification.Name] = [
            .socketStatusCreated,
            .socketStatusDeleted,
            .socketStatusViewed,
            .socketConnected
        ]
        for name in statusNotifications {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.loadGroups(preservingCurrentStatusID: self?.currentStatus?.id)
            })
        }
    }

    private func loadGroups(preservingCurrentStatusID statusID: String?) {
        guard !isLoading else {
            reloadRequested = true
            reloadStatusID = statusID ?? currentStatus?.id
            return
        }
        isLoading = true
        loadingIndicator.startAnimating()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                if self.reloadRequested {
                    self.reloadRequested = false
                    let statusID = self.reloadStatusID
                    self.reloadStatusID = nil
                    self.loadGroups(preservingCurrentStatusID: statusID)
                }
            }
            do {
                let loadedGroups: [StatusGroup]
                if self.ownerStatusesOnly {
                    let mine = try await self.statusService.mine()
                    loadedGroups = mine.statuses.isEmpty ? [] : [mine]
                } else {
                    loadedGroups = try await self.statusService.feed()
                }
                self.groups = self.normalize(loadedGroups)
                guard !self.groups.isEmpty else {
                    self.dismiss(animated: true)
                    return
                }

                if let statusID,
                   let location = self.findStatus(statusID) {
                    self.groupIndex = location.group
                    self.statusIndex = location.status
                } else {
                    let targetIndex: Int?
                    if self.ownerStatusesOnly {
                        targetIndex = self.groups.indices.first
                    } else {
                        targetIndex = self.groups.firstIndex(where: { $0.owner.id == self.initialOwnerID })
                    }
                    guard let target = targetIndex else {
                        self.dismiss(animated: true)
                        return
                    }
                    self.groupIndex = target
                    let statuses = self.groups[target].statuses
                    let firstUnseen = statuses.firstIndex(where: { !$0.hasViewed })
                    self.statusIndex = self.ownerStatusesOnly
                        ? 0
                        : firstUnseen ?? 0
                }
                self.displayCurrentStatus()
            } catch {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }

    private func displayCurrentStatus() {
        guard let group = currentGroup, let status = currentStatus else {
            dismiss(animated: true)
            return
        }
        guard let expiresAt = ChitChatDateFormatter.date(from: status.expiresAt), expiresAt > Date() else {
            advance()
            return
        }

        stopTimer()
        progress = 0
        imageTask?.cancel()
        imageView.image = nil
        avatarView.configure(name: group.owner.name, urlString: group.owner.avatarUrl)
        ownerLabel.text = isOwner ? "My Status" : group.owner.name
        timeLabel.text = Self.time(status.createdAt)
        ownerActions.isHidden = !isOwner
        viewsButton.setTitle("\(status.viewCount) views", for: .normal)
        deleteButton.isEnabled = !isDeleting
        rebuildProgressViews(group: group)

        if status.type == .text {
            imageView.isHidden = true
            textLabel.isHidden = false
            textLabel.text = status.text
            view.backgroundColor = Self.backgroundColor(status.backgroundStyle)
        } else {
            imageView.isHidden = false
            textLabel.isHidden = true
            view.backgroundColor = .black
            loadImage(status.mediaUrl, statusID: status.id)
        }
        acknowledgeCurrentStatusIfNeeded()
        startTimerIfNeeded()
    }

    private func rebuildProgressViews(group: StatusGroup) {
        progressStack.arrangedSubviews.forEach {
            progressStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for index in group.statuses.indices {
            let bar = UIProgressView(progressViewStyle: .bar)
            bar.trackTintColor = UIColor.white.withAlphaComponent(0.35)
            bar.progressTintColor = .white
            bar.progress = index < statusIndex ? 1 : 0
            progressStack.addArrangedSubview(bar)
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil, isForeground, !isHolding, currentStatus != nil, presentedViewController == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let status = self.currentStatus,
               let expiresAt = ChitChatDateFormatter.date(from: status.expiresAt),
               expiresAt <= Date() {
                self.advance()
                return
            }
            self.progress += 0.02
            if let bar = self.progressStack.arrangedSubviews.indices.contains(self.statusIndex)
                ? self.progressStack.arrangedSubviews[self.statusIndex] as? UIProgressView
                : nil {
                bar.progress = min(1, self.progress)
            }
            if self.progress >= 1 {
                self.advance()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func acknowledgeCurrentStatusIfNeeded() {
        guard
            isForeground,
            !isOwner,
            let status = currentStatus,
            !acknowledgedStatusIDs.contains(status.id),
            let expiresAt = ChitChatDateFormatter.date(from: status.expiresAt),
            expiresAt > Date()
        else { return }
        acknowledgedStatusIDs.insert(status.id)
        Task { [weak self] in
            do {
                _ = try await self?.statusService.markViewed(statusID: status.id)
            } catch {
                await MainActor.run {
                    self?.acknowledgedStatusIDs.remove(status.id)
                }
            }
        }
    }

    private func advance() {
        stopTimer()
        guard let group = currentGroup else {
            dismiss(animated: true)
            return
        }
        if statusIndex < group.statuses.count - 1 {
            statusIndex += 1
            displayCurrentStatus()
        } else if groupIndex < groups.count - 1 {
            groupIndex += 1
            statusIndex = 0
            displayCurrentStatus()
        } else {
            dismiss(animated: true)
        }
    }

    private func goBack() {
        stopTimer()
        if statusIndex > 0 {
            statusIndex -= 1
            displayCurrentStatus()
        } else if groupIndex > 0 {
            groupIndex -= 1
            statusIndex = max(0, groups[groupIndex].statuses.count - 1)
            displayCurrentStatus()
        } else {
            startTimerIfNeeded()
        }
    }

    private func loadImage(_ rawURL: String, statusID: String) {
        guard let url = APIClient.shared.resolvedURL(for: rawURL) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard self?.currentStatus?.id == statusID else { return }
                self?.imageView.image = image
            }
        }
        imageTask?.resume()
    }

    private func normalize(_ input: [StatusGroup]) -> [StatusGroup] {
        var groupsByOwner: [String: StatusGroup] = [:]
        for group in input {
            let statuses = Dictionary(grouping: group.statuses, by: \.id)
                .compactMap { $0.value.last }
                .filter { status in
                    guard let expiresAt = ChitChatDateFormatter.date(from: status.expiresAt) else { return false }
                    return expiresAt > Date()
                }
                .sorted { Self.date($0.createdAt) < Self.date($1.createdAt) }
            guard let latest = statuses.last else { continue }
            groupsByOwner[group.owner.id] = StatusGroup(
                owner: group.owner,
                statuses: statuses,
                hasUnseen: statuses.contains { !$0.hasViewed },
                latestCreatedAt: latest.createdAt
            )
        }
        return groupsByOwner.values.sorted { Self.date($0.latestCreatedAt) > Self.date($1.latestCreatedAt) }
    }

    private func findStatus(_ statusID: String) -> (group: Int, status: Int)? {
        for (groupIndex, group) in groups.enumerated() {
            if let statusIndex = group.statuses.firstIndex(where: { $0.id == statusID }) {
                return (groupIndex, statusIndex)
            }
        }
        return nil
    }

    private func presentViewerList() {
        guard let viewers = currentStatus?.viewers else { return }
        stopTimer()
        let controller = StatusViewerListViewController(viewers: viewers) { [weak self] in
            self?.startTimerIfNeeded()
        }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet
        navigation.presentationController?.delegate = self
        present(navigation, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        startTimerIfNeeded()
    }

    @objc private func viewersTapped() {
        presentViewerList()
    }

    @objc private func deleteTapped() {
        guard let status = currentStatus, isOwner, !isDeleting else { return }
        stopTimer()
        let alert = UIAlertController(
            title: "Delete status?",
            message: "This status will be removed for all eligible contacts.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.startTimerIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.isDeleting = true
            self.deleteButton.isEnabled = false
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    self.isDeleting = false
                    self.deleteButton.isEnabled = true
                }
                do {
                    _ = try await self.statusService.delete(statusID: status.id)
                    self.loadGroups(preservingCurrentStatusID: nil)
                } catch {
                    self.showAlert(message: error.localizedDescription)
                    self.startTimerIfNeeded()
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func previousTapped() {
        let isTap = holdStartedAt.map { CACurrentMediaTime() - $0 < 0.35 } ?? true
        isHolding = false
        holdStartedAt = nil
        if isTap {
            goBack()
        } else {
            startTimerIfNeeded()
        }
    }

    @objc private func nextTapped() {
        let isTap = holdStartedAt.map { CACurrentMediaTime() - $0 < 0.35 } ?? true
        isHolding = false
        holdStartedAt = nil
        if isTap {
            advance()
        } else {
            startTimerIfNeeded()
        }
    }

    @objc private func holdBegan() {
        holdStartedAt = CACurrentMediaTime()
        isHolding = true
        stopTimer()
    }

    @objc private func holdEnded() {
        isHolding = false
        holdStartedAt = nil
        startTimerIfNeeded()
    }

    private static func date(_ value: String) -> Date {
        ChitChatDateFormatter.date(from: value) ?? .distantPast
    }

    private static func time(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date(value))
    }

    private static func backgroundColor(_ style: String) -> UIColor {
        switch style {
        case "purple": return UIColor(red: 0.39, green: 0.28, blue: 0.67, alpha: 1)
        case "blue": return UIColor(red: 0.10, green: 0.48, blue: 0.67, alpha: 1)
        case "pink": return UIColor(red: 0.69, green: 0.24, blue: 0.46, alpha: 1)
        case "green": return UIColor(red: 0.24, green: 0.53, blue: 0.30, alpha: 1)
        case "orange": return UIColor(red: 0.68, green: 0.38, blue: 0.17, alpha: 1)
        default: return UIColor(red: 0.09, green: 0.55, blue: 0.46, alpha: 1)
        }
    }
}
