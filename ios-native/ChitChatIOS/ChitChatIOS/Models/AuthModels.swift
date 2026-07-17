import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let meta: APIResponseMeta?
    let error: APIErrorPayload?
}

struct APIResponseMeta: Decodable {
    let nextCursor: String?
    let hasMore: Bool?
    let limit: Int?
}

struct PaginatedResponse<Value> {
    let values: Value
    let nextCursor: String?
    let hasMore: Bool
    let limit: Int?
}

struct APIErrorPayload: Decodable, Error {
    let code: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }
}

struct RequestOtpRequest: Encodable {
    let phone: String
}

enum OtpDeliveryMode: String, Codable {
    case demo
    case sms
}

struct RequestOtpResponse: Codable {
    let otpRequestId: String
    let expiresAt: String
    let resendAvailableAt: String
    let deliveryMode: OtpDeliveryMode
    let otp: String?
}

struct DeviceInfo: Codable {
    let deviceId: String?
    let deviceName: String?
    let platform: String?
    let appVersion: String?
}

struct VerifyOtpRequest: Encodable {
    let phone: String
    let otp: String
    let otpRequestId: String
    let deviceInfo: DeviceInfo?
}

struct VerifyOtpResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
    let sessionId: String
    let isProfileComplete: Bool
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
}

struct UpdateProfileRequest: Encodable {
    let name: String?
    let avatarUrl: String?
    let bio: String?
}

struct LogoutRequest: Encodable {
    let sessionId: String?
}

struct LogoutResponse: Decodable {
    let revokedSessionId: String
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let sessionId: String
    let currentUser: User
}

struct EmptyResponse: Codable {}

struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}



