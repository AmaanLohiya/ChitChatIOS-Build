import UIKit

private enum ChatDetailTimeFormatter {
    static func string(from rawValue: String?) -> String {
        guard let date = ChitChatDateFormatter.date(from: rawValue) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct MessageReplyPreview {
    let senderName: String
    let summary: String
}

private enum ChatDetailFileFormatter {
    static func string(from value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(value)
        var unitIndex = 0
        while size >= 1024, unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(value) \(units[unitIndex])"
        }
        if size < 10 {
            return String(format: "%.1f %@", size, units[unitIndex])
        }
        return String(format: "%.0f %@", size, units[unitIndex])
    }

    static func displayName(from value: String?, mimeType: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "Document" }

        var resolved = removingChitChatPrefix(from: trimmed)
        if URL(fileURLWithPath: resolved).pathExtension.isEmpty,
           let fileExtension = preferredExtension(forMimeType: mimeType) {
            resolved += ".\(fileExtension)"
        }
        return resolved.isEmpty ? "Document" : resolved
    }

    private static func removingChitChatPrefix(from value: String) -> String {
        for prefix in ["chitchat-preview-", "chitchat-upload-", "chitchat-"] {
            guard value.hasPrefix(prefix) else { continue }
            let remainder = String(value.dropFirst(prefix.count))
            guard remainder.count > 37 else { return remainder }
            let uuidCandidate = String(remainder.prefix(36))
            let separatorIndex = remainder.index(remainder.startIndex, offsetBy: 36)
            if UUID(uuidString: uuidCandidate) != nil, remainder[separatorIndex] == "-" {
                return String(remainder.dropFirst(37))
            }
            return remainder
        }
        return value
    }

    static func preferredExtension(forMimeType mimeType: String?) -> String? {
        switch mimeType?.lowercased() {
        case "application/pdf":
            return "pdf"
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            return "xlsx"
        case "application/vnd.ms-excel":
            return "xls"
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "docx"
        case "application/msword":
            return "doc"
        case "text/csv", "application/csv":
            return "csv"
        case "text/plain":
            return "txt"
        case "application/zip", "application/x-zip-compressed":
            return "zip"
        default:
            return nil
        }
    }
}

private final class MessageReadView: UIView {
    private let firstCheck = CAShapeLayer()
    private let secondCheck = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        [firstCheck, secondCheck].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.strokeColor = ChitChatColors.chatDetailReadBlue.cgColor
            $0.lineWidth = 2.3
            $0.lineCap = .round
            $0.lineJoin = .round
            layer.addSublayer($0)
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        firstCheck.path = checkPath(offsetX: 0).cgPath
        secondCheck.path = checkPath(offsetX: 6).cgPath
    }

    private func checkPath(offsetX: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: offsetX + 1, y: 9))
        path.addLine(to: CGPoint(x: offsetX + 5, y: 13))
        path.addLine(to: CGPoint(x: offsetX + 13, y: 4))
        return path
    }
}

private final class MessageBubbleBackgroundView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var isOutgoing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(isOutgoing: Bool, radius: CGFloat = ChitChatSpacing.chatDetailBubbleRadius) {
        self.isOutgoing = isOutgoing
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        shapeLayer.fillColor = (
            isOutgoing ? ChitChatColors.chatDetailSent : ChitChatColors.chatDetailReceived
        ).cgColor
        shapeLayer.strokeColor = isOutgoing
            ? UIColor.clear.cgColor
            : UIColor.white.withAlphaComponent(0.04).cgColor
        shapeLayer.lineWidth = isOutgoing ? 0 : 1
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = bubblePath(in: bounds).cgPath
    }

    private func bubblePath(in rect: CGRect) -> UIBezierPath {
        let width = rect.width
        let height = rect.height
        let radius = min(
            layer.cornerRadius,
            min(width / 2, height / 2)
        )
        let tailRadius = min(ChitChatSpacing.chatDetailBubbleTailRadius, radius)
        let lowerLeftRadius = isOutgoing ? radius : tailRadius
        let lowerRightRadius = isOutgoing ? tailRadius : radius

        let path = UIBezierPath()
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: width - radius, y: 0))
        path.addArc(
            withCenter: CGPoint(x: width - radius, y: radius),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: width, y: height - lowerRightRadius))
        path.addArc(
            withCenter: CGPoint(x: width - lowerRightRadius, y: height - lowerRightRadius),
            radius: lowerRightRadius,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: lowerLeftRadius, y: height))
        path.addArc(
            withCenter: CGPoint(x: lowerLeftRadius, y: height - lowerLeftRadius),
            radius: lowerLeftRadius,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(
            withCenter: CGPoint(x: radius, y: radius),
            radius: radius,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        path.close()
        return path
    }
}

