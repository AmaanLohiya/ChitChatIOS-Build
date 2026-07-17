import UIKit

final class SettingsViewController: BaseViewController {
    private var user: User
    private let scrollView = UIScrollView()
    private weak var profileAvatarView: ReplicaAvatarView?
    private weak var profileNameLabel: UILabel?
    private weak var profileBioLabel: UILabel?

    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private var runtimeVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let version, !version.isEmpty, let build, !build.isEmpty {
            return "Version \(version) (\(build))"
        }
        if let version, !version.isEmpty {
            return "Version \(version)"
        }
        if let build, !build.isEmpty {
            return "Build \(build)"
        }
        return "Version unavailable"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottomClearance = (tabBarController?.tabBar.bounds.height ?? 0) + 72
        guard scrollView.contentInset.bottom != bottomClearance else { return }
        scrollView.contentInset.bottom = bottomClearance
        scrollView.scrollIndicatorInsets.bottom = bottomClearance
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileCard()
    }

    private func buildUI() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Settings"
        title.textColor = UIColor(hex: "#E7EFF3")
        title.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        header.addSubview(title)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.contentInsetAdjustmentBehavior = .never

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 8

        let profile = makeProfileCard()
        profile.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        content.addArrangedSubview(profile)
        content.addArrangedSubview(makeSectionTitle("APPEARANCE"))
        content.addArrangedSubview(makeRowsCard([
            makeRow(symbol: "moon", title: "Dark mode", value: "Enabled"),
            makeRow(symbol: "paintpalette", title: "Chat wallpaper", value: "Default")
        ]))
        content.addArrangedSubview(makeSectionTitle("PRIVACY"))
        content.addArrangedSubview(makeToggleCard(symbol: "eye", title: "Read receipts", value: "Let others see when you've read their messages"))
        content.addArrangedSubview(makeToggleCard(symbol: "person", title: "Last seen", value: "Show when you were last online"))
        content.addArrangedSubview(makeSectionTitle("NOTIFICATIONS"))
        content.addArrangedSubview(makeSliderCard())
        content.addArrangedSubview(makeSectionTitle("ACCOUNT"))
        content.addArrangedSubview(makeRowsCard([
            makeRow(symbol: "person", title: "Account", value: "Privacy, security, change number"),
            makeRow(symbol: "lock", title: "Privacy", value: "Block contacts, disappearing messages"),
            makeRow(symbol: "shield", title: "Security", value: "Two-step verification, passcode lock")
        ]))
        content.addArrangedSubview(makeSectionTitle("APP"))
        let notificationsRow = makeRow(
            symbol: "bell",
            title: "Notifications",
            value: "Messages, status updates and previews"
        )
        notificationsRow.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(openNotificationSettings))
        )
        content.addArrangedSubview(makeRowsCard([
            notificationsRow,
            makeRow(symbol: "message", title: "Chats", value: "Theme, wallpapers, chat history"),
            makeRow(symbol: "externaldrive", title: "Storage and data", value: "367 MB used")
        ]))
        content.addArrangedSubview(makeSectionTitle("SUPPORT"))
        content.addArrangedSubview(makeRowsCard([
            makeRow(symbol: "questionmark.circle", title: "Help", value: "Help center, contact us"),
            makeRow(symbol: "info.circle", title: "About", value: runtimeVersionText)
        ]))
        let logoutCard = makeRowsCard([
            makeRow(symbol: "rectangle.portrait.and.arrow.right", title: "Log out", value: "Sign out of your account")
        ])
        logoutCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(confirmLogout)))
        content.addArrangedSubview(logoutCard)
        content.addArrangedSubview(makeFooter())

        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 10),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func makeProfileCard() -> UIControl {
        let card = UIControl()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(hex: "#102432")
        card.layer.cornerRadius = 18
        card.layer.borderColor = ChitChatColors.border.cgColor
        card.layer.borderWidth = 1
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 98).isActive = true

        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: user.name, urlString: user.avatarUrl, updatedAt: user.updatedAt)
        profileAvatarView = avatar

        let camera = UIImageView(image: UIImage(systemName: "camera"))
        camera.translatesAutoresizingMaskIntoConstraints = false
        camera.tintColor = .white
        camera.backgroundColor = ChitChatColors.accent
        camera.contentMode = .center
        camera.layer.cornerRadius = 11
        camera.clipsToBounds = true
        camera.layer.borderColor = UIColor(hex: "#102432").cgColor
        camera.layer.borderWidth = 2

        let name = UILabel()
        name.translatesAutoresizingMaskIntoConstraints = false
        name.text = user.name.isEmpty ? "You" : user.name
        name.textColor = UIColor(hex: "#E7EFF3")
        name.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        profileNameLabel = name

        let bio = UILabel()
        bio.translatesAutoresizingMaskIntoConstraints = false
        bio.text = user.bio.isEmpty ? "No status yet" : user.bio
        bio.textColor = ChitChatColors.textMuted
        bio.font = UIFont.systemFont(ofSize: 13)
        bio.numberOfLines = 1
        profileBioLabel = bio

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = ChitChatColors.textMuted.withAlphaComponent(0.4)

        card.addSubview(avatar)
        card.addSubview(camera)
        card.addSubview(name)
        card.addSubview(bio)
        card.addSubview(chevron)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 54),
            avatar.heightAnchor.constraint(equalToConstant: 54),
            camera.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 3),
            camera.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 2),
            camera.widthAnchor.constraint(equalToConstant: 22),
            camera.heightAnchor.constraint(equalToConstant: 22),
            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            name.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            name.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 7),
            bio.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            bio.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            bio.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12)
        ])
        return card
    }

    private func makeSectionTitle(_ text: String) -> UIView {
        let wrap = UIView()
        wrap.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: ChitChatColors.textMuted,
                .kern: 0.9
            ]
        )
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -2)
        ])
        return wrap
    }

    private func makeRowsCard(_ rows: [UIView]) -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        rows.enumerated().forEach { index, row in
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = ChitChatColors.border
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(divider)
            }
            stack.addArrangedSubview(row)
        }
        card.addSubview(stack)
        stack.pinEdges(to: card)
        return card
    }

    private func makeRow(symbol: String, title: String, value: String) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
        let icon = makeIconWrap(symbol)
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = UIColor(hex: "#E7EFF3")
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.text = value
        valueLabel.textColor = ChitChatColors.textMuted
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.numberOfLines = 2
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = ChitChatColors.textMuted.withAlphaComponent(0.35)
        row.addSubview(icon)
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)
        row.addSubview(chevron)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 42),
            icon.heightAnchor.constraint(equalToConstant: 42),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 18),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12)
        ])
        return row
    }

    private func makeToggleCard(symbol: String, title: String, value: String) -> UIView {
        let card = makeCard()
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 104).isActive = true
        let icon = makeIconWrap(symbol)
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = UIColor(hex: "#E7EFF3")
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.text = value
        valueLabel.textColor = ChitChatColors.textMuted
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.numberOfLines = 2
        valueLabel.lineBreakMode = .byTruncatingTail
        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 1
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = true
        toggle.onTintColor = ChitChatColors.accent
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        card.addSubview(icon)
        card.addSubview(textStack)
        card.addSubview(toggle)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 42),
            icon.heightAnchor.constraint(equalToConstant: 42),
            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            toggle.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    private func makeSliderCard() -> UIView {
        let card = makeCard()
        card.heightAnchor.constraint(equalToConstant: 104).isActive = true
        let icon = makeIconWrap("speaker.wave.2")
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Notification volume"
        title.textColor = UIColor(hex: "#E7EFF3")
        title.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let value = UILabel()
        value.translatesAutoresizingMaskIntoConstraints = false
        value.text = "75%"
        value.textColor = ChitChatColors.accent
        value.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.value = 0.75
        slider.minimumTrackTintColor = ChitChatColors.accent
        slider.maximumTrackTintColor = UIColor(hex: "#233B4C")
        slider.thumbTintColor = ChitChatColors.accent
        card.addSubview(icon)
        card.addSubview(title)
        card.addSubview(value)
        card.addSubview(slider)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            icon.widthAnchor.constraint(equalToConstant: 42),
            icon.heightAnchor.constraint(equalToConstant: 42),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            value.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 2),
            value.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            slider.heightAnchor.constraint(equalToConstant: 30)
        ])
        return card
    }

    private func makeFooter() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        let from = UILabel()
        from.text = "from"
        from.textColor = ChitChatColors.textMuted.withAlphaComponent(0.55)
        from.font = UIFont.systemFont(ofSize: 11)
        let brand = UILabel()
        brand.text = "ChitChat Inc."
        brand.textColor = ChitChatColors.accent
        brand.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        stack.addArrangedSubview(from)
        stack.addArrangedSubview(brand)
        return stack
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(hex: "#102432")
        card.layer.cornerRadius = 18
        card.layer.borderColor = ChitChatColors.border.cgColor
        card.layer.borderWidth = 1
        card.clipsToBounds = true
        return card
    }

    private func makeIconWrap(_ symbol: String) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.12)
        wrap.layer.cornerRadius = 14
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        icon.contentMode = .scaleAspectFit
        wrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])
        return wrap
    }

    @objc private func openProfile() {
        let profileUser = SessionManager.shared.authenticatedUser ?? user
        navigationController?.pushViewController(ProfileViewController(user: profileUser), animated: true)
    }

    @objc private func openNotificationSettings() {
        navigationController?.pushViewController(NotificationSettingsViewController(), animated: true)
    }

    @objc private func confirmLogout() {
        let alert = UIAlertController(
            title: "Log out?",
            message: "You will need to verify your phone number to sign in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { _ in
            Task {
                await SessionManager.shared.logout()
            }
        })
        present(alert, animated: true)
    }

    private func refreshProfileCard() {
        if let authenticatedUser = SessionManager.shared.authenticatedUser {
            user = authenticatedUser
            applyProfileCardUser()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let refreshedUser = try await SessionManager.shared.refreshCurrentUser()
                self.user = refreshedUser
                self.applyProfileCardUser()
            } catch {
                // Keep the current profile card visible during temporary network failures.
            }
        }
    }

    private func applyProfileCardUser() {
        profileAvatarView?.configure(name: user.name, urlString: user.avatarUrl, updatedAt: user.updatedAt)
        profileNameLabel?.text = user.name.isEmpty ? "You" : user.name
        profileBioLabel?.text = user.bio.isEmpty ? "No status yet" : user.bio
    }
}
