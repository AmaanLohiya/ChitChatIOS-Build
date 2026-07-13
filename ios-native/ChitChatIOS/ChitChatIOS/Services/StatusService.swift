import Foundation

final class StatusService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func feed() async throws -> [StatusGroup] {
        try await apiClient.request("/api/v1/statuses/feed")
    }

    func mine() async throws -> StatusGroup {
        try await apiClient.request("/api/v1/statuses/mine")
    }

    func createText(text: String, backgroundStyle: StatusBackgroundStyle) async throws -> StatusItem {
        try await apiClient.request(
            "/api/v1/statuses",
            method: .post,
            body: CreateTextStatusRequest(text: text, backgroundStyle: backgroundStyle.rawValue)
        )
    }

    func createImage(mediaURL: String) async throws -> StatusItem {
        try await apiClient.request(
            "/api/v1/statuses",
            method: .post,
            body: CreateImageStatusRequest(mediaUrl: mediaURL)
        )
    }

    func markViewed(statusID: String) async throws -> StatusItem {
        try await apiClient.request(
            "/api/v1/statuses/\(statusID)/view",
            method: .post
        )
    }

    func delete(statusID: String) async throws -> DeleteStatusResponse {
        try await apiClient.request(
            "/api/v1/statuses/\(statusID)",
            method: .delete
        )
    }
}
