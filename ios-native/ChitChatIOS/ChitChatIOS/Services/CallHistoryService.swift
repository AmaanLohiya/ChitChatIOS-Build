import Foundation

final class CallHistoryService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func listCalls(limit: Int = 100) async throws -> [CallHistoryItem] {
        try await apiClient.request(
            "/api/v1/calls",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }
}
