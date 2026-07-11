import PhotosUI
import UIKit

final class ReplicaAvatarView: UIView {
    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var task: URLSessionDataTask?
    private var loadIdentifier = UUID()

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
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    func configure(name: String, urlString: String, updatedAt: String? = nil) {
        task?.cancel()
        task = nil
        loadIdentifier = UUID()
        imageView.image = nil

        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        initialsLabel.text = initials.isEmpty ? "C" : initials

        guard let url = ProfileAvatarURL.resolve(urlString, updatedAt: updatedAt) else { return }

        if url.isFileURL {
            imageView.image = UIImage(contentsOfFile: url.path)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let identifier = loadIdentifier
        task = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard self?.loadIdentifier == identifier else { return }
                self?.imageView.image = image
            }
        }
        task?.resume()
    }

    deinit {
        task?.cancel()
    }
}

private enum ProfileAvatarURL {
    static func resolve(_ rawValue: String, updatedAt: String? = nil) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url: URL?
        if trimmed.hasPrefix("/") {
            url = APIClient.shared.resolvedURL(for: trimmed)
        } else {
            url = URL(string: trimmed)
        }

        guard let url else { return nil }
        guard !url.isFileURL, let updatedAt, !updatedAt.isEmpty else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "v" }
        queryItems.append(URLQueryItem(name: "v", value: updatedAt))
        components.queryItems = queryItems
        return components.url ?? url
    }
}

final class ProfileViewController: BaseViewController {
    private var user: User
    private let sessionManager = SessionManager.shared
    private weak var avatarView: ReplicaAvatarView?
    private weak var nameLabel: UILabel?
    private weak var statusLabel: UILabel?
    private weak var bioLabel: UILabel?
    private weak var phoneLabel: UILabel?

