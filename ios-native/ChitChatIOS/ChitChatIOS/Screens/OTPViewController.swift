import UIKit

final class OTPViewController: BaseViewController, UITextFieldDelegate {
    private let phone: String
    private var otpRequestId: String
    private var devOtp: String?
    private let sessionManager = SessionManager.shared
    private var timer: Timer?
    private var secondsRemaining = 60
    private var isVerifying = false
    private var didFocusFirstField = false

    private var otpFields: [UITextField] = []
    private let timerLabel = UILabel()
    private let resendButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let devOtpLabel = UILabel()
    private let loader = UIActivityIndicatorView(style: .medium)
    private let verifyButton = PrimaryButton(title: "Verify")

    init(phone: String, otpRequestId: String, devOtp: String?) {
        self.phone = phone
        self.otpRequestId = otpRequestId
        self.devOtp = devOtp
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
        startTimer()
        updateVerifyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFocusFirstField else { return }
        didFocusFirstField = true
        otpFields.first?.becomeFirstResponder()
    }

    deinit {
        timer?.invalidate()
    }

    private func buildUI() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let header = ChitChatComponents.makeHeader(
            title: "Verify phone number",
            target: self,
            backAction: #selector(goBack)
        )

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0

        let copy = UILabel()
        copy.text = "Enter the 6-digit code sent to"
        copy.font = ChitChatTypography.body
        copy.textColor = ChitChatColors.textMuted
        copy.textAlignment = .center

        let phoneLabel = UILabel()
        phoneLabel.text = phone
        phoneLabel.font = ChitChatTypography.title
        phoneLabel.textColor = ChitChatColors.accent
        phoneLabel.textAlignment = .center
        phoneLabel.adjustsFontSizeToFitWidth = true
        phoneLabel.minimumScaleFactor = 0.8

        let copyStack = UIStackView(arrangedSubviews: [copy, phoneLabel])
        copyStack.axis = .vertical
        copyStack.spacing = 7
        copyStack.alignment = .center

        let otpRow = UIStackView()
        otpRow.axis = .horizontal
        otpRow.alignment = .center
        otpRow.distribution = .equalSpacing
        otpRow.spacing = 6
        otpRow.translatesAutoresizingMaskIntoConstraints = false

        for index in 0..<6 {
            let field = UITextField()
            field.translatesAutoresizingMaskIntoConstraints = false
            field.keyboardType = .numberPad
            field.textContentType = .oneTimeCode
            field.textAlignment = .center
            field.font = ChitChatTypography.otp
            field.textColor = ChitChatColors.textPrimary
            field.tintColor = ChitChatColors.accent
            field.backgroundColor = ChitChatColors.surface
            field.layer.cornerRadius = ChitChatSpacing.otpRadius
            field.layer.borderWidth = 1.5
            field.layer.borderColor = ChitChatColors.border.cgColor
            field.delegate = self
            field.tag = index
            field.inputAccessoryView = ChitChatComponents.makeKeyboardDoneToolbar(
                target: self,
                action: #selector(verifyFromKeyboard)
            )
            field.addTarget(self, action: #selector(otpChanged(_:)), for: .editingChanged)
            field.widthAnchor.constraint(equalToConstant: ChitChatSpacing.otpCellWidth).isActive = true
            field.heightAnchor.constraint(equalToConstant: ChitChatSpacing.otpCellHeight).isActive = true
            otpFields.append(field)
            otpRow.addArrangedSubview(field)
        }

        timerLabel.font = ChitChatTypography.bodyMedium
        timerLabel.textColor = ChitChatColors.textMuted
        timerLabel.textAlignment = .center

        resendButton.setTitle("Resend code", for: .normal)
        resendButton.setTitleColor(ChitChatColors.accent, for: .normal)
        resendButton.titleLabel?.font = ChitChatTypography.bodySemibold
        resendButton.addTarget(self, action: #selector(resendCode), for: .touchUpInside)
        resendButton.isHidden = true

        devOtpLabel.font = ChitChatTypography.caption
        devOtpLabel.textColor = ChitChatColors.accent
        devOtpLabel.textAlignment = .center
        devOtpLabel.numberOfLines = 0
        devOtpLabel.text = devOtp.map { "Development OTP: \($0)" }
        devOtpLabel.isHidden = devOtp == nil

        errorLabel.font = ChitChatTypography.caption
        errorLabel.textColor = UIColor(hex: "#EF8F8F")
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        loader.color = ChitChatColors.accent
        loader.hidesWhenStopped = true

        verifyButton.addTarget(self, action: #selector(verifyOtp), for: .touchUpInside)

        stack.addArrangedSubview(copyStack)
        stack.setCustomSpacing(34, after: copyStack)
        stack.addArrangedSubview(otpRow)
        stack.setCustomSpacing(38, after: otpRow)
        stack.addArrangedSubview(timerLabel)
        stack.addArrangedSubview(resendButton)
        stack.setCustomSpacing(10, after: resendButton)
        stack.addArrangedSubview(devOtpLabel)
        stack.setCustomSpacing(8, after: devOtpLabel)
        stack.addArrangedSubview(errorLabel)
        stack.setCustomSpacing(18, after: errorLabel)
        stack.addArrangedSubview(loader)

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(verifyButton)
        scrollView.addSubview(stack)

        let keyboardBottom = verifyButton.bottomAnchor.constraint(
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
            scrollView.bottomAnchor.constraint(equalTo: verifyButton.topAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 34),
            stack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: 16
            ),
            stack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -16
            ),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),

            otpRow.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),

            verifyButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: ChitChatSpacing.screenHorizontal
            ),
            verifyButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -ChitChatSpacing.screenHorizontal
            ),
            verifyButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
            keyboardBottom
        ])

        updateTimerUI()
    }

    private func startTimer() {
        timer?.invalidate()
        secondsRemaining = 60
        updateTimerUI()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            secondsRemaining = max(secondsRemaining - 1, 0)
            updateTimerUI()
            if secondsRemaining == 0 {
                timer?.invalidate()
            }
        }
    }

    private func updateTimerUI() {
        timerLabel.text = "Resend code in \(secondsRemaining)s"
        timerLabel.isHidden = secondsRemaining == 0
        resendButton.isHidden = secondsRemaining != 0
    }

    private func updateVerifyState() {
        verifyButton.isEnabled = code().count == 6 && !isVerifying
        otpFields.forEach { $0.isEnabled = !isVerifying }
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message?.isEmpty ?? true
    }

    private func code() -> String {
        otpFields.compactMap { $0.text }.joined()
    }

    @objc private func otpChanged(_ field: UITextField) {
        let digits = field.text?.filter { $0.isNumber } ?? ""
        field.text = String(digits.suffix(1))
        setError(nil)
        if !(field.text ?? "").isEmpty, field.tag < otpFields.count - 1 {
            otpFields[field.tag + 1].becomeFirstResponder()
        }
        updateVerifyState()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 2
        textField.layer.borderColor = ChitChatColors.accent.cgColor
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 1.5
        textField.layer.borderColor = ChitChatColors.border.cgColor
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string.isEmpty, let current = textField.text, current.isEmpty, textField.tag > 0 {
            otpFields[textField.tag - 1].becomeFirstResponder()
            otpFields[textField.tag - 1].text = ""
            updateVerifyState()
            return false
        }
        return true
    }

    @objc private func verifyFromKeyboard() {
        dismissKeyboard()
        verifyOtp()
    }

    @objc private func verifyOtp() {
        guard !isVerifying else { return }
        guard code().count == 6 else {
            setError("Enter the 6-digit verification code.")
            return
        }

        dismissKeyboard()
        isVerifying = true
        verifyButton.setTitle("Verifying...", for: .normal)
        loader.startAnimating()
        setError(nil)
        updateVerifyState()

        Task {
            do {
                try await sessionManager.verifyOtp(
                    phone: phone,
                    otp: code(),
                    otpRequestId: otpRequestId
                )
                await MainActor.run {
                    self.loader.stopAnimating()
                    self.isVerifying = false
                    self.verifyButton.setTitle("Verify", for: .normal)
                    self.updateVerifyState()
                }
            } catch {
                await MainActor.run {
                    self.loader.stopAnimating()
                    self.isVerifying = false
                    self.verifyButton.setTitle("Verify", for: .normal)
                    self.setError(error.localizedDescription)
                    self.updateVerifyState()
                }
            }
        }
    }

    @objc private func resendCode() {
        guard !isVerifying else { return }
        setError(nil)
        loader.startAnimating()
        Task {
            do {
                let result = try await sessionManager.requestOtp(phone: phone)
                await MainActor.run {
                    self.otpRequestId = result.otpRequestId
                    self.devOtp = result.otp
                    self.devOtpLabel.text = result.otp.map { "Development OTP: \($0)" }
                    self.devOtpLabel.isHidden = result.otp == nil
                    self.otpFields.forEach { $0.text = "" }
                    self.otpFields.first?.becomeFirstResponder()
                    self.startTimer()
                    self.loader.stopAnimating()
                    self.updateVerifyState()
                }
            } catch {
                await MainActor.run {
                    self.loader.stopAnimating()
                    self.setError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
