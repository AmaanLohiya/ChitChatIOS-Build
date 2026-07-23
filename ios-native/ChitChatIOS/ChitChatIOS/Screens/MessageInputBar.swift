import UIKit

final class MessageInputBar: UIView, UITextFieldDelegate {
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var isSending = false

    var onSend: ((String) -> Void)?
    var onAttach: (() -> Void)?
    var onVoice: (() -> Void)?
    var onTextChanged: ((String) -> Void)?

    var currentText: String {
        textField.text ?? ""
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.chatDetailHeader

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.chatDetailBorder

        let attachButton = makeIconButton(
            symbol: "paperclip",
            pointSize: 24,
            color: ChitChatColors.textMuted,
            accessibilityLabel: "Attachments"
        )
        attachButton.addTarget(self, action: #selector(openAttachments), for: .touchUpInside)

        let inputContainer = UIView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = ChitChatColors.chatDetailInput
        inputContainer.layer.cornerRadius = ChitChatSpacing.chatDetailInputRadius
        inputContainer.layer.cornerCurve = .continuous

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.backgroundColor = .clear
        textField.textColor = ChitChatColors.textPrimary
        textField.tintColor = ChitChatColors.accent
        textField.font = ChitChatTypography.chatDetailInput
        textField.autocorrectionType = .yes
        textField.autocapitalizationType = .sentences
        textField.returnKeyType = .send
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(
            string: "Message",
            attributes: [
                .font: ChitChatTypography.chatDetailInput,
                .foregroundColor: ChitChatColors.chatDetailPlaceholder
            ]
        )
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        let smileButton = makeIconButton(
            symbol: "face.smiling",
            pointSize: 22,
            color: ChitChatColors.textMuted,
            accessibilityLabel: "Emoji"
        )
        let cameraButton = makeIconButton(
            symbol: "camera",
            pointSize: 22,
            color: ChitChatColors.textMuted,
            accessibilityLabel: "Camera"
        )

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.backgroundColor = ChitChatColors.accent
        sendButton.tintColor = UIColor(hex: "#F4FFFB")
        sendButton.layer.cornerRadius = ChitChatSpacing.chatDetailSendButton / 2
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        addSubview(divider)
        addSubview(attachButton)
        addSubview(inputContainer)
        addSubview(sendButton)
        inputContainer.addSubview(textField)
        inputContainer.addSubview(smileButton)
        inputContainer.addSubview(cameraButton)

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            sendButton.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -ChitChatSpacing.chatDetailComposerHorizontal
            ),
            sendButton.topAnchor.constraint(
                equalTo: topAnchor,
                constant: ChitChatSpacing.chatDetailComposerTop
            ),
            sendButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailSendButton),
            sendButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailSendButton),
            sendButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -ChitChatSpacing.chatDetailComposerBottom
            ),

            attachButton.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: ChitChatSpacing.chatDetailComposerHorizontal
            ),
            attachButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailAttachButton),
            attachButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailAttachButton),

            inputContainer.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 6),
            inputContainer.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            inputContainer.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailInputHeight),

            textField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -74),
            textField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            textField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),

            cameraButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            cameraButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: 32),
            cameraButton.heightAnchor.constraint(equalToConstant: 32),

            smileButton.trailingAnchor.constraint(equalTo: cameraButton.leadingAnchor),
            smileButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            smileButton.widthAnchor.constraint(equalToConstant: 32),
            smileButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        updateState()
    }

    private func makeIconButton(
        symbol: String,
        pointSize: CGFloat,
        color: UIColor,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = color
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            ),
            for: .normal
        )
        return button
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return false
    }

    func setSending(_ isSending: Bool) {
        self.isSending = isSending
        textField.isEnabled = !isSending
        updateState()
    }

    func clearText() {
        textField.text = ""
        updateState()
    }

    func restoreText(_ text: String) {
        textField.text = text
        updateState()
    }

    func focusTextInput() {
        textField.becomeFirstResponder()
    }

    @objc private func textChanged() {
        updateState()
        onTextChanged?(textField.text ?? "")
    }

    private func updateState() {
        let hasText = !(textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let symbol = hasText ? "paperplane" : "mic"
        sendButton.setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            ),
            for: .normal
        )
        sendButton.isEnabled = !isSending
        sendButton.alpha = isSending ? 0.58 : 1
        sendButton.accessibilityLabel = hasText ? "Send message" : "Voice message"
    }

    @objc private func send() {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending else { return }
        if text.isEmpty {
            onVoice?()
        } else {
            onSend?(text)
        }
    }

    @objc private func openAttachments() {
        guard !isSending else { return }
        onAttach?()
    }
}
