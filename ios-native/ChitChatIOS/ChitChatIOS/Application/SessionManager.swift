import Foundation

final class SessionManager {
    enum State {
        case restoring
        case signedOut
        case signedIn(User)
    }

    static let shared = SessionManager()

    var onStateChange: ((State) -> Void)? {
        didSet { onStateChange?(state) }
    }

    private(set) var state: State = .restoring {
        didSet {
            onStateChange?(state)
            switch state {
            case .signedIn:
                if let accessToken, !accessToken.isEmpty {
                    SocketService.shared.connect(accessToken: accessToken)
                }
            case .signedOut:
                VoiceCallService.shared.resetForSignOut()
                SocketService.shared.disconnect()
            case .restoring:
                break
            }
        }
    }

    private let authService: AuthService
    private let keychain: KeychainStore

    private var accessToken: String?
    private var refreshToken: String?
    private var sessionId: String?
    private var currentUser: User?
    private var refreshTask: Task<Void, Error>?

    private enum Key {
        static let accessToken = "auth.native.accessToken.v1"
        static let refreshToken = "auth.native.refreshToken.v1"
        static let sessionId = "auth.native.sessionId.v1"
        static let currentUser = "auth.native.currentUser.v1"
    }

    private init(authService: AuthService = AuthService(), keychain: KeychainStore = .shared) {
        self.authService = authService
        self.keychain = keychain
        APIClient.shared.accessTokenProvider = { [weak self] in self?.accessToken }
        APIClient.shared.refreshHandler = { [weak self] in
            guard let self = self else { throw APIClientError.unauthorized }
            try await self.refreshSession()
        }
        SocketService.shared.configure(
            accessTokenProvider: { [weak self] in self?.accessToken },
            authenticationRecovery: { [weak self] in
                guard let self else { return false }
                do {
                    try await self.refreshSession()
                    return true
                } catch {
                    return false
                }
            }
        )
    }

    func restoreSession() async {
        state = .restoring
        accessToken = try? keychain.get(Key.accessToken)
        refreshToken = try? keychain.get(Key.refreshToken)
        sessionId = try? keychain.get(Key.sessionId)
        currentUser = loadStoredUser()

        guard refreshToken != nil, sessionId != nil else {
            state = .signedOut
            return
        }

        do {
            let user = try await authService.getMe()
            try saveStoredUser(user)
            currentUser = user
            state = .signedIn(user)
        } catch APIClientError.unauthorized {
            await restoreByRefreshingOrFallback()
        } catch APIClientError.server(let code, _) where code == "MISSING_AUTH_SESSION" || code == "INVALID_ACCESS_TOKEN" {
            await restoreByRefreshingOrFallback()
        } catch APIClientError.network {
            if let currentUser = currentUser {
                state = .signedIn(currentUser)
            } else {
                state = .signedOut
            }
        } catch {
            if let currentUser = currentUser {
                state = .signedIn(currentUser)
            } else {
                state = .signedOut
            }
        }
    }

    func requestOtp(phone: String) async throws -> RequestOtpResponse {
        try await authService.requestOtp(phone: phone)
    }

    func verifyOtp(phone: String, otp: String, otpRequestId: String) async throws {
        let response = try await authService.verifyOtp(phone: phone, otp: otp, otpRequestId: otpRequestId)
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        sessionId = response.sessionId
        currentUser = response.user
        try saveSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            sessionId: response.sessionId,
            user: response.user
        )
        state = .signedIn(response.user)
    }

    func refreshSession() async throws {
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }

        guard let refreshToken = refreshToken else {
            throw APIClientError.unauthorized
        }

        let task = Task<Void, Error> { [weak self, authService, refreshToken] in
            let response = try await authService.refresh(refreshToken: refreshToken)
            guard let self = self else { return }
            self.accessToken = response.accessToken
            if let rotated = response.refreshToken {
                self.refreshToken = rotated
            }
            try? self.keychain.set(response.accessToken, for: Key.accessToken)
            if let rotated = response.refreshToken {
                try? self.keychain.set(rotated, for: Key.refreshToken)
            }
            SocketService.shared.connect(accessToken: response.accessToken)
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    func signOut() {
        SocketService.shared.disconnect()
        accessToken = nil
        refreshToken = nil
        sessionId = nil
        currentUser = nil
        keychain.delete(Key.accessToken)
        keychain.delete(Key.refreshToken)
        keychain.delete(Key.sessionId)
        keychain.delete(Key.currentUser)
        state = .signedOut
    }

    private func restoreByRefreshingOrFallback() async {
        do {
            try await refreshSession()
            let user = try await authService.getMe()
            try saveStoredUser(user)
            currentUser = user
            state = .signedIn(user)
        } catch APIClientError.network {
            if let currentUser = currentUser {
                state = .signedIn(currentUser)
            } else {
                state = .signedOut
            }
        } catch {
            signOut()
        }
    }

    private func saveSession(accessToken: String, refreshToken: String, sessionId: String, user: User) throws {
        try keychain.set(accessToken, for: Key.accessToken)
        try keychain.set(refreshToken, for: Key.refreshToken)
        try keychain.set(sessionId, for: Key.sessionId)
        try saveStoredUser(user)
    }

    private func saveStoredUser(_ user: User) throws {
        let data = try JSONEncoder().encode(user)
        let raw = String(data: data, encoding: .utf8) ?? ""
        try keychain.set(raw, for: Key.currentUser)
    }

    private func loadStoredUser() -> User? {
        guard
            let raw = try? keychain.get(Key.currentUser),
            let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(User.self, from: data)
    }
}




