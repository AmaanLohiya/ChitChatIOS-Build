import UIKit

final class ActiveSessionsViewController: BaseViewController {
    private let authService: AuthService
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let sessionsStack = UIStackView()
    private let stateLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let logoutOthersButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    private var sessions: [ActiveSession] = []
    private var pendingAction = false

    init(authService: AuthService = AuthService()) {
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
        loadSessions(showLoading: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottomClearance = (tabBarController?.tabBar.bounds.height ?? 0) + 24
        scrollView.contentInset.bottom = bottomClearance
        scrollView.scrollIndicatorInsets.bottom = bottomClearance
    }

    private func buildUI() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = ChitChatColors.textPrimary
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Active Sessions"
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

        header.addSubview(backButton)
        header.addSubview(titleLabel)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        refreshControl.tintColor = ChitChatColors.accent
        refreshControl.addTarget(self, action: #selector(refreshSessions), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 12

        sessionsStack.axis = .vertical
        sessionsStack.spacing = 12

        stateLabel.textColor = ChitChatColors.textMuted
        stateLabel.font = UIFont.systemFont(ofSize: 14)
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0
        stateLabel.isHidden = true

        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(ChitChatColors.accent, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        retryButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)

        logoutOthersButton.setTitle("Log Out All Other Devices", for: .normal)
        logoutOthersButton.setTitleColor(.white, for: .normal)
        logoutOthersButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        logoutOthersButton.backgroundColor = UIColor(hex: "#EF4444")
        logoutOthersButton.layer.cornerRadius = 20
        logoutOthersButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        logoutOthersButton.addTarget(self, action: #selector(confirmLogoutOthers), for: .touchUpInside)

        contentStack.addArrangedSubview(makeInfoCard())
        contentStack.addArrangedSubview(stateLabel)
        contentStack.addArrangedSubview(retryButton)
        contentStack.addArrangedSubview(sessionsStack)
        contentStack.addArrangedSubview(logoutOthersButton)
        updateLogoutOthersButton()

        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            backButton.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func makeInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.1)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = ChitChatColors.accent.withAlphaComponent(0.25).cgColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Review devices signed in to your account. You can revoke any session except this device."
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 0
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func loadSessions(showLoading: Bool) {
        if showLoading && sessions.isEmpty {
            stateLabel.text = "Loading active sessions..."
            stateLabel.isHidden = false
            retryButton.isHidden = true
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let loaded = try await authService.listSessions()
                sessions = loaded.sorted(by: Self.sessionOrder)
                stateLabel.isHidden = !sessions.isEmpty
                stateLabel.text = sessions.isEmpty ? "No active sessions found." : nil
                retryButton.isHidden = true
                renderSessions()
            } catch {
                stateLabel.text = error.localizedDescription
                stateLabel.isHidden = false
                retryButton.isHidden = false
            }
            refreshControl.endRefreshing()
            updateLogoutOthersButton()
        }
    }

    private func renderSessions() {
        sessionsStack.arrangedSubviews.forEach { view in
            sessionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        sessions.forEach { sessionsStack.addArrangedSubview(makeSessionCard($0)) }
    }

    private func makeSessionCard(_ session: ActiveSession) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(hex: "#102432")
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = ChitChatColors.border.cgColor

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 12
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 14, right: 16)

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.spacing = 14

        let iconWrap = UIView()
        iconWrap.backgroundColor = session.isCurrent
            ? ChitChatColors.accent.withAlphaComponent(0.12)
            : UIColor(hex: "#1A3140")
        iconWrap.layer.cornerRadius = 24
        iconWrap.widthAnchor.constraint(equalToConstant: 48).isActive = true
        iconWrap.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let icon = UIImageView(image: UIImage(systemName: session.platform == "web" ? "desktopcomputer" : "iphone"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = session.isCurrent ? ChitChatColors.accent : ChitChatColors.textMuted
        icon.contentMode = .scaleAspectFit
        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 8

        let title = UILabel()
        title.text = Self.deviceLabel(for: session)
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        title.numberOfLines = 1
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleRow.addArrangedSubview(title)

        if session.isCurrent {
            let badge = makeCurrentBadge()
            titleRow.addArrangedSubview(badge)
        }

        let platform = UILabel()
        platform.text = Self.platformDetails(for: session)
        platform.textColor = ChitChatColors.textMuted
        platform.font = UIFont.systemFont(ofSize: 14)
        platform.numberOfLines = 1
        platform.lineBreakMode = .byTruncatingTail

        let lastActive = makeMetadataLabel(Self.lastActiveLabel(session.lastActiveAt))
        let created = makeMetadataLabel(Self.createdLabel(session.createdAt))

        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(platform)
        textStack.addArrangedSubview(lastActive)
        textStack.addArrangedSubview(created)
        topRow.addArrangedSubview(iconWrap)
        topRow.addArrangedSubview(textStack)
        content.addArrangedSubview(topRow)

        if !session.isCurrent {
            let logoutButton = UIButton(type: .system)
            logoutButton.setTitle("Log out this device", for: .normal)
            logoutButton.setImage(UIImage(systemName: "rectangle.portrait.and.arrow.right"), for: .normal)
            logoutButton.tintColor = UIColor(hex: "#F87171")
            logoutButton.setTitleColor(UIColor(hex: "#F87171"), for: .normal)
            logoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            logoutButton.backgroundColor = UIColor(hex: "#F87171").withAlphaComponent(0.12)
            logoutButton.layer.cornerRadius = 14
            logoutButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
            logoutButton.addAction(UIAction { [weak self] _ in
                self?.confirmRevoke(session)
            }, for: .touchUpInside)
            content.addArrangedSubview(logoutButton)
        }

        card.addSubview(content)
        content.pinEdges(to: card)
        return card
    }

    private func makeCurrentBadge() -> UIView {
        let label = UILabel()
        label.text = "This device"
        label.textColor = ChitChatColors.accent
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.12)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
        label.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return label
    }

    private func makeMetadataLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func confirmRevoke(_ session: ActiveSession) {
        guard !pendingAction, !session.isCurrent else { return }
        let alert = UIAlertController(
            title: "Log out this device?",
            message: "That device will need to verify the phone number before signing in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
            self?.revoke(session)
        })
        present(alert, animated: true)
    }

