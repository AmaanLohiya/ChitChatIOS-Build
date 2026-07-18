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

    func updatingPresence(isOnline: Bool, lastSeenAt: String?) -> ChatMemberUser {
        ChatMemberUser(
            id: id,
            name: name,
            avatarUrl: avatarUrl,
            bio: bio,
            isOnline: isOnline,
            lastSeenAt: lastSeenAt ?? self.lastSeenAt
        )
    }
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

    func updatingPresence(userId: String, isOnline: Bool, lastSeenAt: String?) -> ChatParticipant {
        guard self.userId.normalizedID == userId.normalizedID, let user else { return self }
        return ChatParticipant(
            userId: self.userId,
            role: role,
            joinedAt: joinedAt,
            leftAt: leftAt,
            mutedUntil: mutedUntil,
            isArchived: isArchived,
            isPinned: isPinned,
            deletedAt: deletedAt,
            user: user.updatingPresence(isOnline: isOnline, lastSeenAt: lastSeenAt)
        )
    }
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
    let unreadCount: Int
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

    func updatingPresence(userId: String, isOnline: Bool, lastSeenAt: String?) -> Chat {
        let updatedMembers = members.map {
            $0.updatingPresence(userId: userId, isOnline: isOnline, lastSeenAt: lastSeenAt)
        }
        guard updatedMembers != members else { return self }
        return Chat(
            id: id,
            type: type,
            name: name,
            avatarUrl: avatarUrl,
            members: updatedMembers,
            createdBy: createdBy,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            isMuted: isMuted,
            mutedUntil: mutedUntil,
            isPinned: isPinned,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func updatingUnreadCount(_ unreadCount: Int) -> Chat {
        Chat(
            id: id,
            type: type,
            name: name,
            avatarUrl: avatarUrl,
            members: members,
            createdBy: createdBy,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            unreadCount: max(0, unreadCount),
            isMuted: isMuted,
            mutedUntil: mutedUntil,
            isPinned: isPinned,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CreateDirectChatRequest: Encodable {
    let type = ChatType.direct
    let participantIds: [String]
}

struct CreateGroupChatRequest: Encodable {
    let type = ChatType.group
    let participantIds: [String]
    let name: String
    let avatarUrl: String?
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var normalizedID: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
