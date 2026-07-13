import UIKit

private final class StatusOwnerControl: UIControl {
    let ownerID: String

    init(ownerID: String) {
        self.ownerID = ownerID
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

final class UpdatesViewController: BaseViewController {
    private let initialUser: User
    private let statusService = StatusService()
    private let stripScroll = UIScrollView()
    private let stripStack = UIStackView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let refreshControl = UIRefreshControl()
    private var observers: [NSObjectProtocol] = []
    private var feed: [StatusGroup] = []
    private var mine: StatusGroup?
    private var searchQuery = ""
    private var isLoading = false
    private var reloadRequested = false
    private var expiryTimer: Timer?

    private var currentUser: User {
        SessionManager.shared.authenticatedUser ?? initialUser
    }

    init(currentUser: User) {
        initialUser = currentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        expiryTimer?.invalidate()
        removeRealtimeObservers()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if observers.isEmpty {
            observeRealtime()
        }
        loadStatuses(showSpinner: feed.isEmpty && mine == nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        expiryTimer?.invalidate()
        expiryTimer = nil
        removeRealtimeObservers()
    }

    private func buildUI() {
        let header = makeHeader()

        stripScroll.translatesAutoresizingMaskIntoConstraints = false
        stripScroll.backgroundColor = ChitChatColors.header
        stripScroll.showsHorizontalScrollIndicator = false
        stripStack.translatesAutoresizingMaskIntoConstraints = false
        stripStack.axis = .horizontal
        stripStack.spacing = 12
        stripStack.isLayoutMarginsRelativeArrangement = true
        stripStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 10, right: 16)
        stripScroll.addSubview(stripStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        refreshControl.tintColor = ChitChatColors.accent
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        scrollView.addSubview(contentStack)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = ChitChatColors.accent

        view.addSubview(header)
        view.addSubview(stripScroll)
        view.addSubview(scrollView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            stripScroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            stripScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripScroll.heightAnchor.constraint(equalToConstant: 92),
            stripStack.topAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.topAnchor),
            stripStack.leadingAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.leadingAnchor),
            stripStack.trailingAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.trailingAnchor),
            stripStack.bottomAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.bottomAnchor),
            stripStack.heightAnchor.constraint(equalTo: stripScroll.frameLayoutGuide.heightAnchor),

            scrollView.topAnchor.constraint(equalTo: stripScroll.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -110),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Updates"
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 22, weight: .bold)

