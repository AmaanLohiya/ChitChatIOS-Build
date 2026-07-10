import Foundation

enum ContactSource: String, Codable {
    case device
    case app
}

struct Contact: Codable, Equatable {
    let id: String
    let ownerUserId: String
    let contactUserId: String?
    let name: String
    let phoneNumber: String
    let avatarUrl: String
    let label: String
    let source: ContactSource
    let isBlocked: Bool
    let createdAt: String
    let updatedAt: String
}

struct CreateContactRequest: Encodable {
    let contactUserId: String?
    let name: String
    let phoneNumber: String
    let source: ContactSource
    let label: String?
}
