import UIKit

enum ChitChatTypography {
    private static func scaled(_ size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(
            for: UIFont.systemFont(ofSize: size, weight: weight),
            maximumPointSize: size * 1.25
        )
    }

    static let welcomeTitle = scaled(27, weight: .bold, style: .title1)
    static let headerTitle = UIFont.systemFont(ofSize: 17, weight: .bold)
    static let body = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let bodyMedium = UIFont.systemFont(ofSize: 15, weight: .medium)
    static let bodySemibold = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let title = scaled(22, weight: .bold, style: .title2)
    static let largeTitle = scaled(25, weight: .bold, style: .title1)
    static let button = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let caption = UIFont.systemFont(ofSize: 12, weight: .medium)
    static let smallCaption = UIFont.systemFont(ofSize: 11, weight: .semibold)
    static let otp = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)

    // React Native ChatsScreen uses fixed, non-scaling list typography.
    static let chatsHeaderTitle = UIFont.systemFont(ofSize: 22, weight: .bold)
    static let chatsSearch = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let chatsName = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let chatsPreview = UIFont.systemFont(ofSize: 13, weight: .medium)
    static let chatsTime = UIFont.systemFont(ofSize: 10.5, weight: .medium)
    static let chatsUnread = UIFont.systemFont(ofSize: 12, weight: .bold)
    static let chatsEmptyTitle = UIFont.systemFont(ofSize: 15, weight: .bold)
    static let chatsEmptyText = UIFont.systemFont(ofSize: 13, weight: .regular)
    static let chatsError = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let tabLabel = UIFont.systemFont(ofSize: 32 / 3, weight: .regular)
    static let tabLabelSelected = UIFont.systemFont(ofSize: 32 / 3, weight: .semibold)

    // React Native ContactsScreen fixed list typography.
    static let contactsHeaderTitle = UIFont.systemFont(ofSize: 22, weight: .bold)
    static let contactsSearch = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let contactsMenu = UIFont.systemFont(ofSize: 13, weight: .medium)
    static let contactsInviteTitle = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let contactsInviteSubtitle = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let contactsSection = UIFont.systemFont(ofSize: 13, weight: .bold)
    static let contactsName = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let contactsStatus = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let contactsEmptyTitle = UIFont.systemFont(ofSize: 15, weight: .bold)
    static let contactsEmptyText = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let contactsError = UIFont.systemFont(ofSize: 12, weight: .regular)

    // React Native ChatDetailScreen fixed typography.
    static let chatDetailName = UIFont.systemFont(ofSize: 15, weight: .bold)
    static let chatDetailStatus = UIFont.systemFont(ofSize: 11, weight: .regular)
    static let chatDetailMessage = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let chatDetailTime = UIFont.systemFont(ofSize: 10, weight: .regular)
    static let chatDetailInput = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let chatDetailStateTitle = UIFont.systemFont(ofSize: 15, weight: .bold)
    static let chatDetailStateText = UIFont.systemFont(ofSize: 12, weight: .medium)
}

