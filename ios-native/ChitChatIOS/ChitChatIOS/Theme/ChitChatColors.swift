import UIKit

enum ChitChatColors {
    static let background = UIColor(hex: "#071825")
    static let authBackground = UIColor(hex: "#03131F")
    static let backgroundAlt = UIColor(hex: "#0A1B27")
    static let surface = UIColor(hex: "#102432")
    static let surfaceAlt = UIColor(hex: "#0F2230")
    static let surfaceRaised = UIColor(hex: "#132839")
    static let header = UIColor(hex: "#0D2231")
    static let inputBackground = UIColor(hex: "#0E1E2C")
    static let inputBackgroundAlt = UIColor(hex: "#1A2D3C")
    static let textPrimary = UIColor(hex: "#E8F0F4")
    static let textSecondary = UIColor(hex: "#D5E2EA")
    static let textMuted = UIColor(hex: "#8EA0AB")
    static let placeholder = UIColor(hex: "#4C5D6D")
    static let accent = UIColor(hex: "#4BC5A6")
    static let accentStrong = UIColor(hex: "#35B596")
    static let whatsappGreen = UIColor(hex: "#25D366")
    static let disabledGreen = UIColor(hex: "#285E56")
    static let danger = UIColor(hex: "#F16458")
    static let border = UIColor.white.withAlphaComponent(0.08)
    static let divider = UIColor.white.withAlphaComponent(0.05)
    static let pressedOverlay = UIColor.white.withAlphaComponent(0.06)
    static let welcomeGradientStart = UIColor(hex: "#67CA70")
    static let welcomeGradientMiddle = UIColor(hex: "#4DAE69")
    static let welcomeGradientEnd = UIColor(hex: "#3F9E8D")

    // React Native ChatsScreen dark palette.
    static let chatsScreen = UIColor(hex: "#071825")
    static let chatsHeader = UIColor(hex: "#0D2231")
    static let chatsSearch = UIColor(hex: "#1A2D3C")
    static let chatsRow = UIColor(hex: "#0A1F2C")
    static let chatsAvatarBackground = UIColor(hex: "#153041")
    static let chatsPlaceholder = UIColor(hex: "#6F8393")
    static let chatsReadBlue = UIColor(hex: "#2E86FF")
    static let chatsDivider = UIColor.white.withAlphaComponent(0.05)
    static let tabActivePill = UIColor(hex: "#4BC5A6").withAlphaComponent(0.16)

    // React Native ContactsScreen dark palette.
    static let contactsScreen = UIColor(hex: "#071825")
    static let contactsHeader = UIColor(hex: "#0D2231")
    static let contactsCard = UIColor(hex: "#0F2230")
    static let contactsRow = UIColor(hex: "#091B28")
    static let contactsSearch = UIColor(hex: "#1A2D3C")
    static let contactsBorder = UIColor.white.withAlphaComponent(0.05)
    static let contactsSectionBorder = UIColor.white.withAlphaComponent(0.04)
    static let contactsRowBorder = UIColor.white.withAlphaComponent(0.025)
    static let contactsPressed = UIColor.white.withAlphaComponent(0.04)
    static let contactsMenuPressed = UIColor.white.withAlphaComponent(0.06)
    static let contactsInviteGlow = UIColor(hex: "#4BC5A6").withAlphaComponent(0.35)
    static let contactsEmptyIcon = UIColor.white.withAlphaComponent(0.05)

    // React Native ChatDetailScreen palette.
    static let chatDetailScreen = UIColor(hex: "#071825")
    static let chatDetailHeader = UIColor(hex: "#0D2231")
    static let chatDetailBorder = UIColor.white.withAlphaComponent(0.07)
    static let chatDetailSent = UIColor(hex: "#2B6F5D")
    static let chatDetailReceived = UIColor(hex: "#223341")
    static let chatDetailInput = UIColor(hex: "#132839")
    static let chatDetailPlaceholder = UIColor(hex: "#7D8D97")
    static let chatDetailWallpaperOverlay = UIColor(
        red: 2 / 255,
        green: 12 / 255,
        blue: 19 / 255,
        alpha: 0.18
    )
    static let chatDetailSentTime = UIColor(
        red: 223 / 255,
        green: 245 / 255,
        blue: 239 / 255,
        alpha: 0.65
    )
    static let chatDetailReceivedTime = UIColor(
        red: 214 / 255,
        green: 227 / 255,
        blue: 237 / 255,
        alpha: 0.62
    )
    static let chatDetailReadBlue = UIColor(hex: "#3B82F6")
    static let chatDetailStateBackground = UIColor(hex: "#0D2231").withAlphaComponent(0.72)

    static func gradientLayer(colors: [UIColor]) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = colors.map(\.cgColor)
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch hex.count {
        case 3:
            red = (int >> 8) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
        default:
            red = int >> 16
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        }
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

