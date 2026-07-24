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

    static let background = adaptive(dark: "#071825", light: "#F0F2F5")
    static let authBackground = adaptive(dark: "#03131F", light: "#F0F2F5")
    static let backgroundAlt = adaptive(dark: "#0A1B27", light: "#ECEFF3")
    static let surface = adaptive(dark: "#102432", light: "#FFFFFF")
    static let surfaceAlt = adaptive(dark: "#0F2230", light: "#F7F8FA")
    static let surfaceRaised = adaptive(dark: "#132839", light: "#EAF0F4")
    static let header = adaptive(dark: "#0D2231", light: "#FAFBFD")
    static let inputBackground = adaptive(dark: "#0E1E2C", light: "#E1E6EC")
    static let inputBackgroundAlt = adaptive(dark: "#1A2D3C", light: "#E1E6EC")
    static let textPrimary = adaptive(dark: "#E8F0F4", light: "#131B20")
    static let textSecondary = adaptive(dark: "#D5E2EA", light: "#2B3740")
    static let textMuted = adaptive(dark: "#8EA0AB", light: "#697680")
    static let placeholder = adaptive(dark: "#4C5D6D", light: "#7B8792")
    static let accent = adaptive(dark: "#4BC5A6", light: "#2BA889")
    static let accentStrong = adaptive(dark: "#35B596", light: "#228D73")
    static let textOnAccent = adaptive(dark: "#071825", light: "#FFFFFF")
    static let whatsappGreen = UIColor(hex: "#25D366")
    static let disabledGreen = adaptive(dark: "#285E56", light: "#A8D9C9")
    static let danger = adaptive(dark: "#F16458", light: "#D93025")
    static let border = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.08)
    static let divider = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.06)
    static let pressedOverlay = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.06)
    static let welcomeGradientStart = UIColor(hex: "#67CA70")
    static let welcomeGradientMiddle = UIColor(hex: "#4DAE69")
    static let welcomeGradientEnd = UIColor(hex: "#3F9E8D")

    // React Native ChatsScreen palette.
    static let chatsScreen = background
    static let chatsHeader = header
    static let chatsSearch = inputBackgroundAlt
    static let chatsRow = adaptive(dark: "#0A1F2C", light: "#FFFFFF")
    static let chatsAvatarBackground = adaptive(dark: "#153041", light: "#DDE6EB")
    static let chatsPlaceholder = adaptive(dark: "#6F8393", light: "#7B8792")
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
    static let contactsSectionBorder = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.04)
    static let contactsRowBorder = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.025)
    static let contactsPressed = pressedOverlay
    static let contactsMenuPressed = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.06)
    static let contactsInviteGlow = adaptive(dark: "#4BC5A6", light: "#2BA889", alpha: 0.35)
    static let contactsEmptyIcon = adaptive(dark: "#FFFFFF", light: "#14222E", alpha: 0.05)

    // React Native ChatDetailScreen palette.
    static let chatDetailScreen = background
    static let chatDetailHeader = header
    static let chatDetailBorder = border
    static let chatDetailSent = adaptive(dark: "#2B6F5D", light: "#D9F3E8")
    static let chatDetailReceived = adaptive(dark: "#223341", light: "#FFFFFF")
    static let chatDetailInput = surfaceRaised
    static let chatDetailPlaceholder = adaptive(dark: "#7D8D97", light: "#7B8792")
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
        "071825": "F0F2F5", "03131F": "F0F2F5", "0A1B27": "ECEFF3",
        "0A1F2C": "FFFFFF", "091B28": "FFFFFF", "0B1F2C": "F7F8FA",
        "0D2231": "FAFBFD", "0E1E2C": "E1E6EC", "0F2230": "F7F8FA",
        "102432": "FFFFFF", "122C3A": "EAF0F4", "132839": "EAF0F4",
        "153041": "DDE6EB", "1A2D3C": "E1E6EC", "1A3140": "EAF0F4",
        "223341": "FFFFFF", "233B4C": "D3DAE1", "2B6F5D": "D9F3E8",
        "285E56": "A8D9C9", "35B596": "228D73", "4BC5A6": "2BA889",
        "4C5D6D": "7B8792", "6F8393": "7B8792", "7D8D97": "7B8792",
        "8EA0AB": "697680", "93A7B2": "697680", "D5E2EA": "2B3740",
        "E7EFF3": "131B20", "E8F0F4": "131B20"
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
