import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIClientError: LocalizedError {
    case missingBaseURL
    case invalidURL(String)
    case network(Error)
    case unauthorized
    case server(code: String, message: String)
    case invalidResponse
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Missing backend URL."
        case .invalidURL(let path):
            return "Invalid backend path: \(path)"
        case .network(let error):
            return "Cannot reach the backend. \(error.localizedDescription)"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .server(_, let message):
            return message
        case .invalidResponse:
            return "Invalid response from server."
        case .decoding(let error):
            return "Unable to read server response. \(error.localizedDescription)"
        }
    }
}

final class APIClient {
    private static let configuredBaseURL: URL = {
        if let url = URL(string: "http://156.67.105.161:8020") {
            return url
        }
        return URL(fileURLWithPath: "/")
    }()

    static let shared = APIClient(baseURL: configuredBaseURL)

    private let baseURL: URL
    private let session: URLSession
    var accessTokenProvider: (() -> String?)?
    var refreshHandler: (() async throws -> Void)?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func resolvedURL(for path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard path.hasPrefix("/") else { return nil }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = path
        components.queryItems = nil
        return components.url
    }

    func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true,
        retryOnUnauthorized: Bool = true
    ) async throws -> Response {
        let responseData = try await performRequest(
            path,
            method: method,
            body: body,
            queryItems: queryItems,
            requiresAuth: requiresAuth,
            retryOnUnauthorized: retryOnUnauthorized
        )

        do {
            let envelope = try JSONDecoder().decode(APIEnvelope<Response>.self, from: responseData)
            if envelope.success, let data = envelope.data {
                return data
            }

            if let error = envelope.error {
                throw APIClientError.server(code: error.code, message: error.message)
            }

            throw APIClientError.invalidResponse
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    func requestWithMetadata<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) async throws -> (data: Response, meta: APIResponseMeta?) {
        let responseData = try await performRequest(
            path,
            method: method,
            body: body,
            queryItems: queryItems,
            requiresAuth: requiresAuth,
            retryOnUnauthorized: true
        )

        do {
            let envelope = try JSONDecoder().decode(APIEnvelope<Response>.self, from: responseData)
            if envelope.success, let data = envelope.data {
                return (data, envelope.meta)
            }
            if let error = envelope.error {
                throw APIClientError.server(code: error.code, message: error.message)
            }
            throw APIClientError.invalidResponse
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    private func performRequest(
        _ path: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem],
        requiresAuth: Bool,
        retryOnUnauthorized: Bool
    ) async throws -> Data {
        let request = try makeURLRequest(
            path,
            method: method,
            body: body,
            queryItems: queryItems,
            requiresAuth: requiresAuth
        )
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401, requiresAuth, retryOnUnauthorized {
            do {
                guard let refreshHandler = refreshHandler else { throw APIClientError.unauthorized }
                try await refreshHandler()
                return try await performRequest(
                    path,
                    method: method,
                    body: body,
                    queryItems: queryItems,
                    requiresAuth: requiresAuth,
                    retryOnUnauthorized: false
                )
            } catch let error as APIClientError {
                throw error
            } catch {
                throw APIClientError.unauthorized
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let envelope = try? JSONDecoder().decode(APIEnvelope<EmptyResponse>.self, from: data), let error = envelope.error {
                throw APIClientError.server(code: error.code, message: error.message)
            }
            throw APIClientError.server(code: "HTTP_\(httpResponse.statusCode)", message: "Request failed with status \(httpResponse.statusCode).")
        }

        return data
    }

    private func makeURLRequest(
        _ path: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem],
        requiresAuth: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.missingBaseURL
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIClientError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        if requiresAuth, let token = accessTokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}



