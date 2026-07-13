import Foundation

enum CallHistoryStatus: String, Codable {
    case ringing
    case answered
    case completed
    case missed
    case rejected
    case cancelled
    case failed
}

enum CallHistoryDirection: String, Codable {
    case incoming
    case outgoing
}

struct CallHistoryParticipant: Codable, Equatable {
    let id: String
    let name: String
    let avatarUrl: String

    var displayName: String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "ChitChat user" : value
    }
}

struct CallHistoryItem: Codable, Equatable {
    let id: String
    let callId: String
    let chatId: String
    let direction: CallHistoryDirection
    let status: CallHistoryStatus
    let type: VoiceCallType
    let otherParticipant: CallHistoryParticipant
    let initiatedAt: String
    let answeredAt: String?
    let endedAt: String?
    let durationSeconds: Int
    let createdAt: String
    let updatedAt: String
}