    init(user: User) {
        self.user = user
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfile()
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
        content.addArrangedSubview(makeInfoCard())
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
        avatar.configure(name: user.name, urlString: user.avatarUrl, updatedAt: user.updatedAt)
        avatarView = avatar

        let name = UILabel()
        name.translatesAutoresizingMaskIntoConstraints = false
        name.text = displayName
        name.textColor = ChitChatColors.textPrimary
        name.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
        name.textAlignment = .center
        nameLabel = name

        let status = UILabel()
        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = displayBio
        status.textColor = ChitChatColors.textSecondary
        status.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        status.textAlignment = .center
        status.numberOfLines = 2
        statusLabel = status

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
        row.addArrangedSubview(makeQuickAction(symbol: "square.and.pencil", title: "Edit", action: #selector(openEditor)))
        row.addArrangedSubview(makeQuickAction(symbol: "camera", title: "Photo", action: #selector(openEditor)))
        row.heightAnchor.constraint(equalToConstant: 108).isActive = true
        return row
    }

    private func makeQuickAction(symbol: String, title: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = ChitChatColors.surface
        card.layer.cornerRadius = 24
        card.layer.borderColor = ChitChatColors.border.cgColor
        card.layer.borderWidth = 1
        card.addTarget(self, action: action, for: .touchUpInside)

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

    private func makeInfoCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionLabel("BIO"))
        let bio = makeValueLabel(displayBio)
        bioLabel = bio
        stack.addArrangedSubview(bio)
        stack.setCustomSpacing(18, after: bio)
        stack.addArrangedSubview(makeSectionLabel("PHONE"))
        let phone = makeValueLabel(user.phone)
        phone.textColor = ChitChatColors.accentStrong
        phone.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        phoneLabel = phone
        stack.addArrangedSubview(phone)
        card.addSubview(stack)
        stack.pinEdges(to: card)
        return wrapped(card)
    }

    private func makeProfileRowsCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.addArrangedSubview(makeProfileRow(symbol: "square.and.pencil", title: "Edit profile", action: #selector(openEditor)))
        let divider = UIView()
        divider.backgroundColor = ChitChatColors.divider
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(makeProfileRow(symbol: "camera", title: "Change profile photo", action: #selector(openEditor)))
        card.addSubview(stack)
        stack.pinEdges(to: card)
        return wrapped(card)
    }

    private func makeProfileRow(symbol: String, title: String, action: Selector) -> UIControl {
        let row = UIControl()
        row.heightAnchor.constraint(equalToConstant: 68).isActive = true
        row.addTarget(self, action: action, for: .touchUpInside)

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

    private var displayName: String {
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "You" : name
    }

    private var displayBio: String {
        let bio = user.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return bio.isEmpty ? "No status yet" : bio
    }

    private func refreshProfile() {
        if let authenticatedUser = sessionManager.authenticatedUser {
            user = authenticatedUser
            applyUser()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let refreshedUser = try await self.sessionManager.refreshCurrentUser()
                self.user = refreshedUser
                self.applyUser()
            } catch {
                // Keep the last authenticated profile visible during a temporary network failure.
                self.applyUser()
            }
        }
    }

    private func applyUser() {
        avatarView?.configure(name: user.name, urlString: user.avatarUrl, updatedAt: user.updatedAt)
        nameLabel?.text = displayName
        statusLabel?.text = displayBio
        bioLabel?.text = displayBio
        phoneLabel?.text = user.phone
    }

    @objc private func openEditor() {
        navigationController?.pushViewController(
            ProfileEditorViewController(user: user, mode: .edit),
            animated: true
        )
    }

    @objc private func closeProfile() {
        navigationController?.popViewController(animated: true)
    }
}

enum ProfileEditorMode: Equatable {
    case setup
    case edit

    var title: String {
        switch self {
        case .setup:
            return "Profile setup"
        case .edit:
            return "Edit profile"
        }
    }

    var saveTitle: String {
        switch self {
        case .setup:
            return "Continue"
        case .edit:
            return "Save"
        }
    }
}

final class ProfileEditorViewController: BaseViewController, PHPickerViewControllerDelegate, UITextFieldDelegate, UITextViewDelegate {
    private var user: User
    private let mode: ProfileEditorMode
    private let sessionManager = SessionManager.shared
    private let authService = AuthService()
    private let uploadService = UploadService()
    private let nameField = RoundedTextField(placeholder: "Enter your name")
    private let bioField = UITextView()
    private let avatarView = ReplicaAvatarView()
    private let removeAvatarButton = UIButton(type: .system)
    private let saveButton: PrimaryButton
    private let errorLabel = UILabel()
    private var selectedAvatarFileURL: URL?
    private var shouldRemoveAvatar = false
    private var isSaving = false

    init(user: User, mode: ProfileEditorMode) {
        self.user = user
        self.mode = mode
        self.saveButton = PrimaryButton(title: mode.saveTitle)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.authBackground
        buildUI()
        configureInitialValues()
    }

    private func buildUI() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let backAction: Selector = mode == .setup ? #selector(cancelSetup) : #selector(closeEditor)
        let header = ChitChatComponents.makeHeader(title: mode.title, target: self, backAction: backAction)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 16

        let copy = UILabel()
        copy.text = mode == .setup ? "Add a photo and tell us your name" : "Update the details your contacts see"
        copy.textColor = ChitChatColors.textMuted
        copy.font = ChitChatTypography.body
        copy.numberOfLines = 0
        copy.textAlignment = .center

        content.addArrangedSubview(copy)
        content.setCustomSpacing(10, after: copy)
        content.addArrangedSubview(makeAvatarSection())
        content.addArrangedSubview(makeInputCard(title: "NAME", field: nameField))
        content.addArrangedSubview(makeBioCard())
        content.addArrangedSubview(makePhoneCard())

        errorLabel.textColor = ChitChatColors.danger
        errorLabel.font = ChitChatTypography.caption
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        content.addArrangedSubview(errorLabel)

        nameField.autocapitalizationType = .words
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.inputAccessoryView = ChitChatComponents.makeKeyboardDoneToolbar(
            target: self,
            action: #selector(dismissKeyboard)
        )

        saveButton.addTarget(self, action: #selector(saveProfile), for: .touchUpInside)

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(saveButton)
        scrollView.addSubview(content)

        let keyboardBottom = saveButton.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -16
        )
        keyboardBottom.priority = .defaultHigh

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 22),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            saveButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            keyboardBottom
        ])
    }

    private func configureInitialValues() {
        nameField.text = user.name
        bioField.text = user.bio
        avatarView.configure(name: user.name, urlString: user.avatarUrl, updatedAt: user.updatedAt)
        updateRemoveAvatarVisibility()
    }

    private func makeAvatarSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        let button = UIControl()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showAvatarActions), for: .touchUpInside)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        let cameraBadge = UIView()
        cameraBadge.translatesAutoresizingMaskIntoConstraints = false
        cameraBadge.backgroundColor = ChitChatColors.accent
        cameraBadge.layer.cornerRadius = 21
        let camera = UIImageView(image: UIImage(systemName: "camera.fill"))
        camera.translatesAutoresizingMaskIntoConstraints = false
        camera.tintColor = .white
        camera.contentMode = .scaleAspectFit

