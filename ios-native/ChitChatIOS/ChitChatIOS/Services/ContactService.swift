import Foundation

final class ContactService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func listContacts() async throws -> [Contact] {
        try await apiClient.request("/api/v1/contacts")
    }

    func searchContacts(query: String) async throws -> [Contact] {
        try await apiClient.request(
            "/api/v1/contacts/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
    }

    func createContact(name: String, phoneNumber: String, label: String? = nil) async throws -> Contact {
        try await apiClient.request(
            "/api/v1/contacts",
            method: .post,
            body: CreateContactRequest(
                contactUserId: nil,
                name: name,
                phoneNumber: phoneNumber,
                source: .app,
                label: label
            )
        )
    }

    func importDeviceContacts(
        entries: [ImportDeviceContactEntry]
    ) async throws -> ImportDeviceContactsResponse {
        try await apiClient.request(
            "/api/v1/contacts/import-device",
            method: .post,
            body: ImportDeviceContactsRequest(entries: entries)
        )
    }
}
