import UIKit

enum ChitChatThemeMode: String {
    case light
    case dark
}

extension Notification.Name {
    static let chitChatThemeDidChange = Notification.Name("chitchat.theme.didChange")
}

final class ThemeManager {
    static let shared = ThemeManager()

    private let preferenceKey = "chitchat.theme.mode"
    private(set) var mode: ChitChatThemeMode

    private init(defaults: UserDefaults = .standard) {
        mode = ChitChatThemeMode(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .light
    }

    var isDark: Bool { mode == .dark }

    var interfaceStyle: UIUserInterfaceStyle {
        isDark ? .dark : .light
    }

    func setMode(_ mode: ChitChatThemeMode) {
        guard self.mode != mode else {
            applyToConnectedWindows()
            return
        }

        self.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: preferenceKey)
        applyToConnectedWindows()
        NotificationCenter.default.post(name: .chitChatThemeDidChange, object: self)
    }

    func setDarkMode(_ isEnabled: Bool) {
        setMode(isEnabled ? .dark : .light)
    }

    func toggle() {
        setMode(isDark ? .light : .dark)
    }

    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = interfaceStyle
        window.backgroundColor = ChitChatColors.background
        window.tintColor = ChitChatColors.accent
        window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }

    private func applyToConnectedWindows() {
        let apply = { [weak self] in
            guard let self else { return }
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { self.apply(to: $0) }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
