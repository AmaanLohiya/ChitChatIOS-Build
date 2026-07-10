import UIKit

final class MainPlaceholderViewController: BaseViewController {
    private let user: User

    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
    }

    private func buildUI() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Profile"
        title.font = ChitChatTypography.largeTitle
        title.textColor = ChitChatColors.textPrimary
        header.addSubview(title)

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 0

        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.16)
        iconWrap.layer.cornerRadius = 30

        let icon = UIImageView(image: UIImage(systemName: "checkmark.message.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        icon.contentMode = .scaleAspectFit
        iconWrap.addSubview(icon)

        let successTitle = UILabel()
        successTitle.text = "You're signed in"
        successTitle.font = ChitChatTypography.title
        successTitle.textColor = ChitChatColors.textPrimary
        successTitle.textAlignment = .center

        let displayName = user.name.isEmpty ? "Your ChitChat account" : user.name
        let accountLabel = UILabel()
        accountLabel.text = "\(displayName)\n\(user.phone)"
        accountLabel.font = ChitChatTypography.body
        accountLabel.textColor = ChitChatColors.textMuted
        accountLabel.textAlignment = .center
        accountLabel.numberOfLines = 0

        let phaseCard = UIView()
        phaseCard.translatesAutoresizingMaskIntoConstraints = false
        phaseCard.backgroundColor = ChitChatColors.surface
        phaseCard.layer.cornerRadius = ChitChatSpacing.cardRadius
        phaseCard.layer.borderWidth = 1
        phaseCard.layer.borderColor = ChitChatColors.border.cgColor

        let phaseIcon = UIImageView(image: UIImage(systemName: "shield.checkered"))
        phaseIcon.translatesAutoresizingMaskIntoConstraints = false
        phaseIcon.tintColor = ChitChatColors.accent

        let phaseTitle = UILabel()
        phaseTitle.translatesAutoresizingMaskIntoConstraints = false
        phaseTitle.text = "Account protected"
        phaseTitle.font = ChitChatTypography.bodySemibold
        phaseTitle.textColor = ChitChatColors.textPrimary

        let phaseBody = UILabel()
        phaseBody.translatesAutoresizingMaskIntoConstraints = false
        phaseBody.text = "Your ChitChat profile and saved session are active on this device."
        phaseBody.font = ChitChatTypography.caption
        phaseBody.textColor = ChitChatColors.textMuted
        phaseBody.numberOfLines = 0

        phaseCard.addSubview(phaseIcon)
        phaseCard.addSubview(phaseTitle)
        phaseCard.addSubview(phaseBody)

        let logout = UIButton(type: .system)
        logout.translatesAutoresizingMaskIntoConstraints = false
        logout.setTitle("Log out", for: .normal)
        logout.setTitleColor(ChitChatColors.danger, for: .normal)
        logout.titleLabel?.font = ChitChatTypography.button
        logout.backgroundColor = ChitChatColors.surface
        logout.layer.cornerRadius = ChitChatSpacing.buttonRadius
        logout.layer.borderWidth = 1
        logout.layer.borderColor = ChitChatColors.border.cgColor
        logout.addTarget(self, action: #selector(logOut), for: .touchUpInside)

        contentStack.addArrangedSubview(iconWrap)
        contentStack.setCustomSpacing(20, after: iconWrap)
        contentStack.addArrangedSubview(successTitle)
        contentStack.setCustomSpacing(8, after: successTitle)
        contentStack.addArrangedSubview(accountLabel)
        contentStack.setCustomSpacing(28, after: accountLabel)
        contentStack.addArrangedSubview(phaseCard)

        view.addSubview(header)
        view.addSubview(contentStack)
        view.addSubview(logout)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 62),

            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -14),

            contentStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),

            iconWrap.widthAnchor.constraint(equalToConstant: 78),
            iconWrap.heightAnchor.constraint(equalToConstant: 78),
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),

            phaseCard.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            phaseCard.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            phaseIcon.leadingAnchor.constraint(equalTo: phaseCard.leadingAnchor, constant: 18),
            phaseIcon.topAnchor.constraint(equalTo: phaseCard.topAnchor, constant: 20),
            phaseIcon.widthAnchor.constraint(equalToConstant: 22),
            phaseIcon.heightAnchor.constraint(equalToConstant: 22),
            phaseTitle.leadingAnchor.constraint(equalTo: phaseIcon.trailingAnchor, constant: 12),
            phaseTitle.trailingAnchor.constraint(equalTo: phaseCard.trailingAnchor, constant: -18),
            phaseTitle.centerYAnchor.constraint(equalTo: phaseIcon.centerYAnchor),
            phaseBody.topAnchor.constraint(equalTo: phaseTitle.bottomAnchor, constant: 6),
            phaseBody.leadingAnchor.constraint(equalTo: phaseTitle.leadingAnchor),
            phaseBody.trailingAnchor.constraint(equalTo: phaseCard.trailingAnchor, constant: -18),
            phaseBody.bottomAnchor.constraint(equalTo: phaseCard.bottomAnchor, constant: -20),

            logout.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            logout.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            logout.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            logout.heightAnchor.constraint(equalToConstant: ChitChatSpacing.primaryButtonHeight)
        ])
    }

    @objc private func logOut() {
        SessionManager.shared.signOut()
    }
}