final class MessageBubbleCell: UITableViewCell {
    static let reuseIdentifier = "MessageBubbleCell"

    private static let imageCache = NSCache<NSString, UIImage>()
    private static let reactionOrder = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    private let bubbleView = MessageBubbleBackgroundView()
    private let replyPreviewView = UIView()
    private let replyAccentView = UIView()
    private let replySenderLabel = UILabel()
    private let replySummaryLabel = UILabel()
    private let messageLabel = UILabel()
    private let mediaImageView = UIImageView()
    private let captionLabel = UILabel()
    private let documentIconWrap = UIView()
    private let documentIcon = UIImageView()
    private let documentNameLabel = UILabel()
    private let documentSizeLabel = UILabel()
    private let documentDivider = UIView()
    private let documentHintLabel = UILabel()
    private let timeLabel = UILabel()
    private let readView = MessageReadView()
    private let reactionPill = UIView()
    private let reactionLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var bubbleBottomConstraint: NSLayoutConstraint?
    private var incomingTimeTrailing: NSLayoutConstraint?
    private var outgoingTimeTrailing: NSLayoutConstraint?
    private var activeLayoutConstraints: [NSLayoutConstraint] = []
    private var reactionLayoutConstraints: [NSLayoutConstraint] = []
    private var imageTask: URLSessionDataTask?
    private var representedImageURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func buildUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        replyPreviewView.translatesAutoresizingMaskIntoConstraints = false
        replyPreviewView.backgroundColor = ChitChatColors.chatDetailInput.withAlphaComponent(0.72)
        replyPreviewView.layer.cornerRadius = 9
        replyPreviewView.layer.cornerCurve = .continuous
        replyPreviewView.clipsToBounds = true
        replyPreviewView.isHidden = true

        replyAccentView.translatesAutoresizingMaskIntoConstraints = false
        replyAccentView.backgroundColor = ChitChatColors.accent

        replySenderLabel.translatesAutoresizingMaskIntoConstraints = false
        replySenderLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        replySenderLabel.textColor = ChitChatColors.accent
        replySenderLabel.numberOfLines = 1

        replySummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        replySummaryLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        replySummaryLabel.textColor = ChitChatColors.textMuted
        replySummaryLabel.numberOfLines = 1

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textColor = ChitChatColors.textPrimary
        messageLabel.numberOfLines = 0

        mediaImageView.translatesAutoresizingMaskIntoConstraints = false
        mediaImageView.contentMode = .scaleAspectFill
        mediaImageView.clipsToBounds = true
        mediaImageView.backgroundColor = ChitChatColors.chatDetailInput
        mediaImageView.isHidden = true

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.textColor = ChitChatColors.textPrimary
        captionLabel.font = ChitChatTypography.chatDetailMessage
        captionLabel.numberOfLines = 0
        captionLabel.isHidden = true

        documentIconWrap.translatesAutoresizingMaskIntoConstraints = false
        documentIconWrap.backgroundColor = UIColor(hex: "#122C3A").withAlphaComponent(0.45)
        documentIconWrap.layer.cornerRadius = 12
        documentIconWrap.layer.cornerCurve = .continuous
        documentIconWrap.isHidden = true

        documentIcon.translatesAutoresizingMaskIntoConstraints = false
        documentIcon.image = UIImage(
            systemName: "doc.text",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        )
        documentIcon.tintColor = ChitChatColors.accent
        documentIcon.contentMode = .scaleAspectFit

        documentNameLabel.translatesAutoresizingMaskIntoConstraints = false
        documentNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        documentNameLabel.textColor = ChitChatColors.textPrimary
        documentNameLabel.numberOfLines = 1
        documentNameLabel.isHidden = true

        documentSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        documentSizeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        documentSizeLabel.textColor = UIColor(
            red: 214 / 255,
            green: 227 / 255,
            blue: 237 / 255,
            alpha: 0.72
        )
        documentSizeLabel.numberOfLines = 1
        documentSizeLabel.isHidden = true

        documentDivider.translatesAutoresizingMaskIntoConstraints = false
        documentDivider.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        documentDivider.isHidden = true

        documentHintLabel.translatesAutoresizingMaskIntoConstraints = false
        documentHintLabel.text = "Tap to open"
        documentHintLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        documentHintLabel.textColor = UIColor(
            red: 214 / 255,
            green: 227 / 255,
            blue: 237 / 255,
            alpha: 0.7
        )
        documentHintLabel.isHidden = true

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = ChitChatTypography.chatDetailTime
        timeLabel.textAlignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        readView.isHidden = true

        reactionPill.translatesAutoresizingMaskIntoConstraints = false
        reactionPill.backgroundColor = ChitChatColors.chatDetailInput
        reactionPill.layer.cornerRadius = 11
        reactionPill.layer.cornerCurve = .continuous
        reactionPill.layer.borderWidth = 1
        reactionPill.isHidden = true

        reactionLabel.translatesAutoresizingMaskIntoConstraints = false
        reactionLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        reactionLabel.textColor = ChitChatColors.textPrimary
        reactionLabel.numberOfLines = 1
        reactionLabel.lineBreakMode = .byTruncatingTail

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(replyPreviewView)
        replyPreviewView.addSubview(replyAccentView)
        replyPreviewView.addSubview(replySenderLabel)
        replyPreviewView.addSubview(replySummaryLabel)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(mediaImageView)
        bubbleView.addSubview(captionLabel)
        bubbleView.addSubview(documentIconWrap)
        documentIconWrap.addSubview(documentIcon)
        bubbleView.addSubview(documentNameLabel)
        bubbleView.addSubview(documentSizeLabel)
        bubbleView.addSubview(documentDivider)
        bubbleView.addSubview(documentHintLabel)
        bubbleView.addSubview(timeLabel)
        bubbleView.addSubview(readView)
        contentView.addSubview(reactionPill)
        reactionPill.addSubview(reactionLabel)

        incomingTimeTrailing = timeLabel.trailingAnchor.constraint(
            equalTo: bubbleView.trailingAnchor,
            constant: -ChitChatSpacing.chatDetailBubbleHorizontal
        )
        outgoingTimeTrailing = timeLabel.trailingAnchor.constraint(
            equalTo: readView.leadingAnchor,
            constant: -3
        )