        button.addSubview(avatarView)
        button.addSubview(cameraBadge)
        cameraBadge.addSubview(camera)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 136),
            button.heightAnchor.constraint(equalToConstant: 136),
            avatarView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 132),
            avatarView.heightAnchor.constraint(equalToConstant: 132),
            cameraBadge.widthAnchor.constraint(equalToConstant: 42),
            cameraBadge.heightAnchor.constraint(equalToConstant: 42),
            cameraBadge.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            cameraBadge.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            camera.centerXAnchor.constraint(equalTo: cameraBadge.centerXAnchor),
            camera.centerYAnchor.constraint(equalTo: cameraBadge.centerYAnchor),
            camera.widthAnchor.constraint(equalToConstant: 20),
            camera.heightAnchor.constraint(equalToConstant: 20)
        ])

        let hint = UILabel()
        hint.text = "Tap to change photo"
        hint.textColor = ChitChatColors.textMuted
        hint.font = ChitChatTypography.caption

        removeAvatarButton.setTitle("Remove photo", for: .normal)
        removeAvatarButton.setTitleColor(ChitChatColors.danger, for: .normal)
        removeAvatarButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        removeAvatarButton.addTarget(self, action: #selector(removeAvatar), for: .touchUpInside)

        stack.addArrangedSubview(button)
        stack.addArrangedSubview(hint)
        stack.addArrangedSubview(removeAvatarButton)
        return stack
    }

    private func makeInputCard(title: String, field: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = ChitChatColors.surface
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = ChitChatColors.border.cgColor

        let label = makeFieldLabel(title)
        card.addSubview(label)
        card.addSubview(field)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 9),
            field.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            field.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            field.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        return card
    }

    private func makeBioCard() -> UIView {
        bioField.translatesAutoresizingMaskIntoConstraints = false
        bioField.backgroundColor = ChitChatColors.inputBackground
        bioField.textColor = ChitChatColors.textPrimary
        bioField.font = ChitChatTypography.bodyMedium
        bioField.tintColor = ChitChatColors.accent
        bioField.layer.cornerRadius = ChitChatSpacing.inputRadius
        bioField.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        bioField.delegate = self
        bioField.inputAccessoryView = ChitChatComponents.makeKeyboardDoneToolbar(
            target: self,
            action: #selector(dismissKeyboard)
        )
        bioField.heightAnchor.constraint(equalToConstant: 112).isActive = true
        return makeInputCard(title: "ABOUT", field: bioField)
    }

    private func makePhoneCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ChitChatColors.surface
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = ChitChatColors.border.cgColor

        let label = makeFieldLabel("PHONE NUMBER")
        let value = UILabel()
        value.translatesAutoresizingMaskIntoConstraints = false
        value.text = user.phone
        value.textColor = ChitChatColors.textSecondary
        value.font = ChitChatTypography.bodySemibold

        card.addSubview(label)
        card.addSubview(value)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            value.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            value.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            value.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            value.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        return label
    }

    private func updateRemoveAvatarVisibility() {
        let hasAvatar = selectedAvatarFileURL != nil || (!shouldRemoveAvatar && !user.avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        removeAvatarButton.isHidden = !hasAvatar
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message?.isEmpty ?? true
    }

    private func setSaving(_ saving: Bool) {
        isSaving = saving
        saveButton.isEnabled = !saving
        saveButton.setTitle(saving ? "Saving..." : mode.saveTitle, for: .normal)
    }

    @objc private func showAvatarActions() {
        guard !isSaving else { return }

        let alert = UIAlertController(title: "Profile photo", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Choose photo", style: .default) { [weak self] _ in
            self?.openPhotoPicker()
        })
        if !removeAvatarButton.isHidden {
            alert.addAction(UIAlertAction(title: "Remove photo", style: .destructive) { [weak self] _ in
                self?.removeAvatar()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarView
            popover.sourceRect = avatarView.bounds
        }
        present(alert, animated: true)
    }

    private func openPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            showAlert(message: "The selected photo could not be read.")
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard error == nil, let image = object as? UIImage else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "The selected photo could not be read.")
                }
                return
            }
            guard let data = image.jpegData(compressionQuality: 0.84) else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "The selected photo could not be prepared.")
                }
                return
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("profile-\(UUID().uuidString).jpg")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(message: "The selected photo could not be prepared.")
                }
                return
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.selectedAvatarFileURL = fileURL
                self.shouldRemoveAvatar = false
                self.avatarView.configure(name: self.nameField.text ?? self.user.name, urlString: fileURL.absoluteString)
                self.updateRemoveAvatarVisibility()
            }
        }
    }

    @objc private func removeAvatar() {
        guard !isSaving else { return }
        selectedAvatarFileURL = nil
        shouldRemoveAvatar = true
        avatarView.configure(name: nameField.text ?? user.name, urlString: "")
        updateRemoveAvatarVisibility()
    }

    @objc private func saveProfile() {
        dismissKeyboard()
        guard !isSaving else { return }

        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bio = bioField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else {
            setError("Enter at least 2 characters for your name.")
            return
        }
        guard name.count <= 60 else {
            setError("Name cannot exceed 60 characters.")
            return
        }
        guard bio.count <= 180 else {
            setError("About cannot exceed 180 characters.")
            return
        }

        setError(nil)
        setSaving(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let avatarURL = try await self.updatedAvatarURL()
                let updatedUser = try await self.authService.updateProfile(
                    name: name,
                    bio: bio,
                    avatarUrl: avatarURL
                )
                if self.mode == .setup, !updatedUser.isProfileComplete {
                    throw APIClientError.server(
                        code: "PROFILE_INCOMPLETE",
                        message: "Profile setup could not be completed. Please try again."
                    )
                }

                try self.sessionManager.updateAuthenticatedUser(
                    updatedUser,
                    transitionToMainApp: self.mode == .setup
                )
                self.user = updatedUser
                self.setSaving(false)

                if self.mode == .edit {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                self.setSaving(false)
                self.setError(error.localizedDescription)
                if self.isSessionError(error) {
                    self.sessionManager.signOut()
                }
            }
        }
    }

    private func updatedAvatarURL() async throws -> String? {
        if shouldRemoveAvatar {
            return ""
        }
        guard let selectedAvatarFileURL else { return nil }

        let upload = try await uploadService.uploadLocalFile(
            fileURL: selectedAvatarFileURL,
            fileName: "profile-photo.jpg",
            mimeType: "image/jpeg",
            usage: .avatar,
            resourceType: .image
        )
        let url = upload.secureUrl.isEmpty ? upload.url : upload.secureUrl
        guard !url.isEmpty else {
            throw UploadServiceError.invalidResponse
        }
        return url
    }

    private func isSessionError(_ error: Error) -> Bool {
        guard let apiError = error as? APIClientError else { return false }
        switch apiError {
        case .unauthorized:
            return true
        case .server(let code, _):
            return code == "UNAUTHORIZED" || code == "INVALID_ACCESS_TOKEN" || code == "SESSION_INVALID"
        default:
            return false
        }
    }

    @objc private func closeEditor() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func cancelSetup() {
        Task {
            await sessionManager.logout()
        }
    }
}
