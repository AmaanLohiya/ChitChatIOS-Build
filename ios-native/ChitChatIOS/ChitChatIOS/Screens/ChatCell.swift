import UIKit

private enum ChatsListDateFormatter {
    static func string(from rawValue: String?) -> String {
        guard let date = ChitChatDateFormatter.date(from: rawValue) else { return "" }
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

private final class DoubleCheckView: UIView {
    private let firstCheck = CAShapeLayer()
    private let secondCheck = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        [firstCheck, secondCheck].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.strokeColor = ChitChatColors.chatsReadBlue.cgColor
            $0.lineWidth = 1.7
            $0.lineCap = .round
            $0.lineJoin = .round
            layer.addSublayer($0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        firstCheck.path = checkPath(offsetX: 0).cgPath
        secondCheck.path = checkPath(offsetX: 5).cgPath
    }

    private func checkPath(offsetX: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: offsetX + 1, y: 8))
        path.addLine(to: CGPoint(x: offsetX + 4, y: 11))
        path.addLine(to: CGPoint(x: offsetX + 10, y: 3))
        return path
    }
}

private final class ChatAvatarImageView: UIView {
    private static let cache = NSCache<NSString, UIImage>()

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.chatsAvatarBackground
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

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
        layer.cornerRadius = bounds.width / 2
    }

    func configure(name: String, avatarURL: String, seed: String) {
        imageTask?.cancel()
        imageView.image = nil
        imageView.isHidden = true
        initialsLabel.text = Self.initials(from: name)

        let fallbackSeed = seed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? seed
        let resolvedURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://api.dicebear.com/7.x/identicon/png?seed=\(fallbackSeed)"
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
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return letters.isEmpty ? "C" : letters
    }
}

final class ChatCell: UITableViewCell {
    static let reuseIdentifier = "ChatCell"

    private let avatarView = ChatAvatarImageView()
    private let onlineDot = UIView()
    private let nameLabel = UILabel()
    private let pinIcon = UIImageView(image: UIImage(systemName: "pin.fill"))
    private let timeLabel = UILabel()
    private let doubleCheck = DoubleCheckView()
    private let previewLabel = UILabel()
    private let mutedIcon = UIImageView(image: UIImage(systemName: "speaker.slash.fill"))
    private let unreadBubble = UIView()
    private let unreadLabel = UILabel()
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
        backgroundColor = ChitChatColors.chatsRow
        contentView.backgroundColor = ChitChatColors.chatsRow
        selectionStyle = .none

        onlineDot.translatesAutoresizingMaskIntoConstraints = false
        onlineDot.backgroundColor = ChitChatColors.accent
        onlineDot.layer.cornerRadius = ChitChatSpacing.chatsOnlineDot / 2
        onlineDot.layer.borderWidth = 2
        onlineDot.layer.borderColor = ChitChatColors.chatsRow.cgColor

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ChitChatTypography.chatsName
        nameLabel.textColor = ChitChatColors.textPrimary
        nameLabel.numberOfLines = 1
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        pinIcon.translatesAutoresizingMaskIntoConstraints = false
        pinIcon.tintColor = ChitChatColors.textMuted
        pinIcon.contentMode = .scaleAspectFit
        pinIcon.transform = CGAffineTransform(rotationAngle: .pi / 4)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = ChitChatTypography.chatsTime
        timeLabel.textColor = ChitChatColors.textMuted
        timeLabel.textAlignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = ChitChatTypography.chatsPreview
        previewLabel.textColor = ChitChatColors.textMuted
        previewLabel.numberOfLines = 1
        previewLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        mutedIcon.translatesAutoresizingMaskIntoConstraints = false
        mutedIcon.tintColor = ChitChatColors.textMuted
        mutedIcon.contentMode = .scaleAspectFit
        mutedIcon.isHidden = true

        unreadBubble.translatesAutoresizingMaskIntoConstraints = false
        unreadBubble.backgroundColor = ChitChatColors.accent
        unreadBubble.layer.cornerRadius = ChitChatSpacing.chatsUnreadBubble / 2
        unreadBubble.isHidden = true

