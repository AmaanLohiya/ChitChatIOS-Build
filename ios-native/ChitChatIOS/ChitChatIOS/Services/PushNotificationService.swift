import UIKit
import UserNotifications

final class PushNotificationService {
    static let shared = PushNotificationService()

    private enum Key {
        static let installationID = "push.installation-id.v1"
        static let deviceToken = "push.apns-token.v1"
        static let preferences = "push.preferences.v1"
    }

    private let apiClient: APIClient
    private let defaults: UserDefaults

    private init(apiClient: APIClient = .shared, defaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.defaults = defaults
    }

    var installationID: String {
        if let existing = defaults.string(forKey: Key.installationID), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: Key.installationID)
        return created
    }

    func requestAuthorizationAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            guard granted else { return false }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            return true
        } catch {
            return false
        }
    }

    func registerIfAuthorized() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            if let token = defaults.string(forKey: Key.deviceToken), !token.isEmpty {
                await register(token: token)
            }
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else { return }
        defaults.set(token, forKey: Key.deviceToken)
        Task { await register(token: token) }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func loadPreferences() async -> PushPreferences {
        do {
            let preferences: PushPreferences = try await apiClient.request(
                "/api/v1/push-devices/preferences",
                queryItems: [URLQueryItem(name: "installationId", value: installationID)]
            )
            store(preferences)
            return preferences
        } catch {
            return storedPreferences()
        }
    }

    func updatePreferences(_ preferences: PushPreferences) async throws -> PushPreferences {
        do {
            let saved: PushPreferences = try await apiClient.request(
                "/api/v1/push-devices/\(installationID)/preferences",
                method: .patch,
                body: UpdatePushPreferencesRequest(
                    notificationsEnabled: preferences.notificationsEnabled,
                    messageNotificationsEnabled: preferences.messageNotificationsEnabled,
                    statusNotificationsEnabled: preferences.statusNotificationsEnabled,
                    previewEnabled: preferences.previewEnabled
                )
            )
            store(saved)
            return saved
        } catch APIClientError.server(let code, _) where code == "PUSH_INSTALLATION_NOT_FOUND" {
            store(preferences)
            return preferences
        }
    }

    func deactivateCurrentInstallation() async {
        do {
            let _: DeactivatePushDeviceResponse = try await apiClient.request(
                "/api/v1/push-devices/\(installationID)",
                method: .delete
            )
        } catch {
            // Local logout remains authoritative when the device is offline or the token expired.
        }
    }

    private func register(token: String) async {
        guard case .signedIn(_) = SessionManager.shared.state else { return }
        do {
            let registration: PushDeviceRegistration = try await apiClient.request(
                "/api/v1/push-devices/register",
                method: .post,
                body: RegisterPushDeviceRequest(
                    installationId: installationID,
                    platform: "ios",
                    provider: "apns",
                    token: token,
                    environment: Self.environment,
                    appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                    deviceName: UIDevice.current.model
                )
            )
            let preferences = storedPreferences()
            if registration.preferences != preferences {
                _ = try await updatePreferences(preferences)
            }
        } catch {
            #if DEBUG
            print("[push] APNs installation registration unavailable: \(error.localizedDescription)")
            #endif
        }
    }

    private func storedPreferences() -> PushPreferences {
        guard
            let data = defaults.data(forKey: Key.preferences),
            let preferences = try? JSONDecoder().decode(PushPreferences.self, from: data)
        else {
            return .defaults
        }
        return preferences
    }

    private func store(_ preferences: PushPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Key.preferences)
    }

    private static var environment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
