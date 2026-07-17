import UIKit

struct CountryOption {
    let code: String
    let iso: String
    let name: String
}

final class LoginViewController: BaseViewController, UITextFieldDelegate {
    private let countries = [
        CountryOption(code: "+1", iso: "us", name: "United States"),
        CountryOption(code: "+44", iso: "gb", name: "United Kingdom"),
        CountryOption(code: "+91", iso: "in", name: "India"),
        CountryOption(code: "+86", iso: "cn", name: "China"),
        CountryOption(code: "+81", iso: "jp", name: "Japan"),
        CountryOption(code: "+49", iso: "de", name: "Germany")
    ]

    private var selectedCountry: CountryOption
    private let sessionManager = SessionManager.shared
    private let countryButton = UIButton(type: .system)
    private let countryNameLabel = UILabel()
    private let countryCodeLabel = UILabel()
    private let phoneField = RoundedTextField(placeholder: "Phone number", keyboardType: .phonePad)
    private let continueButton = PrimaryButton(title: "Continue")
    private let errorLabel = UILabel()
    private var isSubmitting = false

    init() {
        selectedCountry = countries[0]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
        updateCountryUI()
        updateContinueState()
    }

    private func buildUI() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let header = ChitChatComponents.makeHeader(
            title: "Enter your phone number",
            target: self,
            backAction: #selector(goBack)
        )

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 0

        let copy = UILabel()
        copy.text = "ChitChat will prepare a verification code for your phone number."
        copy.font = ChitChatTypography.body
        copy.textColor = ChitChatColors.textMuted
        copy.numberOfLines = 0

        let help = UIButton(type: .system)
        help.translatesAutoresizingMaskIntoConstraints = false
        help.setTitle("What's my number?", for: .normal)
        help.setTitleColor(ChitChatColors.accent, for: .normal)
        help.titleLabel?.font = ChitChatTypography.bodyMedium
        help.contentHorizontalAlignment = .leading
        help.addTarget(self, action: #selector(showNumberHelp), for: .touchUpInside)

        let copyBlock = UIStackView(arrangedSubviews: [copy, help])
        copyBlock.axis = .vertical
        copyBlock.spacing = 4

        countryButton.translatesAutoresizingMaskIntoConstraints = false
        countryButton.backgroundColor = ChitChatColors.inputBackground
        countryButton.layer.cornerRadius = ChitChatSpacing.selectorRadius
        countryButton.addTarget(self, action: #selector(openCountryPicker), for: .touchUpInside)
        countryButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.inputHeight).isActive = true
        countryButton.accessibilityLabel = "Select country"

        countryNameLabel.translatesAutoresizingMaskIntoConstraints = false
        countryNameLabel.font = ChitChatTypography.bodySemibold
        countryNameLabel.textColor = ChitChatColors.textPrimary
        countryNameLabel.isUserInteractionEnabled = false

        let countryChevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        countryChevron.translatesAutoresizingMaskIntoConstraints = false
        countryChevron.tintColor = ChitChatColors.textMuted
        countryChevron.contentMode = .scaleAspectFit
        countryChevron.isUserInteractionEnabled = false

        countryButton.addSubview(countryNameLabel)
        countryButton.addSubview(countryChevron)

        let phoneRow = UIStackView()
        phoneRow.translatesAutoresizingMaskIntoConstraints = false
        phoneRow.axis = .horizontal
        phoneRow.spacing = 10
        phoneRow.alignment = .fill

        let codeBox = UIView()
        codeBox.backgroundColor = ChitChatColors.inputBackground
        codeBox.layer.cornerRadius = ChitChatSpacing.inputRadius
        codeBox.translatesAutoresizingMaskIntoConstraints = false
        codeBox.widthAnchor.constraint(equalToConstant: 78).isActive = true

        countryCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        countryCodeLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        countryCodeLabel.textColor = ChitChatColors.textPrimary
        countryCodeLabel.textAlignment = .center
        codeBox.addSubview(countryCodeLabel)
        countryCodeLabel.pinEdges(to: codeBox)

        phoneField.delegate = self
        phoneField.textContentType = .telephoneNumber
        phoneField.inputAccessoryView = ChitChatComponents.makeKeyboardDoneToolbar(
            target: self,
            action: #selector(dismissKeyboard)
        )
        phoneField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)

        phoneRow.addArrangedSubview(codeBox)
        phoneRow.addArrangedSubview(phoneField)