        unreadLabel.translatesAutoresizingMaskIntoConstraints = false
        unreadLabel.font = ChitChatTypography.chatsUnread
        unreadLabel.textColor = UIColor(hex: "#F3FFFB")
        unreadLabel.textAlignment = .center
        unreadBubble.addSubview(unreadLabel)

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.chatsDivider

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, pinIcon])
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.axis = .horizontal
        nameStack.alignment = .center
        nameStack.spacing = 6

        let trailingStack = UIStackView(arrangedSubviews: [mutedIcon, unreadBubble])
        trailingStack.translatesAutoresizingMaskIntoConstraints = false
        trailingStack.axis = .horizontal
        trailingStack.alignment = .center
        trailingStack.spacing = 8

        contentView.addSubview(avatarView)
        contentView.addSubview(onlineDot)
        contentView.addSubview(nameStack)
        contentView.addSubview(timeLabel)
        contentView.addSubview(doubleCheck)
        contentView.addSubview(previewLabel)
        contentView.addSubview(trailingStack)
        contentView.addSubview(divider)

        let pinWidth = pinIcon.widthAnchor.constraint(equalToConstant: 14)
        pinWidth.priority = .defaultHigh
        let mutedWidth = mutedIcon.widthAnchor.constraint(equalToConstant: 15)
        mutedWidth.priority = .defaultHigh
        let unreadWidth = unreadBubble.widthAnchor.constraint(
            greaterThanOrEqualToConstant: ChitChatSpacing.chatsUnreadBubble
        )
        unreadWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChitChatSpacing.chatsRowHorizontal
            ),
            avatarView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: ChitChatSpacing.chatsRowTop
            ),
            avatarView.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatsAvatar),
            avatarView.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsAvatar),

            onlineDot.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            onlineDot.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: -1),
            onlineDot.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatsOnlineDot),
            onlineDot.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsOnlineDot),

            nameStack.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: ChitChatSpacing.chatsAvatarGap
            ),
            nameStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            nameStack.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -10),

            pinWidth,
            pinIcon.heightAnchor.constraint(equalToConstant: 14),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: nameStack.centerYAnchor),

            doubleCheck.leadingAnchor.constraint(equalTo: nameStack.leadingAnchor),
            doubleCheck.topAnchor.constraint(equalTo: nameStack.bottomAnchor, constant: 10.5),
            doubleCheck.widthAnchor.constraint(equalToConstant: 17),
            doubleCheck.heightAnchor.constraint(equalToConstant: 17),

            previewLabel.leadingAnchor.constraint(equalTo: doubleCheck.trailingAnchor, constant: 4),
            previewLabel.centerYAnchor.constraint(equalTo: doubleCheck.centerYAnchor),
            previewLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingStack.leadingAnchor, constant: -10),

            trailingStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            trailingStack.centerYAnchor.constraint(equalTo: doubleCheck.centerYAnchor),
            trailingStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            mutedWidth,
            mutedIcon.heightAnchor.constraint(equalToConstant: 15),

            unreadWidth,
            unreadBubble.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatsUnreadBubble),
            unreadLabel.leadingAnchor.constraint(equalTo: unreadBubble.leadingAnchor, constant: 9),
            unreadLabel.trailingAnchor.constraint(equalTo: unreadBubble.trailingAnchor, constant: -9),
            unreadLabel.centerYAnchor.constraint(equalTo: unreadBubble.centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: nameStack.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func configure(chat: Chat, viewerUserId: String) {
        let displayName = chat.displayName(viewerUserId: viewerUserId)
        let otherUser = chat.otherParticipant(viewerUserId: viewerUserId)?.user

        avatarView.configure(
            name: displayName,
            avatarURL: chat.displayAvatarURL(viewerUserId: viewerUserId),
            seed: chat.id
        )
        nameLabel.text = displayName
        previewLabel.text = chat.lastMessagePreview.isEmpty ? "No messages yet" : chat.lastMessagePreview
        timeLabel.text = ChatsListDateFormatter.string(from: chat.lastMessageAt ?? chat.updatedAt)
        onlineDot.isHidden = !(otherUser?.isOnline ?? false)
        pinIcon.isHidden = !chat.isPinned
        mutedIcon.isHidden = !chat.isMuted

        let unreadCount = max(0, chat.unreadCount)
        unreadBubble.isHidden = unreadCount == 0
        unreadLabel.text = unreadCount > 99 ? "99+" : String(unreadCount)
        timeLabel.textColor = unreadCount > 0 ? ChitChatColors.accent : ChitChatColors.textMuted

        let unreadDescription = unreadCount > 0 ? ", \(unreadCount) unread messages" : ""
        accessibilityLabel = "\(displayName), \(previewLabel.text ?? "")\(unreadDescription)"
    }
}
