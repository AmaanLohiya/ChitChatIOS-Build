import Foundation
import UniformTypeIdentifiers

enum UploadResourceType: String, Codable {
    case image
    case video
    case raw
    case auto
}

enum UploadUsage: String, Codable {
    case avatar
    case message
    case story
    case group
    case document
    case voice
}

enum UploadStatus: String, Codable {
    case signed
    case uploaded
    case failed
}

struct Upload: Codable, Equatable {
    let id: String
    let provider: String
    let publicId: String
    let assetId: String
    let url: String
    let secureUrl: String
    let thumbnailUrl: String
    let resourceType: UploadResourceType
    let mimeType: String
    let fileName: String
    let fileSize: Int?
    let width: Int?
    let height: Int?
    let duration: Double?
    let format: String
    let usage: UploadUsage
    let status: UploadStatus
    let createdAt: String
    let updatedAt: String

    var attachment: MessageAttachment {
        MessageAttachment(
            url: secureUrl.isEmpty ? url : secureUrl,
            mimeType: mimeType.isEmpty ? nil : mimeType,
            fileName: fileName.isEmpty ? nil : fileName,
            size: fileSize,
            duration: duration,
            width: width,
            height: height,
            thumbnailUrl: thumbnailUrl.isEmpty ? nil : thumbnailUrl
        )
    }
}

enum UploadServiceError: LocalizedError {
    case missingFile
    case missingToken
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Selected file could not be read."
        case .missingToken:
            return "Session expired. Please log in again."
        case .invalidResponse:
            return "Upload response was invalid."
        }
    }
}

final class UploadService {
    private let baseURL = APIClient.shared.resolvedURL(for: "/") ?? URL(fileURLWithPath: "/")
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient = .shared, session: URLSession = .shared) {
        self.apiClient = apiClient
        self.session = session
    }

    func uploadLocalFile(
        fileURL: URL,
        fileName: String,
        mimeType: String,
        usage: UploadUsage,
        resourceType: UploadResourceType
    ) async throws -> Upload {
        try await performUpload(
            fileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            usage: usage,
            resourceType: resourceType,
            retryOnUnauthorized: true
        )
    }

    static func mimeType(for url: URL, fallback: String = "application/octet-stream") -> String {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        if let type = UTType(filenameExtension: url.pathExtension), let mimeType = type.preferredMIMEType {
            return mimeType
        }
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xls":
            return "application/vnd.ms-excel"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc":
            return "application/msword"
        case "csv":
            return "text/csv"
        case "txt":
            return "text/plain"
        case "zip":
            return "application/zip"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic", "heif":
            return "image/heic"
        case "m4a":
            return "audio/mp4"
        default:
            break
        }
        return fallback
    }

    private func performUpload(
        fileURL: URL,
        fileName: String,
        mimeType: String,
        usage: UploadUsage,
        resourceType: UploadResourceType,
        retryOnUnauthorized: Bool
    ) async throws -> Upload {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadServiceError.missingFile
        }
        guard let token = apiClient.accessTokenProvider?(), !token.isEmpty else {
            throw UploadServiceError.missingToken
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try uploadURL())
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeMultipartBody(
            boundary: boundary,
            fileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            usage: usage,
            resourceType: resourceType
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            debugUploadFailure(
                statusCode: nil,
                serverMessage: error.localizedDescription,
                fileURL: fileURL,
                mimeType: mimeType
            )
            throw APIClientError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401, retryOnUnauthorized {
            do {
                guard let refreshHandler = apiClient.refreshHandler else {
                    throw APIClientError.unauthorized
                }
                try await refreshHandler()
                return try await performUpload(
                    fileURL: fileURL,
                    fileName: fileName,
                    mimeType: mimeType,
                    usage: usage,
                    resourceType: resourceType,
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
                debugUploadFailure(
                    statusCode: httpResponse.statusCode,
                    serverMessage: error.message,
                    fileURL: fileURL,
                    mimeType: mimeType
                )
                throw APIClientError.server(code: error.code, message: error.message)
            }
            debugUploadFailure(
                statusCode: httpResponse.statusCode,
                serverMessage: "HTTP \(httpResponse.statusCode)",
                fileURL: fileURL,
                mimeType: mimeType
            )
            throw APIClientError.server(
                code: "HTTP_\(httpResponse.statusCode)",
                message: "Upload failed with status \(httpResponse.statusCode)."
            )
        }

        do {
            let envelope = try JSONDecoder().decode(APIEnvelope<Upload>.self, from: data)
            if envelope.success, let upload = envelope.data {
                return upload
            }
            if let error = envelope.error {
                throw APIClientError.server(code: error.code, message: error.message)
            }
            throw UploadServiceError.invalidResponse
        } catch let error as APIClientError {
            throw error
        } catch let error as UploadServiceError {
            throw error
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        fileURL: URL,
        fileName: String,
        mimeType: String,
        usage: UploadUsage,
        resourceType: UploadResourceType
    ) throws -> Data {
        var body = Data()
        body.appendMultipartField(name: "usage", value: usage.rawValue, boundary: boundary)
        body.appendMultipartField(name: "resourceType", value: resourceType.rawValue, boundary: boundary)
        let fileData = try Data(contentsOf: fileURL)
        body.appendMultipartFile(
            name: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    private func uploadURL() throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.missingBaseURL
        }
        components.path = "/api/v1/uploads/local"
        guard let url = components.url else {
            throw APIClientError.invalidURL("/api/v1/uploads/local")
        }
        return url
    }

    private func debugUploadFailure(
        statusCode: Int?,
        serverMessage: String?,
        fileURL: URL,
        mimeType: String
    ) {
        #if DEBUG
        let fileExtension = fileURL.pathExtension.isEmpty ? "none" : fileURL.pathExtension.lowercased()
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let sanitizedMessage = (serverMessage ?? "none")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(180)
        print(
            "[native-upload] failure status=\(statusCode.map(String.init) ?? "network") " +
            "ext=\(fileExtension) mime=\(mimeType) size=\(fileSize) message=\(sanitizedMessage)"
        )
        #endif
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        name: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}
