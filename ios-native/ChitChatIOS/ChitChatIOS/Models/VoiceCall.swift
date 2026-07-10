import Foundation

enum VoiceCallType: String, Codable {
    case voice
    case video
}

enum VoiceCallStatus: String, Codable {
    case ringing
    case active
    case ended
    case rejected
    case missed
    case cancelled
}

struct VoiceCall: Codable, Equatable {
    let callId: String
    let chatId: String
    let callerId: String
    let calleeId: String
    let type: VoiceCallType
    let status: VoiceCallStatus
    let startedAt: String
    let answeredAt: String?
    let endedAt: String?
    let lastActivityAt: String?
    let endReason: String?

    enum CodingKeys: String, CodingKey {
        case callId
        case chatId
        case callerId
        case calleeId
        case type
        case status
        case startedAt
        case answeredAt
        case endedAt
        case lastActivityAt
        case endReason
    }

    init(
        callId: String,
        chatId: String,
        callerId: String,
        calleeId: String,
        type: VoiceCallType,
        status: VoiceCallStatus,
        startedAt: String,
        answeredAt: String? = nil,
        endedAt: String? = nil,
        lastActivityAt: String? = nil,
        endReason: String? = nil
    ) {
        self.callId = callId
        self.chatId = chatId
        self.callerId = callerId
        self.calleeId = calleeId
        self.type = type
        self.status = status
        self.startedAt = startedAt
        self.answeredAt = answeredAt
        self.endedAt = endedAt
        self.lastActivityAt = lastActivityAt
        self.endReason = endReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        callId = try container.decode(String.self, forKey: .callId)
        chatId = try container.decode(String.self, forKey: .chatId)
        callerId = try container.decode(String.self, forKey: .callerId)
        calleeId = try container.decode(String.self, forKey: .calleeId)
        type = try container.decodeIfPresent(VoiceCallType.self, forKey: .type) ?? .voice
        status = try container.decodeIfPresent(VoiceCallStatus.self, forKey: .status) ?? .ringing
        startedAt = try container.decode(String.self, forKey: .startedAt)
        answeredAt = try container.decodeIfPresent(String.self, forKey: .answeredAt)
        endedAt = try container.decodeIfPresent(String.self, forKey: .endedAt)
        lastActivityAt = try container.decodeIfPresent(String.self, forKey: .lastActivityAt)
        endReason = try container.decodeIfPresent(String.self, forKey: .endReason)
    }
}

struct VoiceCallParticipant: Equatable {
    let id: String
    let name: String
    let avatarUrl: String

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "ChitChat user" : trimmed
    }
}

enum VoiceCallDirection: Equatable {
    case outgoing
    case incoming
}

enum VoiceCallPresentationStatus: Equatable {
    case outgoing
    case ringing
    case incoming
    case connecting
    case active
    case busy(String)
    case ended(String?)
    case failed(String)
}

struct VoiceCallPresentationState: Equatable {
    let direction: VoiceCallDirection
    let status: VoiceCallPresentationStatus
    let callId: String?
    let chatId: String
    let callerId: String
    let calleeId: String
    let participant: VoiceCallParticipant
    let startedAt: Date
    let connectedAt: Date?
    let isMuted: Bool
    let isSpeakerOn: Bool
}

struct SocketCallEvent {
    let call: VoiceCall
    let offer: [String: Any]?
    let answer: [String: Any]?
    let candidate: [String: Any]?
    let fromUserId: String?
    let reason: String?
}

struct SocketCallBusyEvent {
    let chatId: String
    let callerId: String
    let calleeId: String
    let busyUserId: String
    let reason: String
    let staleCleaned: Bool
    let activeCallId: String?
    let message: String?
}
