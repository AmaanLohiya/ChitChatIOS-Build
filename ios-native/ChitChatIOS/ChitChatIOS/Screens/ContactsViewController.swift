import UIKit

private struct ContactsSection {
    let title: String
    let contacts: [Contact]
}

private enum ContactsSortDirection: Equatable {
    case ascending
    case descending
}

private enum DeviceContactSyncUIState: Equatable {
    case checking
    case permissionRequired
    case syncing
    case denied
    case restricted
    case emptyAddressBook
    case noMatches
    case synced(Int)
    case failed

    var copy: (title: String, subtitle: String) {
        switch self {
        case .checking:
            return ("Find ChitChat contacts", "Checking contact access...")
        case .permissionRequired:
            return ("Find ChitChat contacts", "Match your address book securely")
        case .syncing:
            return ("Matching contacts", "Checking who is on ChitChat...")
        case .denied:
            return ("Contacts access denied", "Open Settings to match contacts")
        case .restricted:
            return ("Contacts access restricted", "Contact access is restricted on this device")
        case .emptyAddressBook:
            return ("No phone contacts found", "Add phone numbers, then refresh")
        case .noMatches:
            return ("No registered contacts found", "Your saved contacts remain available")
        case let .synced(count):
            let noun = count == 1 ? "contact is" : "contacts are"
            return ("Contacts matched", "\(count) address-book \(noun) on ChitChat")
        case .failed:
            return ("Contact sync failed", "Check your connection and tap to retry")
        }
    }
}

private final class ContactsMenuButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? ChitChatColors.contactsMenuPressed : .clear
        }
    }
}

final class ContactsViewController: BaseViewController {
    private let currentUser: User
    private let contactService: ContactService
    private let chatService: ChatService
    private let deviceContactsService: DeviceContactsService

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let searchContainer = UIView()
    private let searchField = UITextField()
    private let addButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var syncRow = UIView()
    private var syncGlow = UIView()

    private var contacts: [Contact] = []
    private var sections: [ContactsSection] = []
    private var animatedContactIDs = Set<String>()
    private var sortDirection: ContactsSortDirection = .ascending
    private var errorMessage: String?
    private var menuOverlay: UIView?
    private var loadTask: Task<Void, Never>?
    private var openChatTask: Task<Void, Never>?
    private var hasLoaded = false
    private var deviceSyncState: DeviceContactSyncUIState = .checking

