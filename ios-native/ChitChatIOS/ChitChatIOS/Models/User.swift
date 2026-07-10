import Foundation

struct User: Codable, Equatable {
    let id: String
    let phone: String
    let name: String
    let avatarUrl: String
    let bio: String
    let isProfileComplete: Bool
    let isOnline: Bool?
    let lastSeenAt: String?
    let createdAt: String?
    let updatedAt: String?

    init(
        id: String,
        phone: String,
        name: String,
        avatarUrl: String,
        bio: String,
        isProfileComplete: Bool,
        isOnline: Bool? = nil,
        lastSeenAt: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.phone = phone
        self.name = name
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.isProfileComplete = isProfileComplete
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case name
        case avatarUrl
        case bio
        case isProfileComplete
        case isOnline
        case lastSeenAt
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        phone = try container.decode(String.self, forKey: .phone)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        isProfileComplete = try container.decodeIfPresent(Bool.self, forKey: .isProfileComplete) ?? false
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline)
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

