import UIKit

private final class ChitChatTabBar: UITabBar {
    private let activeIndicator = UIView()
    private let chatsBadge = UIView()
    private let chatsBadgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        activeIndicator.backgroundColor = ChitChatColors.tabActivePill
        activeIndicator.layer.cornerRadius = 18
        activeIndicator.isUserInteractionEnabled = false
        addSubview(activeIndicator)

        chatsBadge.backgroundColor = ChitChatColors.accent
        chatsBadge.layer.cornerRadius = 11
        chatsBadge.isUserInteractionEnabled = false

        chatsBadgeLabel.frame = CGRect(x: 0, y: 0, width: 21, height: 21)
        chatsBadgeLabel.text = "3"
        chatsBadgeLabel.textColor = ChitChatColors.backgroundAlt
        chatsBadgeLabel.font = ChitChatTypography.chatsUnread
        chatsBadgeLabel.textAlignment = .center
        chatsBadge.addSubview(chatsBadgeLabel)
        addSubview(chatsBadge)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var result = super.sizeThatFits(size)
        result.height = ChitChatSpacing.tabContentHeight + safeAreaInsets.bottom
        return result
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let tabButtons = subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }

        guard
            let selectedItem,
            let selectedIndex = items?.firstIndex(of: selectedItem),
            tabButtons.indices.contains(selectedIndex)
        else {
            activeIndicator.isHidden = true
            return
        }

        let selectedFrame = tabButtons[selectedIndex].frame
        let indicatorWidth = max(56, min(104, selectedFrame.width - 10))
        activeIndicator.frame = CGRect(
            x: selectedFrame.midX - indicatorWidth / 2,
            y: 9,
            width: indicatorWidth,
            height: 49
        )
        chatsBadge.frame = CGRect(
            x: tabButtons[0].frame.midX + 17,
            y: 8,
            width: 21,
            height: 21
        )
        activeIndicator.isHidden = false
        insertSubview(activeIndicator, belowSubview: tabButtons[0])
        bringSubviewToFront(chatsBadge)
    }
}

final class MainTabBarController: UITabBarController {
    private let user: User

    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
        setValue(ChitChatTabBar(), forKey: "tabBar")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.background
        VoiceCallService.shared.configure(currentUser: user)
        configureTabBar()

        let chats = ChatsViewController(currentUser: user)
        let chatIcon = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let selectedChatIcon = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        chats.tabBarItem = UITabBarItem(
            title: "Chats",
            image: UIImage(systemName: "message", withConfiguration: chatIcon),
            selectedImage: UIImage(systemName: "message.fill", withConfiguration: selectedChatIcon)
        )
        let contacts = ContactsViewController(currentUser: user)
        contacts.tabBarItem = UITabBarItem(
            title: "Contacts",
            image: tabImage("person.2", selected: false),
            selectedImage: tabImage("person.2", selected: true)
        )

        let updates = UpdatesViewController(currentUser: user)
        updates.tabBarItem = UITabBarItem(
            title: "Updates",
            image: tabImage("dot.radiowaves.left.and.right", selected: false),
            selectedImage: tabImage("dot.radiowaves.left.and.right", selected: true)
        )

        let calls = CallsViewController()
        calls.tabBarItem = UITabBarItem(
            title: "Calls",
            image: tabImage("phone", selected: false),
            selectedImage: tabImage("phone", selected: true)
        )

        let settings = SettingsViewController(user: user)
        settings.tabBarItem = UITabBarItem(
            title: "Settings",
            image: tabImage("gearshape", selected: false),
            selectedImage: tabImage("gearshape", selected: true)
        )

        viewControllers = [
            makeNavigationController(root: chats),
            makeNavigationController(root: contacts),
            makeNavigationController(root: updates),
            makeNavigationController(root: calls),
            makeNavigationController(root: settings)
        ]
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ChitChatColors.backgroundAlt
        appearance.shadowColor = ChitChatColors.border

        let itemAppearance = appearance.stackedLayoutAppearance
        itemAppearance.normal.iconColor = ChitChatColors.textMuted
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: ChitChatColors.textMuted,
            .font: ChitChatTypography.tabLabel,
            .kern: -0.1
        ]
        itemAppearance.selected.iconColor = ChitChatColors.accent
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: ChitChatColors.accent,
            .font: ChitChatTypography.tabLabelSelected,
            .kern: -0.1
        ]
        itemAppearance.normal.badgeBackgroundColor = ChitChatColors.accent
        itemAppearance.normal.badgeTextAttributes = [
            .foregroundColor: ChitChatColors.backgroundAlt,
            .font: ChitChatTypography.chatsUnread
        ]
        itemAppearance.selected.badgeBackgroundColor = ChitChatColors.accent
        itemAppearance.selected.badgeTextAttributes = [
            .foregroundColor: ChitChatColors.backgroundAlt,
            .font: ChitChatTypography.chatsUnread
        ]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = ChitChatColors.accent
        tabBar.unselectedItemTintColor = ChitChatColors.textMuted
    }

    private func tabImage(_ symbol: String, selected: Bool) -> UIImage? {
        UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 22,
                weight: selected ? .semibold : .regular
            )
        )
    }

    private func makeNavigationController(root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ChitChatColors.header
        appearance.shadowColor = ChitChatColors.border
        appearance.titleTextAttributes = [
            .foregroundColor: ChitChatColors.textPrimary,
            .font: ChitChatTypography.headerTitle
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: ChitChatColors.textPrimary,
            .font: ChitChatTypography.largeTitle
        ]

        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.tintColor = ChitChatColors.accent
        navigation.navigationBar.prefersLargeTitles = false
        navigation.view.backgroundColor = ChitChatColors.background
        return navigation
    }
}
