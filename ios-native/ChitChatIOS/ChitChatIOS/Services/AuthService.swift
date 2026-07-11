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

    private func makeDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return DeviceInfo(
            deviceId: device.identifierForVendor?.uuidString,
            deviceName: device.name,
            platform: "ios",
            appVersion: appVersion
        )
    }
}

