import Contacts
import ContactsUI
import UIKit

final class ContactMessageCardView: UIView {
    private let iconView = UIView()
    private let initialsLabel = UILabel()
    private let nameLabel = UILabel()
    private let organizationLabel = UILabel()
    private let phoneLabel = UILabel()
    private let actionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(_ contact: MessageContact?, actionText: String = "Tap to view or save") {
        let validContact = contact?.isValid == true ? contact : nil
        initialsLabel.text = validContact?.initials ?? "?"
        nameLabel.text = validContact?.displayName ?? "Unsupported contact"
        organizationLabel.text = validContact?.organization
        organizationLabel.isHidden = validContact?.organization?.isEmpty ?? true
        phoneLabel.text = validContact?.phoneSummary ?? "No usable phone number"
        actionLabel.text = actionText
        accessibilityLabel = "\(nameLabel.text ?? "Contact"), \(phoneLabel.text ?? "")"
    }

    @discardableResult
    static func presentActions(for contact: MessageContact?, from presenter: UIViewController) -> Bool {
        guard let contact, contact.isValid else { return false }
        let details = contactDetails(contact)
        let alert = UIAlertController(
            title: contact.displayName,
            message: details,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "View Contact", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            let detailsAlert = UIAlertController(title: contact.displayName, message: details, preferredStyle: .alert)
            detailsAlert.addAction(UIAlertAction(title: "Close", style: .cancel))
            detailsAlert.addAction(UIAlertAction(title: "Save Contact", style: .default) { [weak presenter] _ in
                guard let presenter else { return }
                presentNewContact(contact, from: presenter)
            })
            presenter.present(detailsAlert, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Save Contact", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            presentNewContact(contact, from: presenter)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = presenter.view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.midY,
            width: 1,
            height: 1
        )
        presenter.present(alert, animated: true)
        return true
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(hex: "#11222F").withAlphaComponent(0.26)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = ChitChatColors.chatDetailInput.withAlphaComponent(0.82)
        iconView.layer.cornerRadius = 23
        iconView.layer.cornerCurve = .continuous

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center
        initialsLabel.numberOfLines = 1

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        nameLabel.textColor = ChitChatColors.textPrimary
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        organizationLabel.translatesAutoresizingMaskIntoConstraints = false
        organizationLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        organizationLabel.textColor = UIColor(red: 214 / 255, green: 227 / 255, blue: 237 / 255, alpha: 0.72)
        organizationLabel.numberOfLines = 1
        organizationLabel.lineBreakMode = .byTruncatingTail

        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        phoneLabel.textColor = UIColor(red: 214 / 255, green: 227 / 255, blue: 237 / 255, alpha: 0.72)
        phoneLabel.numberOfLines = 1
        phoneLabel.lineBreakMode = .byTruncatingTail

        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        actionLabel.textColor = ChitChatColors.accent
        actionLabel.numberOfLines = 1
        actionLabel.textAlignment = .center

        addSubview(iconView)
        iconView.addSubview(initialsLabel)
        addSubview(nameLabel)
        addSubview(organizationLabel)
        addSubview(phoneLabel)
        addSubview(actionLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 46),
            iconView.heightAnchor.constraint(equalToConstant: 46),

            initialsLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconView.topAnchor, constant: 1),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nameLabel.heightAnchor.constraint(equalToConstant: 18),

            organizationLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            organizationLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            organizationLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            organizationLabel.heightAnchor.constraint(equalToConstant: 14),

            phoneLabel.topAnchor.constraint(equalTo: organizationLabel.bottomAnchor, constant: 2),
            phoneLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            phoneLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            phoneLabel.heightAnchor.constraint(equalToConstant: 16),

            actionLabel.topAnchor.constraint(greaterThanOrEqualTo: iconView.bottomAnchor, constant: 10),
            actionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            actionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actionLabel.heightAnchor.constraint(equalToConstant: 15),
            actionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    private static func presentNewContact(_ contact: MessageContact, from presenter: UIViewController) {
        let mutable = CNMutableContact()
        let components = PersonNameComponentsFormatter().personNameComponents(from: contact.displayName)
        mutable.givenName = components?.givenName ?? contact.displayName
        mutable.familyName = components?.familyName ?? ""
        mutable.organizationName = contact.organization ?? ""
        mutable.phoneNumbers = contact.phones.map { phone in
            CNLabeledValue(
                label: contactLabel(phone.label),
                value: CNPhoneNumber(stringValue: phone.number)
            )
        }
        let controller = CNContactViewController(forNewContact: mutable)
        controller.allowsEditing = true
        controller.allowsActions = false
        presenter.present(UINavigationController(rootViewController: controller), animated: true)
    }

    private static func contactLabel(_ value: String?) -> String {
        let label = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch label {
        case "mobile":
            return CNLabelPhoneNumberMobile
        case "home":
            return CNLabelHome
        case "work":
            return CNLabelWork
        default:
            return CNLabelPhoneNumberMain
        }
    }

    private static func contactDetails(_ contact: MessageContact) -> String {
        let organization = contact.organization.map { "Organization: \($0)" }
        let numbers = contact.phones.map { phone in
            if let label = phone.label, !label.isEmpty {
                return "\(label): \(phone.number)"
            }
            return phone.number
        }
        return ([organization].compactMap { $0 } + numbers).joined(separator: "\n")
    }
}

final class ContactMessageViewController: UIViewController, CNContactPickerDelegate {
    var onSend: ((MessageContact) -> Void)?

