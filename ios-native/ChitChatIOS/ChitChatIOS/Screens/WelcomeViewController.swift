import UIKit

final class WelcomeViewController: BaseViewController {
    private let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func buildUI() {
        gradientLayer.colors = [
            ChitChatColors.welcomeGradientStart.cgColor,
            ChitChatColors.welcomeGradientMiddle.cgColor,
            ChitChatColors.welcomeGradientEnd.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let scrollContent = UIView()
        scrollContent.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center

        let logoCard = UIView()
        logoCard.translatesAutoresizingMaskIntoConstraints = false
        logoCard.backgroundColor = .white
        logoCard.layer.cornerRadius = ChitChatSpacing.welcomeLogoRadius
        ChitChatComponents.applyCardShadow(to: logoCard)

        let logo = UIImageView(image: UIImage(systemName: "message.fill"))
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.tintColor = UIColor(hex: "#59C86C")
        logo.contentMode = .scaleAspectFit
        logoCard.addSubview(logo)

        let titleLabel = UILabel()
        titleLabel.text = "Welcome to ChitChat"
        titleLabel.font = ChitChatTypography.welcomeTitle
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Private, fast messaging for people who matter."
        subtitleLabel.font = ChitChatTypography.body
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let featureStack = UIStackView()
        featureStack.axis = .vertical
        featureStack.spacing = 10
        featureStack.translatesAutoresizingMaskIntoConstraints = false
        featureStack.addArrangedSubview(
            makeFeature(icon: "lock.fill", title: "Protected account", subtitle: "Keep your conversations safer")
        )
        featureStack.addArrangedSubview(
            makeFeature(icon: "person.2.fill", title: "Connect with friends", subtitle: "Share moments that matter")
        )
        featureStack.addArrangedSubview(
            makeFeature(icon: "bolt.fill", title: "Fast and reliable", subtitle: "Messages arrive without the wait")
        )

        contentStack.addArrangedSubview(logoCard)
        contentStack.setCustomSpacing(20, after: logoCard)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(10, after: titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(22, after: subtitleLabel)
        contentStack.addArrangedSubview(featureStack)

        let bottomStack = UIStackView()
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.axis = .vertical
        bottomStack.spacing = 12
        bottomStack.alignment = .fill

        let button = WelcomeButton(title: "Get Started")
        button.addTarget(self, action: #selector(openLogin), for: .touchUpInside)

        let terms = UILabel()
        terms.text = "By continuing, you agree to our Terms & Privacy Policy"
        terms.font = ChitChatTypography.smallCaption
        terms.textColor = UIColor.white.withAlphaComponent(0.64)
        terms.textAlignment = .center
        terms.numberOfLines = 0

        bottomStack.addArrangedSubview(button)
        bottomStack.addArrangedSubview(terms)

        view.addSubview(scrollView)
        view.addSubview(bottomStack)
        scrollView.addSubview(scrollContent)
        scrollContent.addSubview(contentStack)

        let centeredContent = contentStack.centerYAnchor.constraint(equalTo: scrollContent.centerYAnchor)
        centeredContent.priority = .defaultHigh

        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -12),

            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            contentStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: scrollContent.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollContent.bottomAnchor, constant: -8),
            centeredContent,

            logoCard.widthAnchor.constraint(equalToConstant: 88),
            logoCard.heightAnchor.constraint(equalToConstant: 88),
            logo.centerXAnchor.constraint(equalTo: logoCard.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: logoCard.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 44),
            logo.heightAnchor.constraint(equalToConstant: 44),

            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 310),
            featureStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            featureStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
        ])
    }

    private func makeFeature(icon: String, title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 17
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        card.backgroundColor = UIColor.white.withAlphaComponent(0.11)

        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.layer.cornerRadius = 13
        iconWrap.backgroundColor = UIColor.white.withAlphaComponent(0.15)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconWrap.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .white

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.66)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2

        card.addSubview(iconWrap)
        card.addSubview(textStack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 64),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            iconWrap.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: 42),
            iconWrap.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            textStack.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    @objc private func openLogin() {
        navigationController?.pushViewController(LoginViewController(), animated: true)
    }
}
