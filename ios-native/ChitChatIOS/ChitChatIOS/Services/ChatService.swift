import Foundation

final class ChatService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func listChats() async throws -> [Chat] {
        try await apiClient.request("/api/v1/chats")
    }

    func getChat(id: String) async throws -> Chat {
        try await apiClient.request("/api/v1/chats/\(id)")
    }

    func getGroup(id: String) async throws -> Chat {
        try await apiClient.request("/api/v1/chats/\(id)/group")
    }

    func updateGroup(id: String, input: UpdateGroupRequest) async throws -> Chat {
        try await apiClient.request("/api/v1/chats/\(id)", method: .put, body: input)
    }

    func addGroupMembers(id: String, userIDs: [String]) async throws -> Chat {
        try await apiClient.request("/api/v1/chats/\(id)/members", method: .post, body: AddGroupMembersRequest(participantIds: userIDs))
    }

    func leaveGroup(id: String) async throws -> LeaveGroupResponse {
        try await apiClient.request("/api/v1/chats/\(id)/leave", method: .post)
    }

    func createDirectChat(participantUserId: String) async throws -> Chat {
        try await apiClient.request(
            "/api/v1/chats",
            method: .post,
            body: CreateDirectChatRequest(participantIds: [participantUserId])
        )
    }

    func createGroupChat(
        name: String,
        participantUserIds: [String],
        avatarUrl: String? = nil
    ) async throws -> Chat {
        try await apiClient.request(
            "/api/v1/chats",
            method: .post,
            body: CreateGroupChatRequest(
                participantIds: participantUserIds,
                name: name,
                avatarUrl: avatarUrl
            )
        )
    }
}
