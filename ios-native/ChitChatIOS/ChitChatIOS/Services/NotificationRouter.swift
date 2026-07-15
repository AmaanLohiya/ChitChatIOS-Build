import UIKit

@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    private enum Key {
        static let lastResponseID = "push.last-response-id.v1"
    }

    private var pendingRoute: RemoteNotificationRoute?
    private var routeInFlight = false
    private var lastRouteKey = ""
    private var lastRouteDate = Date.distantPast

    private init() {}

    func handle(userInfo: [AnyHashable: Any], responseIdentifier: String?) {
        guard let route = RemoteNotificationRoute(userInfo: userInfo) else { return }
        if let responseIdentifier, !responseIdentifier.isEmpty {
            let previous = UserDefaults.standard.string(forKey: Key.lastResponseID)
            if previous == responseIdentifier { return }
            UserDefaults.standard.set(responseIdentifier, forKey: Key.lastResponseID)
        }
        pendingRoute = route
        flushIfReady()
    }

    func flushIfReady() {
        guard
            !routeInFlight,
            let route = pendingRoute,
            case .signedIn(let user) = SessionManager.shared.state,
            mainTabController() != nil
        else { return }

        let now = Date()
        if route.deduplicationKey == lastRouteKey, now.timeIntervalSince(lastRouteDate) < 2 {
            pendingRoute = nil
            return
        }

        pendingRoute = nil
        routeInFlight = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.routeInFlight = false }
            await self.route(route, user: user)
        }
    }

    func isExactChatVisible(chatID: String) -> Bool {
        guard
            let tabs = mainTabController(),
            let navigation = tabs.selectedViewController as? UINavigationController,
            let detail = navigation.topViewController as? ChatDetailViewController
        else { return false }
        return detail.notificationChatID == chatID
    }

    private func route(_ route: RemoteNotificationRoute, user: User) async {
        switch route {
        case .message(let chatID, _):
            do {
                let chat = try await ChatService().getChat(id: chatID)
                guard let tabs = mainTabController(),
                      let navigation = tabs.viewControllers?[safe: 0] as? UINavigationController else {
                    pendingRoute = route
                    return
                }
                tabs.selectedIndex = 0
                if let existing = navigation.topViewController as? ChatDetailViewController,
                   existing.notificationChatID == chatID {
                    return
                }
                navigation.pushViewController(
                    ChatDetailViewController(chat: chat, currentUser: user),
                    animated: true
                )
                remember(route)
            } catch {
                showUnavailable(message: "This chat is no longer available.", tabIndex: 0)
            }

        case .status(let ownerID, let statusID):
            do {
                let groups = try await StatusService().feed()
                guard groups.contains(where: { group in
                    group.owner.id == ownerID && group.statuses.contains(where: { $0.id == statusID })
                }) else {
                    showUnavailable(message: "This status is no longer available.", tabIndex: 2)
                    return
                }
                guard let tabs = mainTabController(),
                      let navigation = tabs.viewControllers?[safe: 2] as? UINavigationController else {
                    pendingRoute = route
                    return
                }
                tabs.selectedIndex = 2
                navigation.present(
                    StatusViewerViewController(
                        ownerID: ownerID,
                        ownerStatusesOnly: false,
                        initialStatusID: statusID
                    ),
                    animated: true
                )
                remember(route)
            } catch {
                showUnavailable(message: "This status is no longer available.", tabIndex: 2)
            }
        }
    }

    private func remember(_ route: RemoteNotificationRoute) {
        lastRouteKey = route.deduplicationKey
        lastRouteDate = Date()
    }

    private func showUnavailable(message: String, tabIndex: Int) {
        guard let tabs = mainTabController() else { return }
        tabs.selectedIndex = tabIndex
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topViewController(from: tabs)?.present(alert, animated: true)
    }

    private func mainTabController() -> MainTabBarController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        if let tabs = root as? MainTabBarController { return tabs }
        if let navigation = root as? UINavigationController {
            return navigation.viewControllers.compactMap { $0 as? MainTabBarController }.last
        }
        return nil
    }

    private func topViewController(from root: UIViewController) -> UIViewController? {
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            if let top = navigation.topViewController {
                return topViewController(from: top)
            }
            return navigation
        }
        if let tabs = root as? UITabBarController, let selected = tabs.selectedViewController {
            return topViewController(from: selected)
        }
        return root
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
