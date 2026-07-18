import Foundation
import UIKit

final class AuthService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func requestOtp(phone: String) async throws -> RequestOtpResponse {
        try await apiClient.request(
            "/api/v1/auth/request-otp",
            method: .post,
            body: RequestOtpRequest(phone: phone),
            requiresAuth: false
        )
    }

    func verifyOtp(phone: String, otp: String, otpRequestId: String) async throws -> VerifyOtpResponse {
        try await apiClient.request(
            "/api/v1/auth/verify-otp",
            method: .post,
            body: VerifyOtpRequest(
                phone: phone,
                otp: otp,
                otpRequestId: otpRequestId,
                deviceInfo: makeDeviceInfo()
            ),
            requiresAuth: false
        )
    }

    func refresh(refreshToken: String) async throws -> RefreshTokenResponse {
        try await apiClient.request(
            "/api/v1/auth/refresh",
            method: .post,
            body: RefreshTokenRequest(refreshToken: refreshToken),
            requiresAuth: false
        )
    }

    func getMe() async throws -> User {
        try await apiClient.request("/api/v1/users/me", method: .get, requiresAuth: true)
    }

    func updateProfile(
        name: String,
        bio: String,
        avatarUrl: String?
    ) async throws -> User {
        try await apiClient.request(
            "/api/v1/users/me",
            method: .put,
            body: UpdateProfileRequest(name: name, avatarUrl: avatarUrl, bio: bio),
            requiresAuth: true
        )
    }

    func logout(sessionId: String?) async throws {
        let _: LogoutResponse = try await apiClient.request(
            "/api/v1/auth/logout",
            method: .post,
            body: LogoutRequest(sessionId: sessionId),
            requiresAuth: true
        )
    }

    func listSessions() async throws -> [ActiveSession] {
        let response: ActiveSessionsResponse = try await apiClient.request(
            "/api/v1/auth/sessions",
            method: .get,
            requiresAuth: true
        )
        return response.sessions
    }

    func revokeSession(sessionId: String) async throws -> RevokeSessionResponse {
        let encodedSessionID = sessionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionId
        return try await apiClient.request(
            "/api/v1/auth/sessions/\(encodedSessionID)",
            method: .delete,
            requiresAuth: true
        )
    }

    func logoutOtherSessions() async throws -> LogoutOthersResponse {
        try await apiClient.request(
            "/api/v1/auth/logout-others",
            method: .post,
            body: EmptyResponse(),
            requiresAuth: true
        )
    }

    private func makeDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let versionLabel = buildVersion.isEmpty ? appVersion : "\(appVersion) (\(buildVersion))"
        return DeviceInfo(
            deviceId: PushNotificationService.shared.installationID,
            deviceName: device.name,
            platform: "ios",
            osVersion: device.systemVersion,
            appVersion: versionLabel
        )
    }
}

