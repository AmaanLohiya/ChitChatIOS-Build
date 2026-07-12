import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case video
    case audio
    case voice
    case document
    case location
    case contact
    case sticker
    case gif
    case system
}

enum MessageStatus {
    case sent
    case delivered
    case read
}

struct MessageSender: Equatable {
    let id: String
    let name: String
    let avatarUrl: String
}

struct MessageAttachment: Codable, Equatable {
    let url: String
    let mimeType: String?
    let fileName: String?
    let size: Int?
    let duration: Double?
    let width: Int?
    let height: Int?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case url
        case secureUrl
        case mimeType
        case contentType
        case fileName
        case filename
        case originalName
        case name
        case size
        case fileSize
        case sizeBytes
        case duration
        case width
        case height
        case thumbnailUrl
    }

    init(
        url: String,
        mimeType: String?,
        fileName: String?,
        size: Int?,
        duration: Double?,
        width: Int?,
        height: Int?,
        thumbnailUrl: String?
    ) {
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.size = size
        self.duration = duration
        self.width = width
        self.height = height
        self.thumbnailUrl = thumbnailUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try Self.firstNonEmptyString(in: container, keys: [.url, .secureUrl]) ?? ""
        mimeType = try Self.firstNonEmptyString(in: container, keys: [.mimeType, .contentType])
        fileName = try Self.firstNonEmptyString(in: container, keys: [.fileName, .filename, .originalName, .name])
        size = try container.decodeIfPresent(Int.self, forKey: .size)
            ?? container.decodeIfPresent(Int.self, forKey: .fileSize)
            ?? container.decodeIfPresent(Int.self, forKey: .sizeBytes)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
    }

    private static func firstNonEmptyString(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> String? {
        for key in keys {
            let value = try container.decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
    }

    func resolvingSize(_ fallbackSize: Int?) -> MessageAttachment {
        guard size == nil, let fallbackSize, fallbackSize > 0 else { return self }
        return MessageAttachment(
            url: url,
            mimeType: mimeType,
            fileName: fileName,
            size: fallbackSize,
            duration: duration,
            width: width,
            height: height,
            thumbnailUrl: thumbnailUrl
        )
    }
}

struct MessageReceipt: Codable, Equatable {
    let userId: String
    let deliveredAt: String?
    let readAt: String?
}

struct MessageReaction: Codable, Equatable {
    let userId: String
    let emoji: String
    let createdAt: String
}

struct Message: Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let type: MessageType
    let text: String
    let attachments: [MessageAttachment]
    let replyToMessageId: String?
    let forwardedFromMessageId: String?
    let deliveredTo: [MessageReceipt]
    let readBy: [MessageReceipt]
    let reactions: [MessageReaction]
    let editedAt: String?
    let deletedForEveryoneAt: String?
    let createdAt: String
    let updatedAt: String
    let isDeletedForEveryone: Bool
    let isDeletedForMe: Bool

    var status: MessageStatus {
        if readBy.count > 1 { return .read }
        if deliveredTo.count > 1 { return .delivered }
        return .sent
    }

    var primaryAttachment: MessageAttachment? {
        attachments.first
    }

    var displayText: String {
        if isDeletedForEveryone { return "This message was deleted" }
        switch type {
        case .text:
            return text
        case .image:
            return text.isEmpty ? "Photo" : text
        case .document:
            return primaryAttachment?.fileName ?? "Document"
        default:
            return type.rawValue.capitalized
        }
    }
}

struct CreateTextMessageRequest: Encodable {
    let type = MessageType.text
    let text: String
}

struct CreateMessageRequest: Encodable {
    let type: MessageType
    let text: String?
    let attachments: [MessageAttachment]?
    let replyToMessageId: String?

    init(
        type: MessageType,
        text: String?,
        attachments: [MessageAttachment]?,
        replyToMessageId: String? = nil
    ) {
        self.type = type
        self.text = text
        self.attachments = attachments
        self.replyToMessageId = replyToMessageId
    }
}

struct EditMessageRequest: Encodable {
    let text: String
}

struct DeleteMessageRequest: Encodable {
    let forEveryone: Bool
}

struct MessageReactionRequest: Encodable {
    let emoji: String
}
