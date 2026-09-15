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

enum MessageStatus: Equatable {
    case sent
    case delivered
    case read
}

enum MessageLocalSendState: Equatable {
    case sending
    case failed
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

struct MessageLocation: Codable, Equatable {
    let lat: Double
    let lng: Double
    let title: String?
    let address: String?

    var isValid: Bool {
        lat.isFinite && lng.isFinite && (-90...90).contains(lat) && (-180...180).contains(lng)
    }

    var displayTitle: String { title?.isEmpty == false ? title ?? "Shared location" : "Shared location" }
    var displayAddress: String {
        if let address, !address.isEmpty { return address }
        return String(format: "%.5f, %.5f", lat, lng)
    }

    init(lat: Double, lng: Double, title: String? = nil, address: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.title = title.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)) }
        self.address = address.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)) }
    }

    enum CodingKeys: String, CodingKey { case lat, lng, title, address }

    init(from decoder: Decoder) throws {
        let values = try? decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lat: (try? values?.decode(Double.self, forKey: .lat)) ?? .nan,
            lng: (try? values?.decode(Double.self, forKey: .lng)) ?? .nan,
            title: try? values?.decode(String.self, forKey: .title),
            address: try? values?.decode(String.self, forKey: .address)
        )
    }
}

struct MessageContactPhone: Codable, Equatable {
    let label: String?
    let number: String

    var isValid: Bool {
        let value = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.count >= 3 && value.count <= 40
    }

    init(label: String? = nil, number: String) {
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedLabel, !trimmedLabel.isEmpty {
            self.label = String(trimmedLabel.prefix(32))
        } else {
            self.label = nil
        }
        self.number = String(number.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    }
}

struct MessageContact: Codable, Equatable {
    let displayName: String
    let phones: [MessageContactPhone]
    let organization: String?

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phones.isEmpty
            && phones.allSatisfy(\.isValid)
    }

    var primaryPhoneNumber: String {
        phones.first?.number ?? "No phone number"
    }

    var phoneSummary: String {
        guard let first = phones.first else { return "No phone number" }
        let extraCount = max(0, phones.count - 1)
        return extraCount > 0 ? "\(first.number) +\(extraCount) more" : first.number
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        guard let first = parts.first?.first else { return "C" }
        let second = parts.count > 1 ? parts.last?.first : nil
        return "\(first)\(second.map(String.init) ?? "")".uppercased()
    }

    init(displayName: String, phones: [MessageContactPhone], organization: String? = nil) {
        self.displayName = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        self.phones = Array(phones.filter(\.isValid).prefix(5))
        let trimmedOrganization = organization?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedOrganization, !trimmedOrganization.isEmpty {
            self.organization = String(trimmedOrganization.prefix(120))
        } else {
            self.organization = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case phones
        case organization
        case name
        case phoneNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? ""
        var phones = try container.decodeIfPresent([MessageContactPhone].self, forKey: .phones) ?? []
        if phones.isEmpty, let phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) {
            phones = [MessageContactPhone(number: phoneNumber)]
        }
        self.init(
            displayName: displayName,
            phones: phones,
            organization: try container.decodeIfPresent(String.self, forKey: .organization)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(phones, forKey: .phones)
        try container.encodeIfPresent(organization, forKey: .organization)
    }
}

struct Message: Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let clientSendId: String?
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
    var location: MessageLocation? = nil
    var contact: MessageContact? = nil

    static func pending(
        chatId: String,
        senderId: String,
        clientSendId: String,
        type: MessageType,
        text: String?,
        attachments: [MessageAttachment],
        replyToMessageId: String?,
        createdAt: String,
        location: MessageLocation? = nil,
        contact: MessageContact? = nil
    ) -> Message {
        Message(
            id: "local-\(clientSendId)",
            chatId: chatId,
            senderId: senderId,
            clientSendId: clientSendId,
            type: type,
            text: text ?? "",
            attachments: attachments,
            replyToMessageId: replyToMessageId,
            forwardedFromMessageId: nil,
            deliveredTo: [],
            readBy: [],
            reactions: [],
            editedAt: nil,
            deletedForEveryoneAt: nil,
            createdAt: createdAt,
            updatedAt: createdAt,
            isDeletedForEveryone: false,
            isDeletedForMe: false,
            location: location,
            contact: contact
        )
    }

    func status(activeParticipantIDs: [String]) -> MessageStatus {
        let recipientIDs = Set(activeParticipantIDs).filter { $0 != senderId }
        guard !recipientIDs.isEmpty else { return .sent }

        let readUserIDs = Set(readBy.map(\.userId))
        if recipientIDs.allSatisfy({ readUserIDs.contains($0) }) { return .read }

        let deliveredUserIDs = Set(deliveredTo.map(\.userId))
        if recipientIDs.allSatisfy({ deliveredUserIDs.contains($0) }) { return .delivered }
        return .sent
    }

    var hasBeenReadByAnother: Bool {
        readBy.contains { $0.userId != senderId }
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
        case .voice, .audio:
            return "Voice message"
        case .location:
            return location?.isValid == true ? "Shared location" : "Unsupported location"
        case .contact:
            return contact?.isValid == true ? contact?.displayName ?? "Shared contact" : "Unsupported contact"
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
    let clientSendId: String?
    let type: MessageType
    let text: String?
    let attachments: [MessageAttachment]?
    let replyToMessageId: String?
    let location: MessageLocation?
    let contact: MessageContact?

    init(
        type: MessageType,
        text: String?,
        attachments: [MessageAttachment]?,
        replyToMessageId: String? = nil,
        clientSendId: String? = nil,
        location: MessageLocation? = nil,
        contact: MessageContact? = nil
    ) {
        self.clientSendId = clientSendId
        self.type = type
        self.text = text
        self.attachments = attachments
        self.replyToMessageId = replyToMessageId
        self.location = location
        self.contact = contact
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
