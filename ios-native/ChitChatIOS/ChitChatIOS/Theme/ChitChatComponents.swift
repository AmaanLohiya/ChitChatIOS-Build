import UIKit

final class PrimaryButton: UIButton {
    override var isEnabled: Bool {
        didSet { applyState() }
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        titleLabel?.font = ChitChatTypography.button
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.cornerRadius = ChitChatSpacing.buttonRadius
        heightAnchor.constraint(equalToConstant: ChitChatSpacing.primaryButtonHeight).isActive = true
        applyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyState() {
        backgroundColor = isEnabled ? ChitChatColors.whatsappGreen : ChitChatColors.disabledGreen
        setTitleColor(isEnabled ? .white : UIColor(hex: "#768A87"), for: .normal)
        alpha = isHighlighted ? 0.86 : 1
    }

    override var isHighlighted: Bool {
        didSet { applyState() }
    }
}

final class WelcomeButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        setTitleColor(UIColor(hex: "#59C86C"), for: .normal)
        titleLabel?.font = ChitChatTypography.button
        titleLabel?.adjustsFontForContentSizeCategory = true
        backgroundColor = .white
        layer.cornerRadius = 20
        heightAnchor.constraint(equalToConstant: 58).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.86 : 1 }
    }
}

final class RoundedTextField: UITextField {
    init(placeholder: String, keyboardType: UIKeyboardType = .default) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        textColor = ChitChatColors.textPrimary
        tintColor = ChitChatColors.accent
        font = ChitChatTypography.bodyMedium
        backgroundColor = ChitChatColors.inputBackground
        layer.cornerRadius = ChitChatSpacing.inputRadius
        autocorrectionType = .no
        autocapitalizationType = .none
        heightAnchor.constraint(equalToConstant: ChitChatSpacing.inputHeight).isActive = true
        attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: ChitChatColors.placeholder]
        )
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        leftViewMode = .always
        rightView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        rightViewMode = .always
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum ChitChatComponents {
    static func makeHeader(title: String, target: Any?, backAction: Selector?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = ChitChatColors.header

        let bottomBorder = UIView()
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBorder.backgroundColor = UIColor.white.withAlphaComponent(0.02)
        container.addSubview(bottomBorder)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.font = ChitChatTypography.headerTitle
        titleLabel.adjustsFontForContentSizeCategory = false

        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = ChitChatColors.textPrimary
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        if let backAction = backAction {
            backButton.addTarget(target, action: backAction, for: .touchUpInside)
        }

        container.addSubview(backButton)
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: ChitChatSpacing.headerHorizontal),
            backButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -18),

            bottomBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1)
        ])

        return container
    }

    static func makeKeyboardDoneToolbar(target: Any?, action: Selector) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: target, action: action)
        done.tintColor = UIColor(hex: "#0A8F78")
        toolbar.items = [spacer, done]
        return toolbar
    }

    static func applyCardShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
    }
}

extension UIView {
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

final class AvatarView: UIView {
    private let initialsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.accent.withAlphaComponent(0.18)
        clipsToBounds = true

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center
        addSubview(initialsLabel)
        initialsLabel.pinEdges(to: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    func configure(name: String) {
        let words = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let initials = words.map(String.init).joined().uppercased()
        initialsLabel.text = initials.isEmpty ? "C" : initials
    }
}

final class EmptyStateView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = ChitChatColors.textMuted.withAlphaComponent(0.7)
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = ChitChatTypography.title
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.textAlignment = .center

        subtitleLabel.font = ChitChatTypography.body
        subtitleLabel.textColor = ChitChatColors.textMuted
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: String, title: String, subtitle: String) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

enum ChitChatDateFormatter {
    private static let fractionalISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardISO = ISO8601DateFormatter()

    static func date(from rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        return fractionalISO.date(from: rawValue) ?? standardISO.date(from: rawValue)
    }

    static func listTimestamp(from rawValue: String?) -> String {
        guard let date = date(from: rawValue) else { return "" }
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
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func messageTime(from rawValue: String?) -> String {
        guard let date = date(from: rawValue) else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


