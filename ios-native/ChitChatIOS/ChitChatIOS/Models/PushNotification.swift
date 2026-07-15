import Foundation

struct PushPreferences: Codable, Equatable {
    var notificationsEnabled: Bool
    var messageNotificationsEnabled: Bool
    var statusNotificationsEnabled: Bool
    var previewEnabled: Bool

    static let defaults = PushPreferences(
        notificationsEnabled: true,
        messageNotificationsEnabled: true,
        statusNotificationsEnabled: true,
        previewEnabled: true
    )
}

struct RegisterPushDeviceRequest: Encodable {
    let installationId: String
    let platform: String
    let provider: String
    let token: String
    let environment: String
    let appVersion: String
    let deviceName: String
}

struct PushDeviceRegistration: Decodable {
    let installationId: String
    let platform: String
    let provider: String
    let environment: String
    let appVersion: String
    let deviceName: String
    let preferences: PushPreferences
    let lastRegisteredAt: String
    let invalidatedAt: String?
}

struct DeactivatePushDeviceResponse: Decodable {
    let installationId: String
    let deactivated: Bool
}

struct UpdatePushPreferencesRequest: Encodable {
    let notificationsEnabled: Bool?
    let messageNotificationsEnabled: Bool?
    let statusNotificationsEnabled: Bool?
    let previewEnabled: Bool?
}

enum RemoteNotificationRoute: Equatable {
    case message(chatID: String, messageID: String?)
    case status(ownerID: String, statusID: String)

    init?(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return nil }
        switch type {
        case "message":
            guard let chatID = (userInfo["chatId"] as? String)?.trimmedNonEmpty else { return nil }
            self = .message(chatID: chatID, messageID: userInfo["messageId"] as? String)
        case "status":
            guard
                let ownerID = (userInfo["ownerId"] as? String)?.trimmedNonEmpty,
                let statusID = (userInfo["statusId"] as? String)?.trimmedNonEmpty
            else { return nil }
            self = .status(ownerID: ownerID, statusID: statusID)
        default:
            return nil
        }
    }

    var deduplicationKey: String {
        switch self {
        case .message(let chatID, let messageID):
            return "message:\(chatID):\(messageID ?? "")"
        case .status(let ownerID, let statusID):
            return "status:\(ownerID):\(statusID)"
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
