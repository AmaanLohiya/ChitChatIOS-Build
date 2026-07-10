import UIKit

final class AddContactViewController: BaseViewController {
    private struct Country {
        let name: String
        let code: String
    }

    private let countries = [
        Country(name: "United States", code: "+1"),
        Country(name: "United Kingdom", code: "+44"),
        Country(name: "India", code: "+91"),
        Country(name: "China", code: "+86"),
        Country(name: "Japan", code: "+81"),
        Country(name: "Germany", code: "+49")
    ]

    private let contactService: ContactService
    private var selectedCountry: Country
    private let nameField = RoundedTextField(placeholder: "Contact name")
    private let phoneField = RoundedTextField(placeholder: "Phone number", keyboardType: .phonePad)
    private let countryButton = UIButton(type: .system)
    private let countryCodeLabel = UILabel()
    private let saveButton = PrimaryButton(title: "Save contact")
    private let errorLabel = UILabel()
    private var isSaving = false

    var onContactCreated: ((Contact) -> Void)?

    init(contactService: ContactService = ContactService()) {
        self.contactService = contactService
        self.selectedCountry = countries[0]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add contact"
        view.backgroundColor = ChitChatColors.authBackground
        buildUI()
        updateCountry()
        updateSaveState()
    }

    private func buildUI() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let instruction = UILabel()
        instruction.translatesAutoresizingMaskIntoConstraints = false
        instruction.text = "Add a phone number to find someone on ChitChat."
        instruction.font = ChitChatTypography.body
        instruction.textColor = ChitChatColors.textMuted
        instruction.numberOfLines = 0

        nameField.textContentType = .name
        nameField.autocapitalizationType = .words
        nameField.addTarget(self, action: #selector(formChanged), for: .editingChanged)

        countryButton.translatesAutoresizingMaskIntoConstraints = false
        countryButton.backgroundColor = ChitChatColors.inputBackground
        countryButton.layer.cornerRadius = ChitChatSpacing.selectorRadius
        countryButton.contentHorizontalAlignment = .left
        countryButton.titleLabel?.font = ChitChatTypography.bodySemibold
        countryButton.setTitleColor(ChitChatColors.textPrimary, for: .normal)
        countryButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        countryButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.inputHeight).isActive = true
        countryButton.addTarget(self, action: #selector(selectCountry), for: .touchUpInside)

        let codeBox = UIView()
        codeBox.translatesAutoresizingMaskIntoConstraints = false
        codeBox.backgroundColor = ChitChatColors.inputBackground
        codeBox.layer.cornerRadius = ChitChatSpacing.inputRadius
        codeBox.widthAnchor.constraint(equalToConstant: 78).isActive = true

        countryCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        countryCodeLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        countryCodeLabel.textColor = ChitChatColors.textPrimary
        countryCodeLabel.textAlignment = .center
        codeBox.addSubview(countryCodeLabel)
        countryCodeLabel.pinEdges(to: codeBox)

        phoneField.textContentType = .telephoneNumber
        phoneField.inputAccessoryView = ChitChatComponents.makeKeyboardDoneToolbar(
            target: self,
            action: #selector(dismissKeyboard)
        )
        phoneField.addTarget(self, action: #selector(formChanged), for: .editingChanged)

        let phoneRow = UIStackView(arrangedSubviews: [codeBox, phoneField])
        phoneRow.axis = .horizontal
        phoneRow.spacing = 10

        errorLabel.font = ChitChatTypography.caption
        errorLabel.textColor = UIColor(hex: "#EF8F8F")
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [instruction, nameField, countryButton, phoneRow, errorLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12

        saveButton.addTarget(self, action: #selector(saveContact), for: .touchUpInside)

        view.addSubview(stack)
        view.addSubview(saveButton)

        let keyboardBottom = saveButton.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -16
        )
        keyboardBottom.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ChitChatSpacing.screenHorizontal),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ChitChatSpacing.screenHorizontal),
            saveButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),
            keyboardBottom
        ])
    }

    private func updateCountry() {
        countryButton.setTitle("\(selectedCountry.name)  \(selectedCountry.code)", for: .normal)
        countryCodeLabel.text = selectedCountry.code
    }

    private func normalizedPhone() -> String {
        let raw = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = raw.filter { $0.isNumber || $0 == "+" }
        if cleaned.hasPrefix("+") { return cleaned }
        return "\(selectedCountry.code)\(cleaned.filter { $0.isNumber })"
    }

    private func updateSaveState() {
        let hasName = !(nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let phoneDigits = phoneField.text?.filter { $0.isNumber }.count ?? 0
        saveButton.isEnabled = hasName && phoneDigits >= 8 && !isSaving
    }

    private func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message?.isEmpty ?? true
    }

    @objc private func formChanged() {
        setError(nil)
        updateSaveState()
    }

    @objc private func selectCountry() {
        dismissKeyboard()
        let alert = UIAlertController(title: "Select country", message: nil, preferredStyle: .actionSheet)
        countries.forEach { country in
            alert.addAction(UIAlertAction(title: "\(country.name)  \(country.code)", style: .default) { [weak self] _ in
                self?.selectedCountry = country
                self?.updateCountry()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func saveContact() {
        dismissKeyboard()
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = normalizedPhone()
        guard !name.isEmpty else {
            setError("Enter a contact name.")
            return
        }
        guard phone.range(of: #"^\+[1-9]\d{7,14}$"#, options: .regularExpression) != nil else {
            setError("Enter a valid phone number.")
            return
        }
        guard !isSaving else { return }

        isSaving = true
        saveButton.setTitle("Saving...", for: .normal)
        updateSaveState()

        Task { [weak self] in
            guard let self else { return }
            do {
                let contact = try await contactService.createContact(name: name, phoneNumber: phone)
                await MainActor.run {
                    self.isSaving = false
                    self.saveButton.setTitle("Save contact", for: .normal)
                    self.onContactCreated?(contact)
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.saveButton.setTitle("Save contact", for: .normal)
                    self.setError(error.localizedDescription)
                    self.updateSaveState()
                }
            }
        }
    }
}
