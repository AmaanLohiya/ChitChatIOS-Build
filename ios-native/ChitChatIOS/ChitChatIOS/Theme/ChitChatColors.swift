import UIKit

enum ChitChatColors {
    private static func adaptive(dark: String, light: String) -> UIColor {
        UIColor { traits in
            UIColor.chitChatRaw(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    private static func adaptive(dark: String, light: String, alpha: CGFloat) -> UIColor {
        UIColor { traits in
            UIColor.chitChatRaw(hex: traits.userInterfaceStyle == .dark ? dark : light)
                .withAlphaComponent(alpha)
        }
    }

    private static func adaptive(
        dark: String,
        darkAlpha: CGFloat,
        light: String,
        lightAlpha: CGFloat
    ) -> UIColor {
        UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor.chitChatRaw(hex: isDark ? dark : light)
                .withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        }
    }

    static let background = adaptive(dark: "#071825", light: "#F3F6F8")
    static let authBackground = adaptive(dark: "#03131F", light: "#F3F6F8")
    static let backgroundAlt = adaptive(dark: "#0A1B27", light: "#EDF2F4")
    static let surface = adaptive(dark: "#102432", light: "#FFFFFF")
    static let surfaceAlt = adaptive(dark: "#0F2230", light: "#F8FBFC")
    static let surfaceRaised = adaptive(dark: "#132839", light: "#EDF2F4")
    static let header = adaptive(dark: "#0D2231", light: "#F8FBFC")
    static let inputBackground = adaptive(dark: "#0E1E2C", light: "#E8EEF1")
    static let inputBackgroundAlt = adaptive(dark: "#1A2D3C", light: "#E8EEF1")
    static let textPrimary = adaptive(dark: "#E8F0F4", light: "#17242E")
    static let textSecondary = adaptive(dark: "#D5E2EA", light: "#384A55")
    static let textMuted = adaptive(dark: "#8EA0AB", light: "#687A86")
    static let placeholder = adaptive(dark: "#4C5D6D", light: "#71838E")
    static let accent = adaptive(dark: "#4BC5A6", light: "#2BA889")
    static let accentStrong = adaptive(dark: "#35B596", light: "#228D73")
    static let textOnAccent = adaptive(dark: "#071825", light: "#FFFFFF")
    static let whatsappGreen = UIColor(hex: "#25D366")
    static let disabledGreen = adaptive(dark: "#285E56", light: "#ADDCCF")
    static let danger = adaptive(dark: "#F16458", light: "#D93025")
    static let settingsSliderRail = adaptive(dark: "#233B4C", light: "#D6E0E4")
    static let border = adaptive(dark: "#FFFFFF", darkAlpha: 0.08, light: "#D6E0E4", lightAlpha: 1)
    static let divider = adaptive(dark: "#FFFFFF", darkAlpha: 0.06, light: "#E1E8EB", lightAlpha: 1)
    static let pressedOverlay = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.06)
    static let welcomeGradientStart = UIColor(hex: "#67CA70")
    static let welcomeGradientMiddle = UIColor(hex: "#4DAE69")
    static let welcomeGradientEnd = UIColor(hex: "#3F9E8D")

    // React Native ChatsScreen palette.
    static let chatsScreen = background
    static let chatsHeader = header
    static let chatsSearch = inputBackgroundAlt
    static let chatsRow = adaptive(dark: "#0A1F2C", light: "#FFFFFF")
    static let chatsAvatarBackground = adaptive(dark: "#153041", light: "#DCE7EA")
    static let chatsPlaceholder = adaptive(dark: "#6F8393", light: "#71838E")
    static let chatsReadBlue = UIColor(hex: "#2E86FF")
    static let chatsDivider = divider
    static let tabActivePill = adaptive(dark: "#4BC5A6", light: "#2BA889", alpha: 0.16)

    // React Native ContactsScreen palette.
    static let contactsScreen = background
    static let contactsHeader = header
    static let contactsCard = surfaceAlt
    static let contactsRow = adaptive(dark: "#091B28", light: "#FFFFFF")
    static let contactsSearch = inputBackgroundAlt
    static let contactsBorder = divider
    static let contactsSectionBorder = adaptive(dark: "#FFFFFF", darkAlpha: 0.04, light: "#E1E8EB", lightAlpha: 1)
    static let contactsRowBorder = adaptive(dark: "#FFFFFF", darkAlpha: 0.025, light: "#E8EEF1", lightAlpha: 1)
    static let contactsPressed = pressedOverlay
    static let contactsMenuPressed = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.06)
    static let contactsInviteGlow = adaptive(dark: "#4BC5A6", light: "#2BA889", alpha: 0.35)
    static let contactsEmptyIcon = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.05)

    // React Native ChatDetailScreen palette.
    static let chatDetailScreen = adaptive(dark: "#071825", light: "#EFF4F6")
    static let chatDetailHeader = header
    static let chatDetailBorder = border
    static let chatDetailSent = adaptive(dark: "#2B6F5D", light: "#D8F1E7")
    static let chatDetailReceived = adaptive(dark: "#223341", light: "#FFFFFF")
    static let chatDetailInput = adaptive(dark: "#132839", light: "#E8EEF1")
    static let chatDetailPlaceholder = adaptive(dark: "#7D8D97", light: "#71838E")
    static let chatDetailWallpaperOverlay = adaptive(dark: "#020C13", light: "#FFFFFF", alpha: 0.18)
    static let chatDetailSentTime = adaptive(dark: "#DFF5EF", light: "#376755", alpha: 0.72)
    static let chatDetailReceivedTime = adaptive(dark: "#D6E3ED", light: "#5B6871", alpha: 0.78)
    static let chatDetailReadBlue = UIColor(hex: "#3B82F6")
    static let chatDetailStateBackground = adaptive(dark: "#0D2231", light: "#FAFBFD", alpha: 0.86)

    static func gradientLayer(colors: [UIColor]) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = colors.map(\.cgColor)
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }
}