    init(
        currentUser: User,
        contactService: ContactService = ContactService(),
        chatService: ChatService = ChatService(),
        deviceContactsService: DeviceContactsService = DeviceContactsService()
    ) {
        self.currentUser = currentUser
        self.contactService = contactService
        self.chatService = chatService
        self.deviceContactsService = deviceContactsService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.contactsScreen
        configureHeader()
        configureTable()
        updateListHeader()
        updateEmptyState()
        startSyncGlow()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        loadContacts(showLoadingState: !hasLoaded)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissSortMenu(animated: false)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    deinit {
        loadTask?.cancel()
        openChatTask?.cancel()
        syncGlow.layer.removeAllAnimations()
        NotificationCenter.default.removeObserver(self)
    }

    private func configureHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = ChitChatColors.contactsHeader

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedText = NSAttributedString(
            string: "Contacts",
            attributes: [
                .font: ChitChatTypography.contactsHeaderTitle,
                .foregroundColor: ChitChatColors.textPrimary,
                .kern: -0.25
            ]
        )

        configureHeaderButton(
            addButton,
            symbol: "person.badge.plus",
            color: ChitChatColors.accent,
            accessibilityLabel: "Add contact",
            action: #selector(addContact)
        )

        let moreButton = UIButton(type: .system)
        configureHeaderButton(
            moreButton,
            symbol: "ellipsis",
            color: ChitChatColors.textMuted,
            accessibilityLabel: "Open contacts menu",
            action: #selector(toggleSortMenu)
        )
        moreButton.transform = CGAffineTransform(rotationAngle: .pi / 2)

        let actionStack = UIStackView(arrangedSubviews: [addButton, moreButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = ChitChatSpacing.contactsHeaderActionGap

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.backgroundColor = ChitChatColors.contactsSearch
        searchContainer.layer.cornerRadius = ChitChatSpacing.contactsSearchRadius
        searchContainer.layer.cornerCurve = .continuous

        let searchIcon = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            )
        )
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.tintColor = ChitChatColors.textMuted
        searchIcon.contentMode = .scaleAspectFit

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
            attributes: [
                .font: ChitChatTypography.contactsSearch,
                .foregroundColor: ChitChatColors.chatsPlaceholder
            ]
        )
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.contactsBorder

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
                constant: ChitChatSpacing.contactsHeaderHorizontal
            ),
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: ChitChatSpacing.contactsHeaderTop
            ),
            titleLabel.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsHeaderActionSize),

            actionStack.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: -ChitChatSpacing.contactsHeaderHorizontal
            ),
            actionStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsHeaderActionSize),
            addButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsHeaderActionSize),
            moreButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsHeaderActionSize),
            moreButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsHeaderActionSize),

            searchContainer.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: ChitChatSpacing.contactsHeaderRowBottom
            ),
            searchContainer.leadingAnchor.constraint(
                equalTo: headerView.leadingAnchor,
                constant: ChitChatSpacing.contactsHeaderHorizontal
            ),
            searchContainer.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: -ChitChatSpacing.contactsHeaderHorizontal
            ),
            searchContainer.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsSearchHeight),
            searchContainer.bottomAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: -ChitChatSpacing.contactsHeaderBottom
            ),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -14),
            searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func configureHeaderButton(
        _ button: UIButton,
        symbol: String,
        color: UIColor,
        accessibilityLabel: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = color
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            ),
            for: .normal
        )
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = ChitChatColors.contactsScreen
        tableView.separatorStyle = .none
        tableView.rowHeight = ChitChatSpacing.contactsRowHeight
        tableView.estimatedRowHeight = ChitChatSpacing.contactsRowHeight
        tableView.sectionHeaderHeight = ChitChatSpacing.contactsSectionHeight
        tableView.estimatedSectionHeaderHeight = ChitChatSpacing.contactsSectionHeight
        tableView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: ChitChatSpacing.contactsListBottom,
            right: 0
        )
        tableView.showsVerticalScrollIndicator = true
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        let refresh = UIRefreshControl()
        refresh.tintColor = ChitChatColors.accent
        refresh.addTarget(self, action: #selector(refreshContacts), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func updateListHeader() {
        syncGlow.layer.removeAllAnimations()
        syncRow = UIView()
        syncGlow = UIView()

        let width = max(view.bounds.width, tableView.bounds.width)
        let errorHeight: CGFloat = errorMessage == nil ? 0 : 56
        let headerHeight: CGFloat = 92 + errorHeight
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: headerHeight))
        container.backgroundColor = ChitChatColors.contactsScreen
        container.autoresizingMask = [.flexibleWidth]

        syncRow.translatesAutoresizingMaskIntoConstraints = false
        syncRow.backgroundColor = .clear

        let inviteDivider = UIView()
        inviteDivider.translatesAutoresizingMaskIntoConstraints = false
        inviteDivider.backgroundColor = UIColor.white.withAlphaComponent(0.03)

        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .clear

        syncGlow.translatesAutoresizingMaskIntoConstraints = false
        syncGlow.backgroundColor = ChitChatColors.contactsInviteGlow
        syncGlow.layer.cornerRadius = ChitChatSpacing.contactsInviteIcon / 2
        syncGlow.alpha = 0.2

        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = ChitChatColors.accent
        iconCircle.layer.cornerRadius = ChitChatSpacing.contactsInviteIcon / 2

        let inviteIcon = UIImageView(
            image: UIImage(
                systemName: "person.badge.plus",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            )
        )
        inviteIcon.translatesAutoresizingMaskIntoConstraints = false
        inviteIcon.tintColor = .white
        inviteIcon.contentMode = .scaleAspectFit

        let syncCopy = deviceSyncState.copy
        let syncTitle = UILabel()
        syncTitle.translatesAutoresizingMaskIntoConstraints = false
        syncTitle.attributedText = NSAttributedString(
            string: syncCopy.title,
            attributes: [
                .font: ChitChatTypography.contactsInviteTitle,
                .foregroundColor: ChitChatColors.textPrimary,
                .kern: -0.2
            ]
        )

        let syncSubtitle = UILabel()
        syncSubtitle.translatesAutoresizingMaskIntoConstraints = false
        syncSubtitle.text = syncCopy.subtitle
        syncSubtitle.font = ChitChatTypography.contactsInviteSubtitle
        syncSubtitle.textColor = ChitChatColors.textMuted
        syncSubtitle.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [syncTitle, syncSubtitle])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let syncButton = UIButton(type: .custom)
        syncButton.translatesAutoresizingMaskIntoConstraints = false
        syncButton.accessibilityLabel = "\(syncCopy.title). \(syncCopy.subtitle)"
        syncButton.addTarget(self, action: #selector(deviceContactsTapped), for: .touchUpInside)
        syncButton.addTarget(self, action: #selector(syncPressed), for: .touchDown)
        syncButton.addTarget(
            self,
            action: #selector(syncReleased),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )

        container.addSubview(syncRow)
        syncRow.addSubview(iconWrap)
        iconWrap.addSubview(syncGlow)
        iconWrap.addSubview(iconCircle)
        iconCircle.addSubview(inviteIcon)
        syncRow.addSubview(textStack)
        syncRow.addSubview(inviteDivider)
        syncRow.addSubview(syncButton)

        NSLayoutConstraint.activate([
            syncRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            syncRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            syncRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            syncRow.heightAnchor.constraint(equalToConstant: 72),

            iconWrap.leadingAnchor.constraint(equalTo: syncRow.leadingAnchor, constant: 16),
            iconWrap.centerYAnchor.constraint(equalTo: syncRow.centerYAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),
            iconWrap.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),

            syncGlow.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            syncGlow.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            syncGlow.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),
            syncGlow.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),

            iconCircle.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconCircle.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),
            iconCircle.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsInviteIcon),

            inviteIcon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            inviteIcon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            inviteIcon.widthAnchor.constraint(equalToConstant: 15),
            inviteIcon.heightAnchor.constraint(equalToConstant: 15),

            textStack.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: syncRow.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: syncRow.centerYAnchor),
            syncTitle.heightAnchor.constraint(equalToConstant: 20),
            syncSubtitle.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

            inviteDivider.leadingAnchor.constraint(equalTo: syncRow.leadingAnchor),
            inviteDivider.trailingAnchor.constraint(equalTo: syncRow.trailingAnchor),
            inviteDivider.bottomAnchor.constraint(equalTo: syncRow.bottomAnchor),
            inviteDivider.heightAnchor.constraint(equalToConstant: 1),

            syncButton.topAnchor.constraint(equalTo: syncRow.topAnchor),
            syncButton.leadingAnchor.constraint(equalTo: syncRow.leadingAnchor),
            syncButton.trailingAnchor.constraint(equalTo: syncRow.trailingAnchor),
            syncButton.bottomAnchor.constraint(equalTo: syncRow.bottomAnchor)
        ])

        if let errorMessage {
            let banner = UIView()
            banner.translatesAutoresizingMaskIntoConstraints = false
            banner.backgroundColor = ChitChatColors.contactsRow
            banner.layer.cornerRadius = 14
            banner.layer.borderWidth = 1
            banner.layer.borderColor = ChitChatColors.contactsBorder.cgColor

            let errorLabel = UILabel()
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            errorLabel.text = errorMessage
            errorLabel.textColor = ChitChatColors.textMuted
            errorLabel.font = ChitChatTypography.contactsError
            errorLabel.numberOfLines = 2

            container.addSubview(banner)
            banner.addSubview(errorLabel)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: syncRow.bottomAnchor, constant: 10),
                banner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                banner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                banner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                errorLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
                errorLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
                errorLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
                errorLabel.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10)
            ])
        }

        tableView.tableHeaderView = container
    }

    private func startSyncGlow() {
        syncGlow.layer.removeAllAnimations()
        syncGlow.alpha = 0.2
        UIView.animate(
            withDuration: 1.2,
            delay: 0,
            options: [.autoreverse, .repeat, .allowUserInteraction]
        ) {
            self.syncGlow.alpha = 0.46
        }
    }

    private func loadContacts(
        showLoadingState: Bool,
        requestDevicePermission: Bool = false
    ) {
        guard loadTask == nil else { return }
        if showLoadingState {
            updateEmptyState(isLoading: true)
        }
        deviceSyncState = requestDevicePermission || deviceContactsService.authorizationState() == .granted
            ? .syncing
            : .checking
        updateListHeader()
        startSyncGlow()

        loadTask = Task { [weak self] in
            guard let self else { return }
            var loaded = self.contacts
            var listError: String?
            do {
                loaded = try await contactService.listContacts()
            } catch {
                listError = error.localizedDescription
            }

            guard !Task.isCancelled else { return }
            let syncResult = await self.synchronizeDeviceContacts(
                requestPermission: requestDevicePermission,
                serverContacts: loaded
            )
            if syncResult.refreshedServer {
                listError = nil
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.contacts = syncResult.contacts
                self.errorMessage = listError
                self.deviceSyncState = syncResult.state
                self.hasLoaded = true
                self.applySearch()
                self.updateListHeader()
                self.startSyncGlow()
                self.tableView.refreshControl?.endRefreshing()
                self.loadTask = nil
            }
        }
    }

    private func synchronizeDeviceContacts(
        requestPermission: Bool,
        serverContacts: [Contact]
    ) async -> (contacts: [Contact], state: DeviceContactSyncUIState, refreshedServer: Bool) {
        let authorization = requestPermission
            ? await deviceContactsService.requestAuthorization()
            : deviceContactsService.authorizationState()

        switch authorization {
        case .undetermined:
            return (serverContacts, .permissionRequired, false)
        case .denied:
            return (serverContacts, .denied, false)
        case .restricted:
            return (serverContacts, .restricted, false)
        case .granted:
            break
        }

        do {
            let snapshot = try await deviceContactsService.readSnapshot(defaultPhone: currentUser.phone)
            if snapshot.entries.isEmpty {
                deviceContactsService.rememberSuccessfulFingerprint(
                    snapshot.fingerprint,
                    for: currentUser.id
                )
                return (serverContacts, .emptyAddressBook, false)
            }

            let previousFingerprint = deviceContactsService.lastSuccessfulFingerprint(
                for: currentUser.id
            )
            let serverHasImportedContacts = serverContacts.contains { $0.source == .device }
            var latestContacts = serverContacts
            var refreshedServer = false

            if previousFingerprint != snapshot.fingerprint || !serverHasImportedContacts {
                for entries in deviceContactsService.importBatches(for: snapshot.entries) {
                    _ = try await contactService.importDeviceContacts(entries: entries)
                }
                latestContacts = try await contactService.listContacts()
                deviceContactsService.rememberSuccessfulFingerprint(
                    snapshot.fingerprint,
                    for: currentUser.id
                )
                refreshedServer = true
            }

            let registeredCount = latestContacts.filter {
                $0.source == .device && $0.contactUserId != nil
            }.count
            return (
                latestContacts,
                registeredCount > 0 ? .synced(registeredCount) : .noMatches,
                refreshedServer
            )
        } catch {
            // Keep the last good server list; failed imports never advance the fingerprint.
            return (serverContacts, .failed, false)
        }
    }

    private func applySearch() {
        let query = searchField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let visibleContacts = contacts.filter {
            $0.source == .app || $0.contactUserId != nil
        }
        let filtered = visibleContacts.filter { contact in
            guard !query.isEmpty else { return true }
            return contact.name.lowercased().contains(query)
                || contact.phoneNumber.lowercased().contains(query)
                || contact.label.lowercased().contains(query)
        }

        let sorted = filtered.sorted { left, right in
            let comparison = left.name.localizedCaseInsensitiveCompare(right.name)
            return sortDirection == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }

        func makeSections(_ contacts: [Contact], label: String) -> [ContactsSection] {
            var grouped: [String: [Contact]] = [:]
            contacts.forEach { contact in
                let trimmed = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.first.map { String($0).uppercased() } ?? "#"
                grouped[key, default: []].append(contact)
            }

            return grouped.keys.sorted().map {
                ContactsSection(title: "\(label) - \($0)", contacts: grouped[$0] ?? [])
            }
        }

        sections = makeSections(
            sorted.filter { $0.contactUserId != nil },
            label: "ON CHITCHAT"
        ) + makeSections(
            sorted.filter { $0.contactUserId == nil && $0.source == .app },
            label: "SAVED"
        )
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState(isLoading: Bool = false) {
        guard sections.isEmpty else {
            tableView.tableFooterView = UIView(frame: .zero)
            return
        }

        let width = max(view.bounds.width, tableView.bounds.width)
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 250))
        footer.backgroundColor = ChitChatColors.contactsScreen
        footer.autoresizingMask = [.flexibleWidth]

        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = ChitChatColors.contactsEmptyIcon
        iconCircle.layer.cornerRadius = 29

        let icon = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            )
        )
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.textMuted.withAlphaComponent(0.45)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = ChitChatTypography.contactsEmptyTitle
        title.textColor = ChitChatColors.textPrimary
        title.textAlignment = .center
        let isSearching = searchField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if isSearching {
            title.text = "No contacts found"
        } else if deviceSyncState == .noMatches {
            title.text = "No registered contacts found"
        } else {
            title.text = "No contacts yet"
        }
        title.isHidden = isLoading || !hasLoaded

        let text = UILabel()
        text.translatesAutoresizingMaskIntoConstraints = false
        text.font = ChitChatTypography.contactsEmptyText
        text.textColor = ChitChatColors.textMuted
        text.textAlignment = .center
        text.numberOfLines = 0
        if isLoading || !hasLoaded || deviceSyncState == .syncing {
            text.text = deviceSyncState == .syncing ? "Matching contacts..." : "Loading contacts..."
        } else if isSearching {
            text.text = "Try another search term"
        } else if deviceSyncState == .emptyAddressBook {
            text.text = "No phone numbers were found in your address book. Manual Add Contact remains available."
        } else {
            text.text = "Match device contacts above or add a contact manually to start chatting"
        }

        footer.addSubview(iconCircle)
        iconCircle.addSubview(icon)
        footer.addSubview(title)
        footer.addSubview(text)

        let textBelowTitle = text.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4)
        let textBelowIcon = text.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 10)
        textBelowTitle.isActive = !title.isHidden
        textBelowIcon.isActive = title.isHidden

        NSLayoutConstraint.activate([
            iconCircle.topAnchor.constraint(equalTo: footer.topAnchor, constant: 70),
            iconCircle.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 58),
            iconCircle.heightAnchor.constraint(equalToConstant: 58),
            icon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            title.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24),
            title.heightAnchor.constraint(equalToConstant: 20),

            text.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            text.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24)
        ])
        tableView.tableFooterView = footer
    }

    private func openDirectChat(for contact: Contact) {
        guard let contactUserId = contact.contactUserId else {
            showAlert(message: "This contact is not on ChitChat yet.")
            return
        }
        guard openChatTask == nil else { return }

        addButton.isEnabled = false
        openChatTask = Task { [weak self] in
            guard let self else { return }
            do {
                let chat = try await chatService.createDirectChat(participantUserId: contactUserId)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.addButton.isEnabled = true
                    self.openChatTask = nil
                    self.navigationController?.pushViewController(
                        ChatDetailViewController(chat: chat, currentUser: self.currentUser),
                        animated: true
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.addButton.isEnabled = true
                    self.openChatTask = nil
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func showSortMenu() {
        guard menuOverlay == nil else { return }

        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear

        let dismissButton = UIButton(type: .custom)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(closeSortMenu), for: .touchUpInside)

        let menu = UIView()
        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.backgroundColor = ChitChatColors.contactsCard
        menu.layer.cornerRadius = 12
        menu.layer.borderWidth = 1
        menu.layer.borderColor = ChitChatColors.contactsBorder.cgColor
        menu.clipsToBounds = true

        let ascending = makeMenuButton(title: "Sort A-Z", tag: 0)
        let descending = makeMenuButton(title: "Sort Z-A", tag: 1)
        let menuDivider = UIView()
        menuDivider.translatesAutoresizingMaskIntoConstraints = false
        menuDivider.backgroundColor = ChitChatColors.contactsMenuPressed

        view.addSubview(overlay)
        overlay.addSubview(dismissButton)
        overlay.addSubview(menu)
        menu.addSubview(ascending)
        menu.addSubview(descending)
        menu.addSubview(menuDivider)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dismissButton.topAnchor.constraint(equalTo: overlay.topAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            dismissButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),

            menu.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 54),
            menu.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menu.widthAnchor.constraint(equalToConstant: 140),
            menu.heightAnchor.constraint(equalToConstant: 73),

            ascending.topAnchor.constraint(equalTo: menu.topAnchor),
            ascending.leadingAnchor.constraint(equalTo: menu.leadingAnchor),
            ascending.trailingAnchor.constraint(equalTo: menu.trailingAnchor),
            ascending.heightAnchor.constraint(equalToConstant: 36),

            menuDivider.topAnchor.constraint(equalTo: ascending.bottomAnchor),
            menuDivider.leadingAnchor.constraint(equalTo: menu.leadingAnchor),
            menuDivider.trailingAnchor.constraint(equalTo: menu.trailingAnchor),
            menuDivider.heightAnchor.constraint(equalToConstant: 1),

            descending.topAnchor.constraint(equalTo: menuDivider.bottomAnchor),
            descending.leadingAnchor.constraint(equalTo: menu.leadingAnchor),
            descending.trailingAnchor.constraint(equalTo: menu.trailingAnchor),
            descending.bottomAnchor.constraint(equalTo: menu.bottomAnchor)
        ])

        menu.alpha = 0
        menu.transform = CGAffineTransform(translationX: 0, y: -8).scaledBy(x: 0.94, y: 0.94)
        UIView.animate(withDuration: 0.17) {
            menu.alpha = 1
            menu.transform = .identity
        }
        menuOverlay = overlay
    }

    private func makeMenuButton(title: String, tag: Int) -> UIButton {
        let button = ContactsMenuButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = tag
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.titleLabel?.font = ChitChatTypography.contactsMenu
        button.setTitleColor(ChitChatColors.textPrimary, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(sortMenuSelected(_:)), for: .touchUpInside)
        return button
    }

    private func dismissSortMenu(animated: Bool) {
        guard let overlay = menuOverlay else { return }
        menuOverlay = nil
        if animated {
            UIView.animate(withDuration: 0.12, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
            }
        } else {
            overlay.removeFromSuperview()
        }
    }

    @objc private func searchChanged() {
        applySearch()
    }

    @objc private func refreshContacts() {
        loadContacts(showLoadingState: false)
    }

    @objc private func applicationDidBecomeActive() {
        guard viewIfLoaded?.window != nil else { return }
        loadContacts(showLoadingState: false)
    }

    @objc private func addContact() {
        let controller = AddContactViewController(contactService: contactService)
        controller.onContactCreated = { [weak self] contact in
            guard let self else { return }
            contacts.append(contact)
            applySearch()
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func toggleSortMenu() {
        if menuOverlay == nil {
            showSortMenu()
        } else {
            dismissSortMenu(animated: true)
        }
    }

    @objc private func closeSortMenu() {
        dismissSortMenu(animated: true)
    }

    @objc private func sortMenuSelected(_ sender: UIButton) {
        sortDirection = sender.tag == 0 ? .ascending : .descending
        dismissSortMenu(animated: true)
        applySearch()
    }

    @objc private func syncPressed() {
        syncRow.backgroundColor = ChitChatColors.contactsPressed
    }

    @objc private func syncReleased() {
        syncRow.backgroundColor = .clear
    }

    @objc private func deviceContactsTapped() {
        switch deviceContactsService.authorizationState() {
        case .granted:
            loadContacts(showLoadingState: false)
        case .undetermined:
            presentContactsRationale()
        case .denied:
            openContactSettings()
        case .restricted:
            showAlert(message: "Contact access is restricted on this device.")
        }
    }

    private func presentContactsRationale() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "Find ChitChat contacts",
            message: "ChitChat reads contact names and phone numbers to find people already on ChitChat. Emails, photos, addresses, and notes are not uploaded.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.loadContacts(showLoadingState: false, requestDevicePermission: true)
        })
        present(alert, animated: true)
    }

    private func openContactSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            showAlert(message: "Open Settings to allow ChitChat contact access.")
            return
        }
        UIApplication.shared.open(url)
    }
}

