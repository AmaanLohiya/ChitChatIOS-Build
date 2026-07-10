import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let sessionManager = SessionManager.shared

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.view.backgroundColor = ChitChatColors.authBackground

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.backgroundColor = ChitChatColors.authBackground
        window.tintColor = ChitChatColors.accent
        self.window = window
        window.makeKeyAndVisible()

        sessionManager.onStateChange = { [weak navigationController] state in
            DispatchQueue.main.async {
                guard let navigationController else { return }
                switch state {
                case .restoring:
                    navigationController.setViewControllers([SplashViewController()], animated: false)
                case .signedOut:
                    navigationController.setViewControllers([WelcomeViewController()], animated: true)
                case .signedIn(let user):
                    navigationController.setViewControllers([MainTabBarController(user: user)], animated: true)
                }
            }
        }

        navigationController.setViewControllers([SplashViewController()], animated: false)
        Task { await sessionManager.restoreSession() }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        SocketService.shared.reconnectUsingLatestToken()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SocketService.shared.suspend()
    }
}

