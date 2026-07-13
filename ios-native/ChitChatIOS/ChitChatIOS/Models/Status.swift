import Foundation

enum StatusKind: String, Codable {
    case text
    case image
}

enum StatusBackgroundStyle: String, Codable, CaseIterable {
    case teal
    case purple
    case blue
    case pink
    case green
    case orange
}

struct StatusOwner: Codable, Equatable {
    let id: String
    let name: String
    let avatarUrl: String
}

struct StatusViewer: Codable, Equatable {
    let id: String
    let name: String
    let avatarUrl: String
    let viewedAt: String
}

struct StatusItem: Codable, Equatable {
    let id: String
    let ownerId: String
    let type: StatusKind
    let text: String
    let mediaUrl: String
    let backgroundStyle: String
    let createdAt: String
    let updatedAt: String
    let expiresAt: String
    let viewCount: Int
    let hasViewed: Bool
    let viewers: [StatusViewer]?
}

struct StatusGroup: Codable, Equatable {
    let owner: StatusOwner
    let statuses: [StatusItem]
    let hasUnseen: Bool
    let latestCreatedAt: String
}

struct StatusCreatedSocketEvent: Codable, Equatable {
    let status: StatusItem
    let owner: StatusOwner
}

struct StatusDeletedSocketEvent: Codable, Equatable {
    let statusId: String
    let ownerId: String
    let deletedAt: String
}

struct StatusViewedSocketEvent: Codable, Equatable {
    let statusId: String
    let ownerId: String
    let viewCount: Int
    let viewer: StatusViewer
}

struct DeleteStatusResponse: Codable {
    let statusId: String
    let ownerId: String
    let deletedAt: String
}

struct CreateTextStatusRequest: Encodable {
    let type = "text"
    let text: String
    let backgroundStyle: String
}

struct CreateImageStatusRequest: Encodable {
    let type = "image"
    let mediaUrl: String
}