extension ContactsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension ContactsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].contacts.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = ChitChatColors.contactsCard

        let topBorder = UIView()
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        topBorder.backgroundColor = ChitChatColors.contactsSectionBorder

        let bottomBorder = UIView()
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBorder.backgroundColor = ChitChatColors.contactsSectionBorder

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = NSAttributedString(
            string: sections[section].title,
            attributes: [
                .font: ChitChatTypography.contactsSection,
                .foregroundColor: ChitChatColors.accent,
                .kern: 0.2
            ]
        )

        header.addSubview(topBorder)
        header.addSubview(bottomBorder)
        header.addSubview(label)
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: header.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            bottomBorder.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),

            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            label.heightAnchor.constraint(equalToConstant: 16)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        ChitChatSpacing.contactsSectionHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ContactCell.reuseIdentifier,
            for: indexPath
        ) as? ContactCell else {
            return UITableViewCell()
        }
        cell.configure(contact: sections[indexPath.section].contacts[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let contact = sections[indexPath.section].contacts[indexPath.row]
        guard !animatedContactIDs.contains(contact.id) else { return }
        animatedContactIDs.insert(contact.id)

        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 6)
        UIView.animate(
            withDuration: 0.21,
            delay: min(Double(indexPath.row) * 0.018, 0.18),
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openDirectChat(for: sections[indexPath.section].contacts[indexPath.row])
    }
}