        let search = makeIcon("magnifyingglass", selector: #selector(searchTapped))
        let create = makeIcon("ellipsis", selector: #selector(createTapped))
        let actions = UIStackView(arrangedSubviews: [search, create])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .horizontal
        actions.spacing = 2

        header.addSubview(title)
        header.addSubview(actions)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
            actions.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            actions.centerYAnchor.constraint(equalTo: title.centerYAnchor)
        ])
        return header
    }

    private func observeRealtime() {
        let names: [Notification.Name] = [
            .socketConnected,
            .socketStatusCreated,
            .socketStatusDeleted,
            .socketStatusViewed,
            SessionManager.currentUserDidChange
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.loadStatuses(showSpinner: false)
            }
        }
    }

    private func removeRealtimeObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func loadStatuses(showSpinner: Bool) {
        guard !isLoading else {
            reloadRequested = true
            return
        }
        isLoading = true
        if showSpinner { activityIndicator.startAnimating() }

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isLoading = false
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                if self.reloadRequested {
                    self.reloadRequested = false
                    self.loadStatuses(showSpinner: false)
                }
            }
            do {
                async let feedRequest = self.statusService.feed()
                async let mineRequest = self.statusService.mine()
                let (feed, mine) = try await (feedRequest, mineRequest)
                self.feed = self.normalize(groups: feed)
                self.mine = mine.statuses.isEmpty ? nil : self.normalize(group: mine)
                self.render()
            } catch {
                self.renderError(error.localizedDescription)
            }
        }
    }

    private func render() {
        clear(stack: stripStack)
        clear(stack: contentStack)

        let myOwner = StatusOwner(
            id: currentUser.id,
            name: currentUser.name.isEmpty ? "You" : currentUser.name,
            avatarUrl: currentUser.avatarUrl
        )
        stripStack.addArrangedSubview(
            makeStripItem(owner: myOwner, unseen: mine != nil, showsPlus: mine == nil)
        )
        filteredFeed.forEach {
            stripStack.addArrangedSubview(makeStripItem(owner: $0.owner, unseen: $0.hasUnseen, showsPlus: false))
        }

        contentStack.addArrangedSubview(makeMyStatus(owner: myOwner))
        let recent = filteredFeed.filter(\.hasUnseen)
        let viewed = filteredFeed.filter { !$0.hasUnseen }

        if !recent.isEmpty {
            contentStack.addArrangedSubview(makeSectionTitle("RECENT UPDATES", top: 10))
            recent.forEach { contentStack.addArrangedSubview(makeStatusRow($0)) }
        }
        if !viewed.isEmpty {
            contentStack.addArrangedSubview(makeSectionTitle("VIEWED UPDATES", top: 18))
            viewed.forEach { contentStack.addArrangedSubview(makeStatusRow($0)) }
        }
        if recent.isEmpty && viewed.isEmpty {
            contentStack.addArrangedSubview(makeEmptyState())
        }
        scheduleNextExpiry()
    }

    private var filteredFeed: [StatusGroup] {
        guard !searchQuery.isEmpty else { return feed }
        return feed.filter { $0.owner.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private func renderError(_ message: String) {
        expiryTimer?.invalidate()
        expiryTimer = nil
        clear(stack: contentStack)
        let wrap = UIView()
        wrap.heightAnchor.constraint(equalToConstant: 180).isActive = true
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = .center
        label.numberOfLines = 3
        let retry = UIButton(type: .system)
        retry.translatesAutoresizingMaskIntoConstraints = false
        retry.setTitle("Retry", for: .normal)
        retry.setTitleColor(ChitChatColors.accent, for: .normal)
        retry.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        wrap.addSubview(label)
        wrap.addSubview(retry)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -28),
            label.centerYAnchor.constraint(equalTo: wrap.centerYAnchor, constant: -18),
            retry.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            retry.centerXAnchor.constraint(equalTo: wrap.centerXAnchor)
        ])
        contentStack.addArrangedSubview(wrap)
    }

    private func makeStripItem(owner: StatusOwner, unseen: Bool, showsPlus: Bool) -> UIView {
        let control = StatusOwnerControl(ownerID: owner.id)
        control.widthAnchor.constraint(equalToConstant: 64).isActive = true
        control.addTarget(self, action: #selector(ownerTapped(_:)), for: .touchUpInside)
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: owner.name, urlString: owner.avatarUrl)
        avatar.layer.borderWidth = 3
        avatar.layer.borderColor = (unseen ? ChitChatColors.accent : ChitChatColors.textMuted.withAlphaComponent(0.3)).cgColor
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = owner.id == currentUser.id ? "Your Status" : firstName(owner.name)
        label.textColor = unseen || owner.id == currentUser.id ? ChitChatColors.textPrimary : ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        control.addSubview(avatar)
        control.addSubview(label)
        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: control.topAnchor),
            avatar.centerXAnchor.constraint(equalTo: control.centerXAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 52),
            avatar.heightAnchor.constraint(equalToConstant: 52),
            label.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: control.trailingAnchor)
        ])
        if showsPlus { addPlusBadge(to: control, anchoredTo: avatar, size: 20) }
        return control
    }

    private func makeMyStatus(owner: StatusOwner) -> UIView {
        let control = StatusOwnerControl(ownerID: owner.id)
        control.heightAnchor.constraint(equalToConstant: 88).isActive = true
        control.addTarget(self, action: #selector(ownerTapped(_:)), for: .touchUpInside)
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: owner.name, urlString: owner.avatarUrl)
        avatar.layer.borderWidth = mine == nil ? 0 : 3
        avatar.layer.borderColor = ChitChatColors.accent.cgColor
        let title = makeLabel("My Status", size: 15, weight: .bold, color: ChitChatColors.textPrimary)
        let subtitle = makeLabel(
            mine.map { relativeTime($0.latestCreatedAt) } ?? "Tap to add status update",
            size: 12,
            weight: .regular,
            color: ChitChatColors.textMuted
        )
        control.addSubview(avatar)
        control.addSubview(title)
        control.addSubview(subtitle)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 20),
            avatar.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            title.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3)
        ])
        if mine == nil { addPlusBadge(to: control, anchoredTo: avatar, size: 24) }
        return control
    }

    private func makeStatusRow(_ group: StatusGroup) -> UIView {
        let control = StatusOwnerControl(ownerID: group.owner.id)
        control.heightAnchor.constraint(equalToConstant: 76).isActive = true
        control.addTarget(self, action: #selector(ownerTapped(_:)), for: .touchUpInside)
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: group.owner.name, urlString: group.owner.avatarUrl)
        avatar.layer.borderWidth = 3
        avatar.layer.borderColor = (group.hasUnseen ? ChitChatColors.accent : ChitChatColors.textMuted.withAlphaComponent(0.3)).cgColor
        let name = makeLabel(group.owner.name, size: 15, weight: group.hasUnseen ? .bold : .semibold, color: ChitChatColors.textPrimary)
        let time = makeLabel(relativeTime(group.latestCreatedAt), size: 12, weight: .regular, color: ChitChatColors.textMuted)
        control.addSubview(avatar)
        control.addSubview(name)
        control.addSubview(time)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 24),
            avatar.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            name.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 8),
            name.trailingAnchor.constraint(lessThanOrEqualTo: control.trailingAnchor, constant: -20),
            time.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            time.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3)
        ])
        return control
    }

    private func makeSectionTitle(_ text: String, top: CGFloat) -> UIView {
        let wrap = UIView()
        wrap.heightAnchor.constraint(equalToConstant: top + 22).isActive = true
        let label = makeLabel(text, size: 11, weight: .bold, color: ChitChatColors.textMuted)
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -8)
        ])
        return wrap
    }

    private func makeEmptyState() -> UIView {
        let wrap = UIView()
        wrap.heightAnchor.constraint(equalToConstant: 190).isActive = true
        let title = makeLabel("No updates yet", size: 17, weight: .bold, color: ChitChatColors.textPrimary)
        let subtitle = makeLabel("Contact updates stay here for 24 hours.", size: 13, weight: .regular, color: ChitChatColors.textMuted)
        subtitle.textAlignment = .center
        wrap.addSubview(title)
        wrap.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: wrap.centerYAnchor, constant: -10),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.centerXAnchor.constraint(equalTo: wrap.centerXAnchor)
        ])
        return wrap
    }

    private func addPlusBadge(to container: UIView, anchoredTo avatar: UIView, size: CGFloat) {
        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "+"
        badge.textAlignment = .center
        badge.font = UIFont.systemFont(ofSize: size * 0.68, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = ChitChatColors.accent
        badge.layer.cornerRadius = size / 2
        badge.clipsToBounds = true
        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 2),
            badge.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 1),
            badge.widthAnchor.constraint(equalToConstant: size),
            badge.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = color
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        return label
    }

    private func makeIcon(_ symbol: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = ChitChatColors.textMuted
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    private func clear(stack: UIStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func normalize(group: StatusGroup) -> StatusGroup {
        let now = Date()
        let byID = Dictionary(grouping: group.statuses, by: \.id)
            .compactMap { $0.value.last }
            .filter {
                guard let expiresAt = ChitChatDateFormatter.date(from: $0.expiresAt) else { return false }
                return expiresAt > now
            }
        let statuses = byID.sorted { date($0.createdAt) < date($1.createdAt) }
        return StatusGroup(
            owner: group.owner,
            statuses: statuses,
            hasUnseen: statuses.contains { !$0.hasViewed },
            latestCreatedAt: statuses.last?.createdAt ?? group.latestCreatedAt
        )
    }

    private func normalize(groups: [StatusGroup]) -> [StatusGroup] {
        groups.map { normalize(group: $0) }.filter { !$0.statuses.isEmpty }.sorted {
            date($0.latestCreatedAt) > date($1.latestCreatedAt)
        }
    }

    private func scheduleNextExpiry() {
        expiryTimer?.invalidate()
        let groups = (mine.map { [$0] } ?? []) + feed
        let expirations = groups
            .flatMap(\.statuses)
            .compactMap { ChitChatDateFormatter.date(from: $0.expiresAt) }
            .filter { $0 > Date() }
        guard let nextExpiry = expirations.min() else {
            expiryTimer = nil
            return
        }
        expiryTimer = Timer.scheduledTimer(
            withTimeInterval: max(0.1, nextExpiry.timeIntervalSinceNow + 0.1),
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.feed = self.normalize(groups: self.feed)
            if let mine = self.mine {
                let normalizedMine = self.normalize(group: mine)
                self.mine = normalizedMine.statuses.isEmpty ? nil : normalizedMine
            }
            self.render()
            self.loadStatuses(showSpinner: false)
        }
    }

    private func date(_ value: String) -> Date {
        ChitChatDateFormatter.date(from: value) ?? .distantPast
    }

    private func relativeTime(_ value: String) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date(value)))
        if elapsed < 60 { return "Just now" }
        if elapsed < 3_600 { return "\(max(1, Int(elapsed / 60))) min ago" }
        return "\(max(1, Int(elapsed / 3_600))) hours ago"
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    @objc private func refreshPulled() {
        loadStatuses(showSpinner: false)
    }

    @objc private func retryTapped() {
        loadStatuses(showSpinner: true)
    }

    @objc private func createTapped() {
        presentCreation()
    }

    @objc private func searchTapped() {
        let alert = UIAlertController(title: "Search updates", message: nil, preferredStyle: .alert)
        alert.addTextField { [searchQuery] field in
            field.placeholder = "Contact name"
            field.text = searchQuery
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self, weak alert] _ in
            self?.searchQuery = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self?.render()
        })
        if !searchQuery.isEmpty {
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
                self?.searchQuery = ""
                self?.render()
            })
        }
        present(alert, animated: true)
    }

    @objc private func ownerTapped(_ sender: UIControl) {
        guard let sender = sender as? StatusOwnerControl else { return }
        if sender.ownerID == currentUser.id, mine == nil {
            presentCreation()
            return
        }
        let viewer = StatusViewerViewController(ownerID: sender.ownerID)
        viewer.modalPresentationStyle = .fullScreen
        present(viewer, animated: true)
    }

    private func presentCreation() {
        let controller = StatusCreationViewController()
        controller.onCreated = { [weak self] in self?.loadStatuses(showSpinner: false) }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }
}
