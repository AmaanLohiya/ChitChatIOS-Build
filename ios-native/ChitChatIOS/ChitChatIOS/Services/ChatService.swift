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

    func createDirectChat(participantUserId: String) async throws -> Chat {
        try await apiClient.request(
            "/api/v1/chats",
            method: .post,
            body: CreateDirectChatRequest(participantIds: [participantUserId])
        )
    }
}
