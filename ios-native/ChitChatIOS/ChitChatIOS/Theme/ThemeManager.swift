import UIKit

enum ChitChatThemeMode: String {
    case light
    case dark
}

extension Notification.Name {
    static let chitChatThemeDidChange = Notification.Name("chitchat.theme.didChange")
}

final class ThemeManager {
    private final class WeakWindow {
        weak var value: UIWindow?

        init(_ value: UIWindow) {
            self.value = value
        }
    }

    static let shared = ThemeManager()

    private let preferenceKey = "chitchat.theme.mode"
    private var managedWindows: [ObjectIdentifier: WeakWindow] = [:]
    private var isApplyingTheme = false
    private var pendingMode: ChitChatThemeMode?
    private(set) var mode: ChitChatThemeMode

    private init(defaults: UserDefaults = .standard) {
        mode = ChitChatThemeMode(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .light
    }

    var isDark: Bool { mode == .dark }

    var interfaceStyle: UIUserInterfaceStyle {
        isDark ? .dark : .light
    }

    // SceneDelegate registers only ChitChat's own application window. Theme
    // changes must never mutate keyboard, alert, or other UIKit-owned windows.
    func register(applicationWindow window: UIWindow) {
        runOnMain { [weak self, weak window] in
            guard let self, let window else { return }
            self.managedWindows[ObjectIdentifier(window)] = WeakWindow(window)
            self.applyTheme(to: window)
        }
    }

    // Retained for the scene bootstrap call-site while still registering the
    // window before applying the persisted appearance.
    func apply(to window: UIWindow) {
        register(applicationWindow: window)
    }

    func setMode(_ mode: ChitChatThemeMode) {
        runOnMain { [weak self] in
            self?.setModeOnMain(mode)
        }
    }

    func setDarkMode(_ isEnabled: Bool) {
        setMode(isEnabled ? .dark : .light)
    }

    func toggle() {
        setMode(isDark ? .light : .dark)
    }

    private func setModeOnMain(_ requestedMode: ChitChatThemeMode) {
        if isApplyingTheme {
            pendingMode = requestedMode
            return
        }

        guard mode != requestedMode else {
            applyToActiveApplicationWindows()
            return
        }

        isApplyingTheme = true
        mode = requestedMode
        UserDefaults.standard.set(requestedMode.rawValue, forKey: preferenceKey)

        applyToActiveApplicationWindows()
        NotificationCenter.default.post(name: .chitChatThemeDidChange, object: self)

        isApplyingTheme = false
        guard let pendingMode, pendingMode != mode else {
            self.pendingMode = nil
            return
        }

        self.pendingMode = nil
        DispatchQueue.main.async { [weak self] in
            self?.setModeOnMain(pendingMode)
        }
    }

    private func applyToActiveApplicationWindows() {
        pruneReleasedWindows()
        managedWindows.values
            .compactMap(\.value)
            .filter { isActiveApplicationWindow($0) }
            .forEach { applyTheme(to: $0) }
    }

    private func isActiveApplicationWindow(_ window: UIWindow) -> Bool {
        guard !window.isHidden, window.rootViewController != nil else { return false }
        guard let activationState = window.windowScene?.activationState else { return false }
        return activationState == .foregroundActive || activationState == .foregroundInactive
    }

    private func applyTheme(to window: UIWindow) {
        guard window.rootViewController != nil else { return }

        window.overrideUserInterfaceStyle = interfaceStyle
        window.backgroundColor = ChitChatColors.background
        window.tintColor = ChitChatColors.accent
        window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    private func pruneReleasedWindows() {
        managedWindows = managedWindows.filter { $0.value.value != nil }
    }

    private func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
