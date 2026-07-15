import UIKit
import UserNotifications

final class NotificationSettingsViewController: BaseViewController {
    private let service = PushNotificationService.shared
    private let permissionLabel = UILabel()
    private let allowSwitch = UISwitch()
    private let messagesSwitch = UISwitch()
    private let statusesSwitch = UISwitch()
    private let previewSwitch = UISwitch()
    private var preferences = PushPreferences.defaults
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = ChitChatColors.background
        navigationController?.setNavigationBarHidden(false, animated: false)
        buildUI()
        Task { @MainActor [weak self] in await self?.load() }
    }

    private func buildUI() {
        permissionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionLabel.textColor = ChitChatColors.textMuted
        permissionLabel.font = UIFont.systemFont(ofSize: 13)
        permissionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            permissionLabel,
            makeRow(
                symbol: "bell",
                title: "Allow notifications",
                detail: "Control remote delivery on this installation",
                toggle: allowSwitch,
                action: #selector(allowChanged)
            ),
            makeRow(
                symbol: "message",
                title: "Message notifications",
                detail: "Direct and group messages",
                toggle: messagesSwitch,
                action: #selector(messagesChanged)
            ),
            makeRow(
                symbol: "dot.radiowaves.left.and.right",
                title: "Status notifications",
                detail: "New updates from eligible contacts",
                toggle: statusesSwitch,
                action: #selector(statusesChanged)
            ),
            makeRow(
                symbol: "eye",
                title: "Show message preview",
                detail: "Display privacy-safe message content",
                toggle: previewSwitch,
                action: #selector(previewChanged)
            )
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func makeRow(
        symbol: String,
        title: String,
        detail: String,
        toggle: UISwitch,
        action: Selector
    ) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor(hex: "#102432")
        row.layer.cornerRadius = 18
        row.layer.borderWidth = 1
        row.layer.borderColor = ChitChatColors.border.cgColor
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        icon.contentMode = .center
        icon.backgroundColor = ChitChatColors.accent.withAlphaComponent(0.1)
        icon.layer.cornerRadius = 13

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.textColor = ChitChatColors.textMuted
        detailLabel.font = UIFont.systemFont(ofSize: 12)
        detailLabel.numberOfLines = 2
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.translatesAutoresizingMaskIntoConstraints = false
        text.axis = .vertical
        text.spacing = 2

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.onTintColor = ChitChatColors.accent
        toggle.addTarget(self, action: action, for: .valueChanged)

        row.addSubview(icon)
        row.addSubview(text)
        row.addSubview(toggle)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 15),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            text.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func load() async {
        preferences = await service.loadPreferences()
        let status = await service.authorizationStatus()
        permissionLabel.text = Self.permissionText(status)
        applyPreferences()
    }

    private func applyPreferences() {
        allowSwitch.setOn(preferences.notificationsEnabled, animated: false)
        messagesSwitch.setOn(preferences.messageNotificationsEnabled, animated: false)
        statusesSwitch.setOn(preferences.statusNotificationsEnabled, animated: false)
        previewSwitch.setOn(preferences.previewEnabled, animated: false)
        let nestedEnabled = preferences.notificationsEnabled && !isSaving
        messagesSwitch.isEnabled = nestedEnabled
        statusesSwitch.isEnabled = nestedEnabled
        previewSwitch.isEnabled = nestedEnabled
        allowSwitch.isEnabled = !isSaving
    }

    @objc private func allowChanged() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.allowSwitch.isOn {
                let granted = await self.service.requestAuthorizationAndRegister()
                let status = await self.service.authorizationStatus()
                self.permissionLabel.text = Self.permissionText(status)
                guard granted else {
                    self.allowSwitch.setOn(false, animated: true)
                    self.preferences.notificationsEnabled = false
                    await self.save()
                    self.showPermissionAlert()
                    return
                }
            }
            self.preferences.notificationsEnabled = self.allowSwitch.isOn
            await self.save()
        }
    }

    @objc private func messagesChanged() {
        preferences.messageNotificationsEnabled = messagesSwitch.isOn
        Task { @MainActor [weak self] in await self?.save() }
    }

    @objc private func statusesChanged() {
        preferences.statusNotificationsEnabled = statusesSwitch.isOn
        Task { @MainActor [weak self] in await self?.save() }
    }

    @objc private func previewChanged() {
        preferences.previewEnabled = previewSwitch.isOn
        Task { @MainActor [weak self] in await self?.save() }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        applyPreferences()
        do {
            preferences = try await service.updatePreferences(preferences)
        } catch {
            showAlert(message: error.localizedDescription)
            preferences = await service.loadPreferences()
        }
        isSaving = false
        applyPreferences()
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Notifications are blocked",
            message: "Allow notifications in Settings to receive messages and status updates.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    private static func permissionText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Permission enabled on this device"
        case .denied:
            return "iOS notification permission is blocked"
        case .notDetermined:
            return "Permission has not been requested"
        @unknown default:
            return "Notification permission status is unavailable"
        }
    }
}