extension UIColor {
    fileprivate static func chitChatRaw(hex: String) -> UIColor {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch normalized.count {
        case 3:
            red = (value >> 8) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
        default:
            red = value >> 16
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        }
        return UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    // Existing programmatic screens used these dark literals directly. Keeping
    // their equivalent colors dynamic avoids a partial light-mode migration.
    private static let chitChatLightEquivalents: [String: String] = [
        "071825": "F3F6F8", "03131F": "F3F6F8", "0A1B27": "EDF2F4",
        "0A1F2C": "FFFFFF", "091B28": "FFFFFF", "0B1F2C": "F8FBFC",
        "0D2231": "F8FBFC", "0E1E2C": "E8EEF1", "0F2230": "F8FBFC",
        "102432": "FFFFFF", "122C3A": "EDF2F4", "132839": "EDF2F4",
        "153041": "DCE7EA", "1A2D3C": "E8EEF1", "1A3140": "EDF2F4",
        "223341": "FFFFFF", "233B4C": "D6E0E4", "2B6F5D": "D8F1E7",
        "285E56": "ADDCCF", "35B596": "228D73", "4BC5A6": "2BA889",
        "4C5D6D": "71838E", "6F8393": "71838E", "7D8D97": "71838E",
        "8EA0AB": "687A86", "93A7B2": "687A86", "D5E2EA": "384A55",
        "E7EFF3": "17242E", "E8F0F4": "17242E"
    ]

    convenience init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        if let light = UIColor.chitChatLightEquivalents[normalized] {
            self.init { traits in
                UIColor.chitChatRaw(hex: traits.userInterfaceStyle == .dark ? normalized : light)
            }
        } else {
            self.init(cgColor: UIColor.chitChatRaw(hex: normalized).cgColor)
        }
    }
}
