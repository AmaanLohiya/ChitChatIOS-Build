import UIKit

final class ReplicaAvatarView: UIView {
    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var task: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = ChitChatColors.accent.withAlphaComponent(0.16)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center

        addSubview(initialsLabel)
        addSubview(imageView)
        initialsLabel.pinEdges(to: self)
        imageView.pinEdges(to: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    func configure(name: String, urlString: String) {
        task?.cancel()
        imageView.image = nil
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        initialsLabel.text = initials.isEmpty ? "C" : initials

        guard let url = URL(string: urlString), !urlString.isEmpty else { return }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
        task?.resume()
    }

    deinit {
        task?.cancel()
    }
}

final class ProfileViewController: BaseViewController {
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
        let header = makeHeader()
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 14

        content.addArrangedSubview(makeHero())
        content.addArrangedSubview(makeQuickActions())
        content.addArrangedSubview(
            makeInfoCard(
                title: "BIO",
                value: user.bio.isEmpty ? "Hey there! I am using ChitChat" : user.bio,
                secondaryTitle: "PHONE",
                secondaryValue: user.phone
            )
        )
        content.addArrangedSubview(makeMediaCard())
        content.addArrangedSubview(makeProfileRowsCard())

        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(content)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let border = UIView()
        border.translatesAutoresizingMaskIntoConstraints = false
        border.backgroundColor = ChitChatColors.divider

        let back = UIButton(type: .system)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.tintColor = ChitChatColors.textPrimary
        back.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        back.layer.cornerRadius = 20
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.addTarget(self, action: #selector(closeProfile), for: .touchUpInside)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Profile"
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        header.addSubview(back)
        header.addSubview(title)
        header.addSubview(border)
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            back.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
            back.widthAnchor.constraint(equalToConstant: 40),
            back.heightAnchor.constraint(equalToConstant: 40),
            title.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            border.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return header
    }

    private func makeHero() -> UIView {
        let hero = UIView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.backgroundColor = ChitChatColors.surface
        hero.clipsToBounds = true

        let glow = UIView()
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.14)
        glow.layer.cornerRadius = 80

        let halo = UIView()
        halo.translatesAutoresizingMaskIntoConstraints = false
        halo.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        halo.layer.borderColor = ChitChatColors.accent.withAlphaComponent(0.14).cgColor
        halo.layer.borderWidth = 1
        halo.layer.cornerRadius = 66

        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: user.name, urlString: user.avatarUrl)

        let name = UILabel()
        name.translatesAutoresizingMaskIntoConstraints = false
        name.text = user.name.isEmpty ? "You" : user.name
        name.textColor = ChitChatColors.textPrimary
        name.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
        name.textAlignment = .center

        let status = UILabel()
        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = user.bio.isEmpty ? "Hey there! I am using ChitChat" : user.bio
        status.textColor = ChitChatColors.textSecondary
        status.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        status.textAlignment = .center
        status.numberOfLines = 2

