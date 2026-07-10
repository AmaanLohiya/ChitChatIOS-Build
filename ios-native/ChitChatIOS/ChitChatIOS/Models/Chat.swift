import Foundation

enum ChatType: String, Codable {
    case direct
    case group
}

struct ChatMemberUser: Codable, Equatable {
    let id: String
    let name: String
    let avatarUrl: String
    let bio: String
    let isOnline: Bool
    let lastSeenAt: String?
}

struct ChatParticipant: Codable, Equatable {
    let userId: String
    let role: String
    let joinedAt: String
    let leftAt: String?
    let mutedUntil: String?
    let isArchived: Bool
    let isPinned: Bool
    let deletedAt: String?
    let user: ChatMemberUser?
}

struct Chat: Codable, Equatable {
    let id: String
    let type: ChatType
    let name: String
    let avatarUrl: String
    let members: [ChatParticipant]
    let createdBy: String
    let lastMessageId: String?
    let lastMessagePreview: String
    let lastMessageAt: String?
    let isMuted: Bool
    let mutedUntil: String?
    let isPinned: Bool
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String

    func otherParticipant(viewerUserId: String) -> ChatParticipant? {
        guard type == .direct else { return nil }
        return members.first { $0.userId != viewerUserId && $0.leftAt == nil && $0.deletedAt == nil }
    }

    func displayName(viewerUserId: String) -> String {
        if type == .group {
            return name.isEmpty ? "Group chat" : name
        }
        let partner = otherParticipant(viewerUserId: viewerUserId)
        return partner?.user?.name.nonEmpty ?? name.nonEmpty ?? "Direct chat"
    }

    func displayAvatarURL(viewerUserId: String) -> String {
        if type == .group {
            return avatarUrl
        }
        return otherParticipant(viewerUserId: viewerUserId)?.user?.avatarUrl ?? avatarUrl
    }
}

struct CreateDirectChatRequest: Encodable {
    let type = ChatType.direct
    let participantIds: [String]
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