        errorLabel.font = ChitChatTypography.caption
        errorLabel.textColor = UIColor(hex: "#EF8F8F")
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        continueButton.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)

        content.addArrangedSubview(copyBlock)
        content.setCustomSpacing(26, after: copyBlock)
        content.addArrangedSubview(countryButton)
        content.setCustomSpacing(12, after: countryButton)
        content.addArrangedSubview(phoneRow)
        content.setCustomSpacing(10, after: phoneRow)
        content.addArrangedSubview(errorLabel)
        content.setCustomSpacing(6, after: errorLabel)

        view.addSubview(header)
        view.addSubview(scrollView)
        view.addSubview(continueButton)
        scrollView.addSubview(content)

        let keyboardBottom = continueButton.bottomAnchor.constraint(
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
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 26),
            content.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: ChitChatSpacing.screenHorizontal
            ),
            content.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -ChitChatSpacing.screenHorizontal
            ),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),

            countryNameLabel.leadingAnchor.constraint(equalTo: countryButton.leadingAnchor, constant: 18),
            countryNameLabel.centerYAnchor.constraint(equalTo: countryButton.centerYAnchor),
            countryNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countryChevron.leadingAnchor, constant: -12),
            countryChevron.trailingAnchor.constraint(equalTo: countryButton.trailingAnchor, constant: -18),
            countryChevron.centerYAnchor.constraint(equalTo: countryButton.centerYAnchor),
            countryChevron.widthAnchor.constraint(equalToConstant: 15),
            countryChevron.heightAnchor.constraint(equalToConstant: 15),

            continueButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: ChitChatSpacing.screenHorizontal
            ),
            continueButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -ChitChatSpacing.screenHorizontal
            ),
            continueButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
            keyboardBottom
        ])
    }

    private func updateCountryUI() {
        countryNameLabel.text = selectedCountry.name
        countryCodeLabel.text = selectedCountry.code
        countryButton.accessibilityValue = "\(selectedCountry.name), \(selectedCountry.code)"
    }

    private func normalizedPhone() -> String {
        let raw = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = raw.filter { $0.isNumber || $0 == "+" }
        if cleaned.hasPrefix("+") {
            return cleaned
        }
        return "\(selectedCountry.code)\(cleaned.filter { $0.isNumber })"
    }

    private func updateContinueState() {
        let digits = phoneField.text?.filter { $0.isNumber } ?? ""
        continueButton.isEnabled = digits.count >= 8 && !isSubmitting
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message?.isEmpty ?? true
    }

    @objc private func phoneChanged() {
        let sanitized = phoneField.text?.filter { $0.isNumber || $0 == "+" } ?? ""
        if sanitized != phoneField.text {
            phoneField.text = sanitized
        }
        setError(nil)
        updateContinueState()
    }

    @objc private func showNumberHelp() {
        dismissKeyboard()
        showAlert(message: "On iPhone, open Settings > Phone > My Number to check the number assigned to your SIM.")
    }

    @objc private func openCountryPicker() {
        dismissKeyboard()
        let alert = UIAlertController(title: "Select country", message: nil, preferredStyle: .actionSheet)
        countries.forEach { country in
            let suffix = country.code == selectedCountry.code ? " - Selected" : ""
            alert.addAction(
                UIAlertAction(title: "\(country.name)  \(country.code)\(suffix)", style: .default) { [weak self] _ in
                    self?.selectedCountry = country
                    self?.updateCountryUI()
                }
            )
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleContinue() {
        dismissKeyboard()
        let phone = normalizedPhone()
        guard phone.range(of: #"^\+[1-9]\d{7,14}$"#, options: .regularExpression) != nil else {
            setError("Please enter a valid phone number.")
            return
        }
        guard !isSubmitting else { return }

        isSubmitting = true
        continueButton.isEnabled = false
        continueButton.setTitle("Preparing...", for: .normal)
        setError(nil)
        Task {
            do {
                let result = try await sessionManager.requestOtp(phone: phone)
                await MainActor.run {
                    guard result.deliveryMode != .demo || result.otp?.count == 6 else {
                        self.setError("The demo verification code is unavailable. Please try again.")
                        self.isSubmitting = false
                        self.continueButton.setTitle("Continue", for: .normal)
                        self.updateContinueState()
                        return
                    }
                    let otpController = OTPViewController(
                        phone: phone,
                        otpRequestId: result.otpRequestId,
                        deliveryMode: result.deliveryMode,
                        demoOtp: result.deliveryMode == .demo ? result.otp : nil,
                        resendAvailableAt: result.resendAvailableAt
                    )
                    self.navigationController?.pushViewController(otpController, animated: true)
                    self.isSubmitting = false
                    self.continueButton.setTitle("Continue", for: .normal)
                    self.updateContinueState()
                }
            } catch {
                await MainActor.run {
                    self.setError(error.localizedDescription)
                    self.isSubmitting = false
                    self.continueButton.setTitle("Continue", for: .normal)
                    self.updateContinueState()
                }
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
