import UIKit

private final class ContactAvatarImageView: UIView {
    private static let cache = NSCache<NSString, UIImage>()

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.contactsCard
        clipsToBounds = true

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

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
        layer.cornerRadius = bounds.width / 2
    }

    func configure(name: String, avatarURL: String) {
        imageTask?.cancel()
        imageView.image = nil
        imageView.isHidden = true
        initialsLabel.text = Self.initials(from: name)

        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        let resolvedURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://api.dicebear.com/7.x/avataaars/png?seed=\(encodedName)"
            : avatarURL
        representedURL = resolvedURL

        if let cached = Self.cache.object(forKey: resolvedURL as NSString) {
            imageView.image = cached
            imageView.isHidden = false
            return
        }

        guard let url = URL(string: resolvedURL) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: resolvedURL as NSString)
            DispatchQueue.main.async {
                guard self?.representedURL == resolvedURL else { return }
                self?.imageView.image = image
                self?.imageView.isHidden = false
            }
        }
        imageTask?.resume()
    }

    func cancelImageLoad() {
        imageTask?.cancel()
        imageTask = nil
        representedURL = nil
    }

    private static func initials(from name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        return letters.isEmpty ? "C" : letters
    }
}

final class ContactCell: UITableViewCell {
    static let reuseIdentifier = "ContactCell"

    private let avatarView = ContactAvatarImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let divider = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelImageLoad()
    }

    private func buildUI() {
        backgroundColor = ChitChatColors.contactsScreen
        contentView.backgroundColor = ChitChatColors.contactsScreen
        selectionStyle = .default

        let pressedView = UIView()
        pressedView.backgroundColor = ChitChatColors.contactsPressed
        selectedBackgroundView = pressedView

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ChitChatTypography.contactsName
        nameLabel.textColor = ChitChatColors.textPrimary
        nameLabel.numberOfLines = 1

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = ChitChatTypography.contactsStatus
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.numberOfLines = 1

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.contactsRowBorder

        let metaStack = UIStackView(arrangedSubviews: [nameLabel, statusLabel])
        metaStack.translatesAutoresizingMaskIntoConstraints = false
        metaStack.axis = .vertical
        metaStack.alignment = .fill
        metaStack.spacing = 2

        contentView.addSubview(avatarView)
        contentView.addSubview(metaStack)
        contentView.addSubview(divider)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChitChatSpacing.contactsRowHorizontal
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: ChitChatSpacing.contactsAvatar),
            avatarView.heightAnchor.constraint(equalToConstant: ChitChatSpacing.contactsAvatar),

            metaStack.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: ChitChatSpacing.contactsAvatarGap
            ),
            metaStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChitChatSpacing.contactsRowHorizontal
            ),
            metaStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            nameLabel.heightAnchor.constraint(equalToConstant: 19),
            statusLabel.heightAnchor.constraint(equalToConstant: 16),

            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func configure(contact: Contact) {
        avatarView.configure(name: contact.name, avatarURL: contact.avatarUrl)
        nameLabel.attributedText = NSAttributedString(
            string: contact.name,
            attributes: [
                .font: ChitChatTypography.contactsName,
                .foregroundColor: ChitChatColors.textPrimary,
                .kern: -0.2
            ]
        )
        statusLabel.text = contact.label.isEmpty ? contact.phoneNumber : contact.label
        accessibilityLabel = "\(contact.name), \(statusLabel.text ?? "")"
    }
}
