import UIKit

final class ChatsViewController: BaseViewController {
    private let currentUser: User
    private let chatService: ChatService

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let searchContainer = UIView()
    private let searchField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIView()
    private let emptyTitle = UILabel()
    private let emptyText = UILabel()

    private var chats: [Chat] = []
    private var filteredChats: [Chat] = []
    private var animatedChatIDs = Set<String>()
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false
    private var errorMessage: String?
    private var socketObservers: [NSObjectProtocol] = []

    init(currentUser: User, chatService: ChatService = ChatService()) {
        self.currentUser = currentUser
        self.chatService = chatService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.chatsScreen
        configureHeader()
        configureTable()
        configureEmptyState()
        observeRealtimeUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        loadChats(showLoadingState: !hasLoaded)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    deinit {
        loadTask?.cancel()
        socketObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func configureHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = ChitChatColors.chatsHeader

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedText = NSAttributedString(
            string: "Chats",
            attributes: [
                .font: ChitChatTypography.chatsHeaderTitle,
                .foregroundColor: ChitChatColors.textPrimary,
                .kern: -0.3
            ]
        )

        let searchAction = makeHeaderButton(
            symbol: "magnifyingglass",
            accessibilityLabel: "Search chats",
            action: #selector(focusSearch)
        )
        let editAction = makeHeaderButton(
            symbol: "square.and.pencil",
            accessibilityLabel: "Start a new chat",
            action: #selector(startNewChat(_:))
        )
        let moreAction = makeHeaderButton(
            symbol: "ellipsis",
            accessibilityLabel: "Open chats menu",
            action: #selector(openChatsMenu)
        )
        moreAction.transform = CGAffineTransform(rotationAngle: .pi / 2)

        let actionStack = UIStackView(arrangedSubviews: [searchAction, editAction, moreAction])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = ChitChatSpacing.chatsHeaderActionGap

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.backgroundColor = ChitChatColors.chatsSearch
        searchContainer.layer.cornerRadius = ChitChatSpacing.chatsSearchRadius
        searchContainer.layer.cornerCurve = .continuous

        let searchIcon = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            )
        )
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.tintColor = ChitChatColors.textMuted
        searchIcon.contentMode = .scaleAspectFit

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.backgroundColor = .clear
        searchField.textColor = ChitChatColors.textPrimary
        searchField.tintColor = ChitChatColors.accent
        searchField.font = ChitChatTypography.chatsSearch
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search chats...",
            attributes: [
                .font: ChitChatTypography.chatsSearch,
                .foregroundColor: ChitChatColors.chatsPlaceholder
            ]
        )
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.chatsDivider

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(actionStack)
        headerView.addSubview(searchContainer)
        headerView.addSubview(divider)
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchField)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            titleLabel.leadingAnchor.constraint(
                equalTo: headerView.leadingAnchor,
                constant: ChitChatSpacing.chatsHeaderHorizontal
            ),
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: ChitChatSpacing.chatsHeaderTop
            ),
            titleLabel.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),

            actionStack.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: -ChitChatSpacing.chatsHeaderHorizontal
            ),
            actionStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            searchAction.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),
            searchAction.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),
            editAction.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),
            editAction.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),
            moreAction.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),
            moreAction.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsHeaderActionSize),

            searchContainer.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: ChitChatSpacing.chatsHeaderRowBottom
            ),
            searchContainer.leadingAnchor.constraint(
                equalTo: headerView.leadingAnchor,
                constant: ChitChatSpacing.chatsHeaderHorizontal
            ),
            searchContainer.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: -ChitChatSpacing.chatsHeaderHorizontal
            ),
            searchContainer.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsSearchHeight),
            searchContainer.bottomAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: -ChitChatSpacing.chatsHeaderBottom
            ),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchIcon.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 16),
            searchIcon.widthAnchor.constraint(equalToConstant: 22),
            searchIcon.heightAnchor.constraint(equalToConstant: 22),

            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 52),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -14),
            searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func makeHeaderButton(
        symbol: String,
        accessibilityLabel: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = ChitChatColors.textMuted
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            ),
            for: .normal
        )
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(headerButtonDown(_:)), for: .touchDown)
        button.addTarget(
            self,
            action: #selector(headerButtonUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        return button
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = ChitChatColors.chatsScreen
        tableView.separatorStyle = .none
        tableView.rowHeight = ChitChatSpacing.chatsRowHeight
        tableView.estimatedRowHeight = ChitChatSpacing.chatsRowHeight
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: ChitChatSpacing.chatsListBottom + 12,
            right: 0
        )
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChatCell.self, forCellReuseIdentifier: ChatCell.reuseIdentifier)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        let refresh = UIRefreshControl()
        refresh.tintColor = ChitChatColors.accent
        refresh.addTarget(self, action: #selector(refreshChats), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureEmptyState() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isUserInteractionEnabled = false

        emptyTitle.translatesAutoresizingMaskIntoConstraints = false
        emptyTitle.font = ChitChatTypography.chatsEmptyTitle
        emptyTitle.textColor = ChitChatColors.textPrimary
        emptyTitle.textAlignment = .center

        emptyText.translatesAutoresizingMaskIntoConstraints = false
        emptyText.font = ChitChatTypography.chatsEmptyText
        emptyText.textColor = ChitChatColors.textMuted
        emptyText.textAlignment = .center
        emptyText.numberOfLines = 0

        view.addSubview(emptyView)
        emptyView.addSubview(emptyTitle)
        emptyView.addSubview(emptyText)

        NSLayoutConstraint.activate([
            emptyView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyTitle.topAnchor.constraint(equalTo: emptyView.topAnchor, constant: 60),
            emptyTitle.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 24),
            emptyTitle.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -24),

            emptyText.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 4),
            emptyText.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 24),
            emptyText.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -24)
        ])

        updateEmptyState()
    }

    private func loadChats(showLoadingState: Bool) {
        guard loadTask == nil else { return }
        if showLoadingState {
            emptyView.isHidden = true
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await chatService.listChats()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.chats = loaded.sorted(by: self.sortChats)
                    self.errorMessage = nil
                    self.hasLoaded = true
                    self.applySearch()
                    self.updateErrorBanner()
                    self.tableView.refreshControl?.endRefreshing()
                    self.loadTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.hasLoaded = true
                    self.applySearch()
                    self.updateErrorBanner()
                    self.tableView.refreshControl?.endRefreshing()
                    self.loadTask = nil
                }
            }
        }
    }

    private func sortChats(_ left: Chat, _ right: Chat) -> Bool {
        let leftDate = ChitChatDateFormatter.date(from: left.lastMessageAt ?? left.updatedAt) ?? .distantPast
        let rightDate = ChitChatDateFormatter.date(from: right.lastMessageAt ?? right.updatedAt) ?? .distantPast
        return leftDate > rightDate
    }

    private func observeRealtimeUpdates() {
        socketObservers.append(
            NotificationCenter.default.addObserver(
                forName: .socketChatUpdated,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self, let chat = notification.object as? Chat else { return }
                self.mergeRealtimeChat(chat)
            }
        )
        socketObservers.append(
            NotificationCenter.default.addObserver(
                forName: .socketPresenceUpdated,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self, let event = notification.object as? SocketPresenceEvent else { return }
                self.mergePresence(event)
            }
        )
    }

    private func mergeRealtimeChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            guard chats[index] != chat else { return }
            chats[index] = chat
        } else {
            chats.append(chat)
        }
        chats.sort(by: sortChats)
        errorMessage = nil
        hasLoaded = true
        applySearch()
        updateErrorBanner()
    }

    private func mergePresence(_ event: SocketPresenceEvent) {
        var changed = false
        chats = chats.map { chat in
            let updated = chat.updatingPresence(
                userId: event.userId,
                isOnline: event.isOnline,
                lastSeenAt: event.lastSeenAt
            )
            if updated != chat { changed = true }
            return updated
        }
        guard changed else { return }
        applySearch()
    }

    private func applySearch() {
        let query = searchField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if query.isEmpty {
            filteredChats = chats
        } else {
            filteredChats = chats.filter {
                $0.displayName(viewerUserId: currentUser.id).lowercased().contains(query)
                    || $0.lastMessagePreview.lowercased().contains(query)
            }
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        guard hasLoaded else {
            emptyView.isHidden = true
            return
        }
        let isSearching = !(searchField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        emptyTitle.text = isSearching ? "No chats found" : "No chats yet"
        emptyText.text = isSearching ? "Try another search term" : "Start a chat from your contacts"
        emptyView.isHidden = !filteredChats.isEmpty
    }

    private func updateErrorBanner() {
        guard let errorMessage, !errorMessage.isEmpty else {
            tableView.tableHeaderView = nil
            return
        }

        let width = max(tableView.bounds.width, view.bounds.width)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 58))
        container.backgroundColor = ChitChatColors.chatsScreen

        let banner = UIView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.backgroundColor = ChitChatColors.chatsRow
        banner.layer.cornerRadius = 14
        banner.layer.borderWidth = 1
        banner.layer.borderColor = ChitChatColors.chatsDivider.cgColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = errorMessage
        label.textColor = ChitChatColors.textMuted
        label.font = ChitChatTypography.chatsError
        label.numberOfLines = 2

        container.addSubview(banner)
        banner.addSubview(label)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            banner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10)
        ])
        tableView.tableHeaderView = container
    }

    @objc private func searchChanged() {
        applySearch()
    }

    @objc private func focusSearch() {
        searchField.becomeFirstResponder()
    }

    @objc private func startNewChat(_ sender: UIButton) {
        guard presentedViewController == nil else { return }

        let sheet = UIAlertController(title: "Start a chat", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New chat", style: .default) { [weak self] _ in
            self?.tabBarController?.selectedIndex = 1
        })
        sheet.addAction(UIAlertAction(title: "New group", style: .default) { [weak self] _ in
            self?.openGroupCreation()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    private func openGroupCreation() {
        guard let navigationController else { return }
        let controller = GroupMemberSelectionViewController(
            currentUser: currentUser,
            chatService: chatService
        ) { [weak self] chat in
            self?.mergeRealtimeChat(chat)
        }
        navigationController.pushViewController(controller, animated: true)
    }

    @objc private func openChatsMenu() {
        // HomeMenu actions are not part of the native Phase 2 feature set.
    }

    @objc private func headerButtonDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = sender.transform.scaledBy(x: 0.9, y: 0.9)
        }
    }

    @objc private func headerButtonUp(_ sender: UIButton) {
        let rotation: CGFloat = sender.accessibilityLabel == "Open chats menu" ? .pi / 2 : 0
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.2
        ) {
            sender.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }

    @objc private func refreshChats() {
        loadChats(showLoadingState: false)
    }
}

extension ChatsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension ChatsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredChats.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ChatCell.reuseIdentifier,
            for: indexPath
        ) as? ChatCell else {
            return UITableViewCell()
        }
        cell.configure(chat: filteredChats[indexPath.row], viewerUserId: currentUser.id)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let chatID = filteredChats[indexPath.row].id
        guard !animatedChatIDs.contains(chatID) else { return }
        animatedChatIDs.insert(chatID)

        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(
            withDuration: 0.26,
            delay: Double(indexPath.row) * 0.035,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let chat = filteredChats[indexPath.row]
        navigationController?.pushViewController(
            ChatDetailViewController(chat: chat, currentUser: currentUser),
            animated: true
        )
    }
}