    private func revoke(_ session: ActiveSession) {
        guard !pendingAction else { return }
        pendingAction = true
        updateLogoutOthersButton()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                pendingAction = false
                updateLogoutOthersButton()
            }
            do {
                _ = try await authService.revokeSession(sessionId: session.id)
                sessions.removeAll { $0.id == session.id }
                renderSessions()
                loadSessions(showLoading: false)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    @objc private func confirmLogoutOthers() {
        guard !pendingAction, sessions.contains(where: { !$0.isCurrent }) else { return }
        let alert = UIAlertController(
            title: "Log out all other devices?",
            message: "This device will stay signed in. Every other session will be revoked.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log out others", style: .destructive) { [weak self] _ in
            self?.logoutOtherSessions()
        })
        present(alert, animated: true)
    }

    private func logoutOtherSessions() {
        guard !pendingAction else { return }
        pendingAction = true
        updateLogoutOthersButton()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                pendingAction = false
                updateLogoutOthersButton()
            }
            do {
                _ = try await authService.logoutOtherSessions()
                sessions.removeAll { !$0.isCurrent }
                renderSessions()
                loadSessions(showLoading: false)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func updateLogoutOthersButton() {
        let enabled = !pendingAction && sessions.contains(where: { !$0.isCurrent })
        logoutOthersButton.isEnabled = enabled
        logoutOthersButton.alpha = enabled ? 1 : 0.45
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Unable to update sessions", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func refreshSessions() {
        loadSessions(showLoading: false)
    }

    @objc private func retryLoad() {
        loadSessions(showLoading: true)
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    private static func sessionOrder(_ left: ActiveSession, _ right: ActiveSession) -> Bool {
        if left.isCurrent != right.isCurrent { return left.isCurrent }
        let leftDate = parsedDate(left.lastActiveAt) ?? .distantPast
        let rightDate = parsedDate(right.lastActiveAt) ?? .distantPast
        return leftDate > rightDate
    }

    private static func deviceLabel(for session: ActiveSession) -> String {
        let name = session.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        switch session.platform {
        case "android": return "Android device"
        case "ios": return "iOS device"
        case "web": return "Web session"
        default: return "Unknown device"
        }
    }

    private static func platformDetails(for session: ActiveSession) -> String {
        let platform: String
        switch session.platform {
        case "android": platform = "Android"
        case "ios": platform = "iOS"
        case "web": platform = "Web"
        default: platform = "Unknown platform"
        }
        let version = session.appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? platform : "\(platform) · ChitChat \(version)"
    }

    private static func parsedDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func lastActiveLabel(_ value: String) -> String {
        guard let date = parsedDate(value) else { return "Last active unavailable" }
        if abs(date.timeIntervalSinceNow) < 60 { return "Active now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last active \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private static func createdLabel(_ value: String) -> String {
        guard let date = parsedDate(value) else { return "Signed-in date unavailable" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Signed in \(formatter.string(from: date))"
    }
}