    private let store = CNContactStore()
    private let card = ContactMessageCardView()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let chooseButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var selectedContact: MessageContact?
    private var didStartSelection = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.background
        title = "Share Contact"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        buildUI()
        configureLoading()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartSelection else { return }
        didStartSelection = true
        startSelectionFlow()
    }

    private func buildUI() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Share this contact?"
        statusLabel.textColor = ChitChatColors.textPrimary
        statusLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        statusLabel.numberOfLines = 0

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.textColor = ChitChatColors.textMuted
        detailLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        detailLabel.numberOfLines = 0

        card.isHidden = true

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = ChitChatColors.accent

        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        chooseButton.setTitle("Choose Contact", for: .normal)
        chooseButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        chooseButton.tintColor = ChitChatColors.textPrimary
        chooseButton.backgroundColor = ChitChatColors.chatDetailInput
        chooseButton.layer.cornerRadius = 16
        chooseButton.addTarget(self, action: #selector(chooseTapped), for: .touchUpInside)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        sendButton.tintColor = ChitChatColors.background
        sendButton.backgroundColor = ChitChatColors.accent
        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        view.addSubview(statusLabel)
        view.addSubview(detailLabel)
        view.addSubview(card)
        view.addSubview(activityIndicator)
        view.addSubview(chooseButton)
        view.addSubview(sendButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            detailLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),

            card.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 22),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            activityIndicator.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 36),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            chooseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            chooseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            chooseButton.heightAnchor.constraint(equalToConstant: 50),

            sendButton.leadingAnchor.constraint(equalTo: chooseButton.trailingAnchor, constant: 12),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            sendButton.bottomAnchor.constraint(equalTo: chooseButton.bottomAnchor),
            sendButton.widthAnchor.constraint(equalTo: chooseButton.widthAnchor),
            sendButton.heightAnchor.constraint(equalTo: chooseButton.heightAnchor)
        ])
    }

    private func configureLoading() {
        statusLabel.text = "Choose a contact"
        detailLabel.text = "Only the selected contact's name, organization, and phone numbers will be shared."
        card.isHidden = true
        activityIndicator.startAnimating()
        chooseButton.isEnabled = false
        sendButton.isEnabled = false
        sendButton.alpha = 0.5
    }

    private func configurePreview(_ contact: MessageContact) {
        selectedContact = contact
        statusLabel.text = "Share this contact?"
        detailLabel.text = "The receiver can view this card and choose whether to save it."
        card.configure(contact, actionText: "Ready to send")
        card.isHidden = false
        activityIndicator.stopAnimating()
        chooseButton.isEnabled = true
        chooseButton.setTitle("Choose Another", for: .normal)
        sendButton.isEnabled = true
        sendButton.alpha = 1
    }

    private func configureError(_ message: String, canOpenSettings: Bool = false) {
        selectedContact = nil
        statusLabel.text = "Unable to share contact"
        detailLabel.text = message
        card.isHidden = true
        activityIndicator.stopAnimating()
        chooseButton.isEnabled = true
        chooseButton.setTitle(canOpenSettings ? "Open Settings" : "Try Again", for: .normal)
        sendButton.isEnabled = false
        sendButton.alpha = 0.5
    }

    private func startSelectionFlow() {
        configureLoading()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            store.requestAccess(for: .contacts) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.presentPickerIfContactsExist() : self.configureError(
                        "Contacts permission is required to choose a contact.",
                        canOpenSettings: true
                    )
                }
            }
        case .authorized:
            presentPickerIfContactsExist()
        case .denied, .restricted:
            configureError("Contacts permission is required to choose a contact.", canOpenSettings: true)
        @unknown default:
            presentPickerIfContactsExist()
        }
    }

    private func presentPickerIfContactsExist() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let hasPhoneContact = self.hasPhoneContact()
            DispatchQueue.main.async {
                guard self.viewIfLoaded?.window != nil else { return }
                if hasPhoneContact {
                    self.activityIndicator.stopAnimating()
                    self.presentPicker()
                } else {
                    self.configureError("No contacts with phone numbers were found.")
                }
            }
        }
    }

    private func hasPhoneContact() -> Bool {
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var found = false
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                if !contact.phoneNumbers.isEmpty {
                    found = true
                    stop.pointee = true
                }
            }
        } catch {
            return false
        }
        return found
    }

    private func presentPicker() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        present(picker, animated: true)
    }

    private func contactSnapshot(from contact: CNContact) -> MessageContact? {
        let displayName = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phones = contact.phoneNumbers.prefix(5).map { labeled in
            MessageContactPhone(
                label: labeled.label.map { CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0) },
                number: labeled.value.stringValue
            )
        }
        let snapshot = MessageContact(
            displayName: displayName?.isEmpty == false ? displayName ?? "" : fallbackName,
            phones: phones,
            organization: fallbackName
        )
        return snapshot.isValid ? snapshot : nil
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        activityIndicator.stopAnimating()
        chooseButton.isEnabled = true
        sendButton.isEnabled = selectedContact != nil
        if selectedContact == nil {
            detailLabel.text = "Choose a contact to preview before sending."
        }
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        guard let snapshot = contactSnapshot(from: contact) else {
            configureError("Choose a contact with a name and phone number.")
            return
        }
        configurePreview(snapshot)
    }

    @objc private func chooseTapped() {
        if chooseButton.title(for: .normal) == "Open Settings" {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
            return
        }
        startSelectionFlow()
    }

    @objc private func sendTapped() {
        guard let selectedContact, selectedContact.isValid else {
            configureError("Choose a contact with a name and phone number.")
            return
        }
        dismiss(animated: true) { [onSend] in
            onSend?(selectedContact)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
