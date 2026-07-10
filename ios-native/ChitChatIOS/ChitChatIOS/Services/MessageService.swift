import Foundation

final class MessageService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func listMessages(chatId: String, cursor: String? = nil, limit: Int = 50) async throws -> PaginatedResponse<[Message]> {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let result: (data: [Message], meta: APIResponseMeta?) = try await apiClient.requestWithMetadata(
            "/api/v1/chats/\(chatId)/messages",
            queryItems: queryItems
        )

        return PaginatedResponse(
            values: result.data,
            nextCursor: result.meta?.nextCursor,
            hasMore: result.meta?.hasMore ?? false,
            limit: result.meta?.limit
        )
    }

    func sendText(chatId: String, text: String) async throws -> Message {
        try await sendMessage(
            chatId: chatId,
            request: CreateMessageRequest(type: .text, text: text, attachments: nil)
        )
    }

    func sendMessage(chatId: String, request: CreateMessageRequest) async throws -> Message {
        try await apiClient.request(
            "/api/v1/chats/\(chatId)/messages",
            method: .post,
            body: request
        )
    }
}