        hero.addSubview(glow)
        hero.addSubview(halo)
        halo.addSubview(avatar)
        hero.addSubview(name)
        hero.addSubview(status)
        NSLayoutConstraint.activate([
            hero.heightAnchor.constraint(equalToConstant: 276),
            glow.widthAnchor.constraint(equalToConstant: 160),
            glow.heightAnchor.constraint(equalToConstant: 160),
            glow.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: -8),
            glow.topAnchor.constraint(equalTo: hero.topAnchor, constant: -28),
            halo.widthAnchor.constraint(equalToConstant: 132),
            halo.heightAnchor.constraint(equalToConstant: 132),
            halo.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            halo.topAnchor.constraint(equalTo: hero.topAnchor, constant: 26),
            avatar.centerXAnchor.constraint(equalTo: halo.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: halo.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 114),
            avatar.heightAnchor.constraint(equalToConstant: 114),
            name.topAnchor.constraint(equalTo: halo.bottomAnchor, constant: 18),
            name.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 18),
            name.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -18),
            status.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 34),
            status.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -34)
        ])
        return hero
    }

    private func makeQuickActions() -> UIView {
        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        [
            ("square.and.pencil", "Edit"),
            ("qrcode", "QR code"),
            ("square.and.arrow.up", "Share")
        ].forEach { symbol, title in
            row.addArrangedSubview(makeQuickAction(symbol: symbol, title: title))
        }
        row.heightAnchor.constraint(equalToConstant: 108).isActive = true
        return row
    }

    private func makeQuickAction(symbol: String, title: String) -> UIView {
        let card = UIView()
        card.backgroundColor = ChitChatColors.surface
        card.layer.cornerRadius = 24
        card.layer.borderColor = ChitChatColors.border.cgColor
        card.layer.borderWidth = 1

        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.16)
        iconWrap.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.textColor = ChitChatColors.textPrimary
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)

        card.addSubview(iconWrap)
        iconWrap.addSubview(icon)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconWrap.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: 44),
            iconWrap.heightAnchor.constraint(equalToConstant: 44),
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
            label.topAnchor.constraint(equalTo: iconWrap.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor)
        ])
        return card
    }

    private func makeInfoCard(
        title: String,
        value: String,
        secondaryTitle: String,
        secondaryValue: String
    ) -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel(title))
        stack.addArrangedSubview(makeValueLabel(value))
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeSectionLabel(secondaryTitle))
        let phone = makeValueLabel(secondaryValue)
        phone.textColor = ChitChatColors.accentStrong
        phone.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        stack.addArrangedSubview(phone)
        card.addSubview(stack)
        stack.pinEdges(to: card)
        return wrapped(card)
    }

    private func makeMediaCard() -> UIView {
        let card = makeCard()
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        let label = makeSectionLabel("MEDIA, LINKS, AND DOCS")
        label.translatesAutoresizingMaskIntoConstraints = false
        let count = UILabel()
        count.translatesAutoresizingMaskIntoConstraints = false
        count.text = "6  ›"
        count.textColor = ChitChatColors.accentStrong
        count.font = UIFont.systemFont(ofSize: 16, weight: .bold)

        let grid = UIStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.axis = .vertical
        grid.spacing = 2
        for _ in 0..<2 {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 2
            for index in 0..<3 {
                let tile = UIView()
                tile.backgroundColor = [
                    UIColor(hex: "#38536A"),
                    UIColor(hex: "#53644F"),
                    UIColor(hex: "#456D78")
                ][index]
                row.addArrangedSubview(tile)
            }
            grid.addArrangedSubview(row)
        }

        card.addSubview(header)
        header.addSubview(label)
        header.addSubview(count)
        card.addSubview(grid)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 50),
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            count.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            count.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            grid.topAnchor.constraint(equalTo: header.bottomAnchor),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            grid.heightAnchor.constraint(equalTo: grid.widthAnchor, multiplier: 2.0 / 3.0)
        ])
        return wrapped(card)
    }

    private func makeProfileRowsCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        [
            ("qrcode", "My QR code"),
            ("square.and.pencil", "Edit profile"),
            ("camera", "Change profile photo"),
            ("sparkles", "Share profile")
        ].enumerated().forEach { index, item in
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = ChitChatColors.divider
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(divider)
            }
            stack.addArrangedSubview(makeProfileRow(symbol: item.0, title: item.1))
        }
        card.addSubview(stack)
        stack.pinEdges(to: card)
        return wrapped(card)
    }

    private func makeProfileRow(symbol: String, title: String) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 68).isActive = true

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.textColor = ChitChatColors.textPrimary
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = ChitChatColors.textMuted

        row.addSubview(icon)
        row.addSubview(label)
        row.addSubview(chevron)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 28),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12)
        ])
        return row
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = ChitChatColors.surface
        card.layer.cornerRadius = 28
        card.layer.borderColor = ChitChatColors.border.cgColor
        card.layer.borderWidth = 1
        card.clipsToBounds = true
        return card
    }

    private func wrapped(_ card: UIView) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: wrap.topAnchor),
            card.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
        return wrap
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        return label
    }

    private func makeValueLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = ChitChatColors.textPrimary
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 0
        return label
    }

    @objc private func closeProfile() {
        navigationController?.popViewController(animated: true)
    }
}