        let bubbleBottomConstraint = bubbleView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -ChitChatSpacing.chatDetailRowBottom
        )
        self.bubbleBottomConstraint = bubbleBottomConstraint

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubbleBottomConstraint,
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.77),

            replyPreviewView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            replyPreviewView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            replyPreviewView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            replyPreviewView.heightAnchor.constraint(equalToConstant: 42),

            replyAccentView.topAnchor.constraint(equalTo: replyPreviewView.topAnchor),
            replyAccentView.leadingAnchor.constraint(equalTo: replyPreviewView.leadingAnchor),
            replyAccentView.bottomAnchor.constraint(equalTo: replyPreviewView.bottomAnchor),
            replyAccentView.widthAnchor.constraint(equalToConstant: 3),

            replySenderLabel.topAnchor.constraint(equalTo: replyPreviewView.topAnchor, constant: 5),
            replySenderLabel.leadingAnchor.constraint(equalTo: replyAccentView.trailingAnchor, constant: 8),
            replySenderLabel.trailingAnchor.constraint(equalTo: replyPreviewView.trailingAnchor, constant: -8),
            replySenderLabel.heightAnchor.constraint(equalToConstant: 14),

            replySummaryLabel.topAnchor.constraint(equalTo: replySenderLabel.bottomAnchor, constant: 1),
            replySummaryLabel.leadingAnchor.constraint(equalTo: replySenderLabel.leadingAnchor),
            replySummaryLabel.trailingAnchor.constraint(equalTo: replySenderLabel.trailingAnchor),
            replySummaryLabel.heightAnchor.constraint(equalToConstant: 14),

            readView.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -ChitChatSpacing.chatDetailBubbleHorizontal
            ),
            readView.widthAnchor.constraint(equalToConstant: 20),
            readView.heightAnchor.constraint(equalToConstant: 20),

            documentIcon.centerXAnchor.constraint(equalTo: documentIconWrap.centerXAnchor),
            documentIcon.centerYAnchor.constraint(equalTo: documentIconWrap.centerYAnchor),
            documentIcon.widthAnchor.constraint(equalToConstant: 22),
            documentIcon.heightAnchor.constraint(equalToConstant: 22),

            reactionLabel.topAnchor.constraint(equalTo: reactionPill.topAnchor, constant: 3),
            reactionLabel.leadingAnchor.constraint(equalTo: reactionPill.leadingAnchor, constant: 8),
            reactionLabel.trailingAnchor.constraint(equalTo: reactionPill.trailingAnchor, constant: -8),
            reactionLabel.bottomAnchor.constraint(equalTo: reactionPill.bottomAnchor, constant: -3),
            reactionPill.widthAnchor.constraint(lessThanOrEqualTo: bubbleView.widthAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetForConfiguration()
    }

    private func resetForConfiguration() {
        imageTask?.cancel()
        imageTask = nil
        representedImageURL = nil
        mediaImageView.image = nil
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        incomingTimeTrailing?.isActive = false
        outgoingTimeTrailing?.isActive = false
        NSLayoutConstraint.deactivate(activeLayoutConstraints)
        activeLayoutConstraints.removeAll()
        NSLayoutConstraint.deactivate(reactionLayoutConstraints)
        reactionLayoutConstraints.removeAll()
        bubbleBottomConstraint?.isActive = true
        leadingConstraint = nil
        trailingConstraint = nil
        replySenderLabel.text = nil
        replySummaryLabel.text = nil
        reactionLabel.text = nil
        resetContentVisibility()
    }

    func configure(
        message: Message,
        isOutgoing: Bool,
        replyPreview: MessageReplyPreview?,
        currentUserId: String
    ) {
        resetForConfiguration()
        configureReplyPreview(replyPreview)

        if isOutgoing {
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChitChatSpacing.chatDetailMessageHorizontal
            )
            trailingConstraint?.isActive = true
            outgoingTimeTrailing?.isActive = true
            readView.isHidden = false
            timeLabel.textColor = ChitChatColors.chatDetailSentTime
        } else {
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChitChatSpacing.chatDetailMessageHorizontal
            )
            leadingConstraint?.isActive = true
            incomingTimeTrailing?.isActive = true
            readView.isHidden = true
            timeLabel.textColor = ChitChatColors.chatDetailReceivedTime
        }

        let timestamp = ChatDetailTimeFormatter.string(from: message.createdAt)
        if message.editedAt != nil, !message.isDeletedForEveryone {
            timeLabel.text = timestamp.isEmpty ? "edited" : "\(timestamp) · edited"
        } else {
            timeLabel.text = timestamp
        }

        if message.isDeletedForEveryone || message.type == .text {
            configureText(message, isOutgoing: isOutgoing)
        } else if message.type == .image, let attachment = message.primaryAttachment, !attachment.url.isEmpty {
            configureImage(message, attachment: attachment, isOutgoing: isOutgoing)
        } else if message.type == .document, let attachment = message.primaryAttachment {
            configureDocument(message, attachment: attachment, isOutgoing: isOutgoing)
        } else {
            configureText(message, isOutgoing: isOutgoing)
        }

        configureReactions(message.reactions, currentUserId: currentUserId, isOutgoing: isOutgoing)

        accessibilityLabel = "\(isOutgoing ? "Sent" : "Received"): \(message.displayText)"
    }

    private func configureReplyPreview(_ preview: MessageReplyPreview?) {
        guard let preview else {
            replyPreviewView.isHidden = true
            return
        }
        replySenderLabel.text = preview.senderName
        replySummaryLabel.text = preview.summary
        replyPreviewView.isHidden = false
    }

    private func contentTopConstraint(
        for view: UIView,
        defaultConstant: CGFloat
    ) -> NSLayoutConstraint {
        if replyPreviewView.isHidden {
            return view.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: defaultConstant)
        }
        return view.topAnchor.constraint(equalTo: replyPreviewView.bottomAnchor, constant: 6)
    }

    private func configureReactions(
        _ reactions: [MessageReaction],
        currentUserId: String,
        isOutgoing: Bool
    ) {
        guard !reactions.isEmpty else {
            reactionPill.isHidden = true
            return
        }

        let counts = Dictionary(grouping: reactions) { $0.emoji }.mapValues { $0.count }
        let known = Set(Self.reactionOrder)
        let orderedEmojis = Self.reactionOrder.filter { counts[$0] != nil }
            + counts.keys.filter { !known.contains($0) }.sorted()
        reactionLabel.text = orderedEmojis.map { emoji in
            let count = counts[emoji] ?? 0
            return count > 1 ? "\(emoji) \(count)" : emoji
        }.joined(separator: "  ")

        let includesCurrentUser = reactions.contains { $0.userId == currentUserId }
        reactionPill.layer.borderColor = (
            includesCurrentUser ? ChitChatColors.accent : ChitChatColors.chatDetailBorder
        ).cgColor
        reactionPill.accessibilityLabel = includesCurrentUser
            ? "Reactions, including yours"
            : "Message reactions"
        reactionPill.isHidden = false
        bubbleBottomConstraint?.isActive = false

        reactionLayoutConstraints = [
            reactionPill.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -2),
            reactionPill.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -ChitChatSpacing.chatDetailRowBottom
            )
        ]
        if isOutgoing {
            reactionLayoutConstraints.append(
                reactionPill.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8)
            )
        } else {
            reactionLayoutConstraints.append(
                reactionPill.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8)
            )
        }
        NSLayoutConstraint.activate(reactionLayoutConstraints)
    }

    private func configureText(_ message: Message, isOutgoing: Bool) {
        messageLabel.isHidden = false
        bubbleView.configure(isOutgoing: isOutgoing)
        messageLabel.attributedText = attributedMessage(message)

        activeLayoutConstraints = [
            contentTopConstraint(
                for: messageLabel,
                defaultConstant: ChitChatSpacing.chatDetailBubbleVertical
            ),
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: ChitChatSpacing.chatDetailBubbleHorizontal
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -ChitChatSpacing.chatDetailBubbleHorizontal
            ),
            timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: bubbleView.leadingAnchor,
                constant: ChitChatSpacing.chatDetailBubbleHorizontal
            ),
            timeLabel.heightAnchor.constraint(equalToConstant: 13),
            timeLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -ChitChatSpacing.chatDetailBubbleVertical
            ),
            readView.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor)
        ]
        NSLayoutConstraint.activate(activeLayoutConstraints)
    }

    private func configureImage(_ message: Message, attachment: MessageAttachment, isOutgoing: Bool) {
        mediaImageView.isHidden = false
        bubbleView.configure(isOutgoing: isOutgoing)
        loadImage(from: attachment.url)

        let imageWidth = mediaImageView.widthAnchor.constraint(equalToConstant: 268)
        imageWidth.priority = .defaultHigh

        var constraints = [
            contentTopConstraint(for: mediaImageView, defaultConstant: 0),
            mediaImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            mediaImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            imageWidth,
            mediaImageView.heightAnchor.constraint(equalToConstant: 300),
            timeLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: bubbleView.leadingAnchor,
                constant: ChitChatSpacing.chatDetailBubbleHorizontal
            ),
            timeLabel.heightAnchor.constraint(equalToConstant: 13),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            readView.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor)
        ]

        let caption = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            captionLabel.isHidden = false
            captionLabel.text = caption
            constraints.append(contentsOf: [
                captionLabel.topAnchor.constraint(equalTo: mediaImageView.bottomAnchor, constant: 10),
                captionLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
                captionLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
                timeLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4)
            ])
        } else {
            constraints.append(timeLabel.topAnchor.constraint(equalTo: mediaImageView.bottomAnchor, constant: 8))
        }

        activeLayoutConstraints = constraints
        NSLayoutConstraint.activate(activeLayoutConstraints)
    }

    private func configureDocument(_ message: Message, attachment: MessageAttachment, isOutgoing: Bool) {
        documentIconWrap.isHidden = false
        documentNameLabel.isHidden = false
        documentSizeLabel.isHidden = false
        documentDivider.isHidden = false
        documentHintLabel.isHidden = false
        bubbleView.configure(isOutgoing: isOutgoing, radius: 20)

        documentNameLabel.text = ChatDetailFileFormatter.displayName(
            from: attachment.fileName,
            mimeType: attachment.mimeType
        )
        documentSizeLabel.text = ChatDetailFileFormatter.string(from: attachment.size)
            ?? documentTypeLabel(fileName: attachment.fileName, mimeType: attachment.mimeType)

        activeLayoutConstraints = [
            bubbleView.widthAnchor.constraint(greaterThanOrEqualToConstant: 214),

            contentTopConstraint(for: documentIconWrap, defaultConstant: 10),
            documentIconWrap.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            documentIconWrap.widthAnchor.constraint(equalToConstant: 44),
            documentIconWrap.heightAnchor.constraint(equalToConstant: 44),

            documentNameLabel.topAnchor.constraint(equalTo: documentIconWrap.topAnchor, constant: 2),
            documentNameLabel.leadingAnchor.constraint(equalTo: documentIconWrap.trailingAnchor, constant: 10),
            documentNameLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            documentNameLabel.heightAnchor.constraint(equalToConstant: 18),

            documentSizeLabel.topAnchor.constraint(equalTo: documentNameLabel.bottomAnchor, constant: 2),
            documentSizeLabel.leadingAnchor.constraint(equalTo: documentNameLabel.leadingAnchor),
            documentSizeLabel.trailingAnchor.constraint(equalTo: documentNameLabel.trailingAnchor),
            documentSizeLabel.heightAnchor.constraint(equalToConstant: 16),

            documentDivider.topAnchor.constraint(equalTo: documentIconWrap.bottomAnchor, constant: 8),
            documentDivider.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            documentDivider.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            documentDivider.heightAnchor.constraint(equalToConstant: 1),

            documentHintLabel.topAnchor.constraint(equalTo: documentDivider.bottomAnchor, constant: 7),
            documentHintLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            documentHintLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -10),
            documentHintLabel.heightAnchor.constraint(equalToConstant: 14),
            documentHintLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),

            timeLabel.centerYAnchor.constraint(equalTo: documentHintLabel.centerYAnchor),
            timeLabel.heightAnchor.constraint(equalToConstant: 13),
            readView.centerYAnchor.constraint(equalTo: documentHintLabel.centerYAnchor)
        ]
        NSLayoutConstraint.activate(activeLayoutConstraints)
    }

    private func documentTypeLabel(fileName: String?, mimeType: String?) -> String {
        let extensionValue = fileName.flatMap {
            URL(fileURLWithPath: $0).pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? ""
        if !extensionValue.isEmpty {
            return extensionValue.uppercased()
        }
        if let mimeType, let preferred = ChatDetailFileFormatter.preferredExtension(forMimeType: mimeType) {
            return preferred.uppercased()
        }
        return "Document"
    }

    private func resetContentVisibility() {
        [
            messageLabel,
            mediaImageView,
            captionLabel,
            documentIconWrap,
            documentNameLabel,
            documentSizeLabel,
            documentDivider,
            documentHintLabel,
            replyPreviewView,
            reactionPill
        ].forEach { $0.isHidden = true }
        readView.isHidden = true
    }

    private func attributedMessage(_ message: Message) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 20
        paragraph.maximumLineHeight = 20

        let font = message.isDeletedForEveryone
            ? UIFont.italicSystemFont(ofSize: 14)
            : ChitChatTypography.chatDetailMessage
        let color = message.isDeletedForEveryone
            ? ChitChatColors.textMuted
            : ChitChatColors.textPrimary

        return NSAttributedString(
            string: message.displayText,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func loadImage(from urlString: String) {
        representedImageURL = urlString
        if let cached = Self.imageCache.object(forKey: urlString as NSString) {
            mediaImageView.image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.imageCache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                guard self?.representedImageURL == urlString else { return }
                self?.mediaImageView.image = image
            }
        }
        imageTask?.resume()
    }
}
