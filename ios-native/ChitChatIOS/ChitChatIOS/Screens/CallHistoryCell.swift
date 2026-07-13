import UIKit

final class CallHistoryCell: UITableViewCell {
    static let reuseIdentifier = "CallHistoryCell"

    private let avatarView = ReplicaAvatarView()
    private let nameLabel = UILabel()
    private let directionIcon = UIImageView()
    private let detailLabel = UILabel()
    private let timestampLabel = UILabel()
    private let callButton = UIButton(type: .system)
    private let divider = UIView()

    var onCall: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCall = nil
        nameLabel.text = nil
        detailLabel.text = nil
        timestampLabel.text = nil
    }

    func configure(item: CallHistoryItem, detail: String, timestamp: String) {
        let isMissed = item.status == .missed && item.direction == .incoming
        avatarView.configure(
            name: item.otherParticipant.displayName,
            urlString: item.otherParticipant.avatarUrl,
            updatedAt: item.updatedAt
        )
        nameLabel.text = item.otherParticipant.displayName
        nameLabel.textColor = isMissed ? UIColor(hex: "#F16458") : ChitChatColors.textPrimary
        detailLabel.text = detail
        timestampLabel.text = timestamp

        let iconName: String
        let iconColor: UIColor
        if isMissed {
            iconName = "phone.down.fill"
            iconColor = UIColor(hex: "#F16458")
        } else if item.direction == .incoming {
            iconName = "phone.arrow.down.left"
            iconColor = ChitChatColors.accent
        } else {
            iconName = "phone.arrow.up.right"
            iconColor = ChitChatColors.textMuted
        }
        directionIcon.image = UIImage(systemName: iconName)
        directionIcon.tintColor = iconColor
    }

    private func buildUI() {
        selectionStyle = .none
        backgroundColor = UIColor(hex: "#0A1F2C")
        contentView.backgroundColor = UIColor(hex: "#0A1F2C")

        [avatarView, nameLabel, directionIcon, detailLabel, timestampLabel, callButton, divider]
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }

        nameLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        nameLabel.numberOfLines = 1
        detailLabel.font = UIFont.systemFont(ofSize: 9.5, weight: .medium)
        detailLabel.textColor = ChitChatColors.textMuted
        detailLabel.numberOfLines = 1
        timestampLabel.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        timestampLabel.textColor = ChitChatColors.textMuted
        timestampLabel.textAlignment = .right
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        directionIcon.contentMode = .scaleAspectFit

        callButton.tintColor = ChitChatColors.accent
        callButton.setImage(
            UIImage(
                systemName: "phone",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)
            ),
            for: .normal
        )
        callButton.accessibilityLabel = "Start voice call"
        callButton.addTarget(self, action: #selector(callTapped), for: .touchUpInside)
        divider.backgroundColor = ChitChatColors.border

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 9),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestampLabel.leadingAnchor, constant: -8),

            directionIcon.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            directionIcon.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            directionIcon.widthAnchor.constraint(equalToConstant: 18),
            directionIcon.heightAnchor.constraint(equalToConstant: 18),

            detailLabel.leadingAnchor.constraint(equalTo: directionIcon.trailingAnchor, constant: 6),
            detailLabel.centerYAnchor.constraint(equalTo: directionIcon.centerYAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestampLabel.leadingAnchor, constant: -8),

            callButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            callButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            callButton.widthAnchor.constraint(equalToConstant: 42),
            callButton.heightAnchor.constraint(equalToConstant: 42),

            timestampLabel.trailingAnchor.constraint(equalTo: callButton.leadingAnchor, constant: -6),
            timestampLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    @objc private func callTapped() {
        onCall?()
    }
}
