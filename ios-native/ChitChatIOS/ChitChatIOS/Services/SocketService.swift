import Foundation
import SocketIO

extension Notification.Name {
    static let socketConnected = Notification.Name("chitchat.socket.connected")
    static let socketDisconnected = Notification.Name("chitchat.socket.disconnected")
    static let socketAuthenticationError = Notification.Name("chitchat.socket.authenticationError")
    static let socketMessageNew = Notification.Name("chitchat.socket.message.new")
    static let socketMessageUpdated = Notification.Name("chitchat.socket.message.updated")
    static let socketMessageDeleted = Notification.Name("chitchat.socket.message.deleted")
    static let socketMessageReactionUpdated = Notification.Name("chitchat.socket.message.reactionUpdated")
    static let socketMessageDelivered = Notification.Name("chitchat.socket.message.delivered")
    static let socketMessageRead = Notification.Name("chitchat.socket.message.read")
    static let socketChatUpdated = Notification.Name("chitchat.socket.chat.updated")
    static let socketTypingStarted = Notification.Name("chitchat.socket.typing.started")
    static let socketTypingStopped = Notification.Name("chitchat.socket.typing.stopped")
    static let socketPresenceUpdated = Notification.Name("chitchat.socket.presence.updated")
    static let socketCallOffer = Notification.Name("chitchat.socket.call.offer")
    static let socketCallAnswer = Notification.Name("chitchat.socket.call.answer")
    static let socketCallIceCandidate = Notification.Name("chitchat.socket.call.iceCandidate")
    static let socketCallRinging = Notification.Name("chitchat.socket.call.ringing")
    static let socketCallReject = Notification.Name("chitchat.socket.call.reject")
    static let socketCallCancel = Notification.Name("chitchat.socket.call.cancel")
    static let socketCallEnd = Notification.Name("chitchat.socket.call.end")
    static let socketCallBusy = Notification.Name("chitchat.socket.call.busy")
    static let socketCallHistoryUpdated = Notification.Name("chitchat.socket.call.historyUpdated")
    static let socketStatusCreated = Notification.Name("chitchat.socket.status.created")
    static let socketStatusDeleted = Notification.Name("chitchat.socket.status.deleted")
    static let socketStatusViewed = Notification.Name("chitchat.socket.status.viewed")
}

struct SocketMessageEvent {
    let chatId: String
    let message: Message
}

struct SocketTypingEvent {
    let chatId: String
    let userId: String
}

struct SocketPresenceEvent {
    let userId: String
    let isOnline: Bool
    let lastSeenAt: String?
}

enum SocketServiceError: LocalizedError {
    case disconnected
    case acknowledgementTimeout
    case invalidPayload
    case server(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .disconnected:
            return "Realtime connection is unavailable."
        case .acknowledgementTimeout:
            return "Realtime request timed out."
        case .invalidPayload:
            return "Realtime server returned an invalid response."
        case .server(_, let message):
            return message
        }
    }
}

final class SocketService {
    static let shared = SocketService()

    private let baseURL = URL(string: "http://156.67.105.161:8020")
    private let notificationCenter: NotificationCenter
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var activeToken: String?
    private var desiredChatIDs = Set<String>()
    private var joinedChatIDs = Set<String>()
    private var joiningChatIDs = Set<String>()
    private var accessTokenProvider: (() -> String?)?
    private var authenticationRecovery: (() async -> Bool)?
    private var isRecoveringAuthentication = false

    private(set) var isConnected = false

    private init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func configure(
        accessTokenProvider: @escaping () -> String?,
        authenticationRecovery: @escaping () async -> Bool
    ) {
        self.accessTokenProvider = accessTokenProvider
        self.authenticationRecovery = authenticationRecovery
    }

    func connect(accessToken: String) {
        guard !accessToken.isEmpty else { return }
        DispatchQueue.main.async {
            guard let baseURL = self.baseURL else {
                self.debug("invalid server URL")
                return
            }
            if self.activeToken == accessToken, let socket = self.socket {
                if socket.status != .connected && socket.status != .connecting {
                    self.debug("reconnecting")
                    socket.connect(withPayload: ["token": accessToken])
                }
                return
            }

            self.teardown(clearRooms: false, clearToken: true)
            self.activeToken = accessToken

            let manager = SocketManager(
                socketURL: baseURL,
                config: [
                    .log(false),
                    .compress,
                    .forceNew(true),
                    .reconnects(true),
                    .reconnectAttempts(-1),
                    .reconnectWait(2),
                    .reconnectWaitMax(12),
                    .handleQueue(.main),
                    .extraHeaders(["Authorization": "Bearer \(accessToken)"])
                ]
            )
            let socket = manager.defaultSocket
            self.manager = manager
            self.socket = socket
            self.registerHandlers(on: socket)
            self.debug("connecting")
            socket.connect(withPayload: ["token": accessToken])
        }
    }

    func reconnectUsingLatestToken() {
        guard let token = accessTokenProvider?(), !token.isEmpty else { return }
        connect(accessToken: token)
    }

    func suspend() {
        DispatchQueue.main.async {
            self.teardown(clearRooms: false, clearToken: true)
        }
    }

    func disconnect() {
        DispatchQueue.main.async {
            self.teardown(clearRooms: true, clearToken: true)
        }
    }

    func joinChat(_ chatId: String) {
        guard !chatId.isEmpty else { return }
        DispatchQueue.main.async {
            self.desiredChatIDs.insert(chatId)
            guard self.isConnected else { return }
            self.joinDesiredChat(chatId)
        }
    }

    func leaveChat(_ chatId: String) {
        guard !chatId.isEmpty else { return }
        DispatchQueue.main.async {
            let wasDesired = self.desiredChatIDs.contains(chatId)
            let wasJoined = self.joinedChatIDs.contains(chatId)
            let wasJoining = self.joiningChatIDs.contains(chatId)
            if self.isConnected, wasJoined {
                self.emitAcknowledged("typing:stop", payload: ["chatId": chatId])
            }
            self.desiredChatIDs.remove(chatId)
            self.joinedChatIDs.remove(chatId)
            self.joiningChatIDs.remove(chatId)
            guard self.isConnected, wasDesired || wasJoined || wasJoining else { return }
            self.emitAcknowledged("chat:leave", payload: ["chatId": chatId])
        }
    }

    func startTyping(in chatId: String) {
        DispatchQueue.main.async {
            guard self.isConnected, self.joinedChatIDs.contains(chatId) else { return }
            self.emitAcknowledged("typing:start", payload: ["chatId": chatId])
        }
    }

    func stopTyping(in chatId: String) {
        DispatchQueue.main.async {
            guard self.isConnected, self.joinedChatIDs.contains(chatId) else { return }
            self.emitAcknowledged("typing:stop", payload: ["chatId": chatId])
        }
    }

    func isChatJoined(_ chatId: String) -> Bool {
        isConnected && joinedChatIDs.contains(chatId)
    }

    func markRead(chatId: String, messageId: String) async throws -> Message {
        let response = try await emitAcknowledgedResponse(
            "message:read",
            payload: ["chatId": chatId, "messageId": messageId],
            timeout: 8
        )
        return try Self.message(fromAcknowledgement: response)
    }

    func sendText(chatId: String, text: String) async throws -> Message {
        try await sendMessage(
            chatId: chatId,
            type: .text,
            text: text,
            attachments: nil,
            replyToMessageId: nil
        )
    }

    func editMessage(chatId: String, messageId: String, text: String) async throws -> Message {
        let response = try await emitAcknowledgedResponse(
            "message:edit",
            payload: ["chatId": chatId, "messageId": messageId, "text": text],
            timeout: 8
        )
        return try Self.message(fromAcknowledgement: response)
    }

    func deleteMessage(
        chatId: String,
        messageId: String,
        forEveryone: Bool
    ) async throws -> Message {
        let response = try await emitAcknowledgedResponse(
            "message:delete",
            payload: [
                "chatId": chatId,
                "messageId": messageId,
                "forEveryone": forEveryone
            ],
            timeout: 8
        )
        return try Self.message(fromAcknowledgement: response)
    }

    func addReaction(chatId: String, messageId: String, emoji: String) async throws -> Message {
        let response = try await emitAcknowledgedResponse(
            "message:reaction:add",
            payload: ["chatId": chatId, "messageId": messageId, "emoji": emoji],
            timeout: 8
        )
        return try Self.message(fromAcknowledgement: response)
    }

    func removeReaction(chatId: String, messageId: String) async throws -> Message {
        let response = try await emitAcknowledgedResponse(
            "message:reaction:remove",
            payload: ["chatId": chatId, "messageId": messageId],
            timeout: 8
        )
        return try Self.message(fromAcknowledgement: response)
    }

    func sendCallOffer(chatId: String, calleeId: String, offer: [String: Any]) async throws -> VoiceCall {
        let response = try await emitAcknowledgedResponse(
            "call:offer",
            payload: [
                "chatId": chatId,
                "calleeId": calleeId,
                "type": VoiceCallType.voice.rawValue,
                "offer": offer
            ],
            timeout: 10
        )
        return try Self.call(fromAcknowledgement: response)
    }

    func sendCallAnswer(callId: String, answer: [String: Any]) async throws -> VoiceCall {
        let response = try await emitAcknowledgedResponse(
            "call:answer",
            payload: ["callId": callId, "answer": answer],
            timeout: 10
        )
        return try Self.call(fromAcknowledgement: response)
    }

    func sendIceCandidate(callId: String, candidate: [String: Any]) async throws {
        _ = try await emitAcknowledgedResponse(
            "call:ice-candidate",
            payload: ["callId": callId, "candidate": candidate],
            timeout: 5
        )
    }

    func sendCallRinging(callId: String) async throws {
        _ = try await emitAcknowledgedResponse(
            "call:ringing",
            payload: ["callId": callId],
            timeout: 5
        )
    }

    func sendCallHeartbeat(callId: String) async throws {
        _ = try await emitAcknowledgedResponse(
            "call:heartbeat",
            payload: ["callId": callId],
            timeout: 5
        )
    }

    func sendCallReject(callId: String, reason: String? = nil) async throws -> VoiceCall {
        try await sendCallTerminalEvent("call:reject", callId: callId, reason: reason)
    }

    func sendCallCancel(callId: String, reason: String? = nil) async throws -> VoiceCall {
        try await sendCallTerminalEvent("call:cancel", callId: callId, reason: reason)
    }

    func sendCallEnd(callId: String, reason: String? = nil) async throws -> VoiceCall {
        try await sendCallTerminalEvent("call:end", callId: callId, reason: reason)
    }

    func sendMessage(
        chatId: String,
        type: MessageType,
        text: String? = nil,
        attachments: [MessageAttachment]? = nil,
        replyToMessageId: String? = nil
    ) async throws -> Message {
        let payload = try Self.messagePayload(
            chatId: chatId,
            type: type,
            text: text,
            attachments: attachments,
            replyToMessageId: replyToMessageId
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Message, Error>) in
            DispatchQueue.main.async {
                guard let socket = self.socket, self.isConnected else {
                    continuation.resume(throwing: SocketServiceError.disconnected)
                    return
                }

                socket.emitWithAck("message:send", payload).timingOut(after: 8) { data in
                    do {
                        let response = try self.parseAcknowledgement(data)
                        let message = try Self.message(fromAcknowledgement: response)
                        self.debug("message:send acknowledged", id: message.id)
                        continuation.resume(returning: message)
                    } catch {
                        self.debug("message:send failed")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private static func messagePayload(
        chatId: String,
        type: MessageType,
        text: String?,
        attachments: [MessageAttachment]?,
        replyToMessageId: String?
    ) throws -> [String: Any] {
        var payload: [String: Any] = [
            "chatId": chatId,
            "type": type.rawValue
        ]

        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["text"] = text
        }

        if let attachments, !attachments.isEmpty {
            let data = try JSONEncoder().encode(attachments)
            payload["attachments"] = try JSONSerialization.jsonObject(with: data)
        }

        if let replyToMessageId, !replyToMessageId.isEmpty {
            payload["replyToMessageId"] = replyToMessageId
        }

        return payload
    }

    private func sendCallTerminalEvent(_ event: String, callId: String, reason: String?) async throws -> VoiceCall {
        var payload: [String: Any] = ["callId": callId]
        if let reason {
            payload["reason"] = reason
        }
        let response = try await emitAcknowledgedResponse(event, payload: payload, timeout: 5)
        return try Self.call(fromAcknowledgement: response)
    }

    private func registerHandlers(on socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            self.isConnected = true
            self.joinedChatIDs.removeAll()
            self.joiningChatIDs.removeAll()
            self.debug("connected")
            self.desiredChatIDs.forEach {
                self.joinDesiredChat($0)
            }
            self.notificationCenter.post(name: .socketConnected, object: nil)
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            guard let self else { return }
            self.isConnected = false
            self.joinedChatIDs.removeAll()
            self.joiningChatIDs.removeAll()
            self.debug("disconnected")
            self.notificationCenter.post(name: .socketDisconnected, object: nil)
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            guard let self else { return }
            self.debug("connection error")
            if self.isAuthenticationError(data) {
                self.handleAuthenticationError()
            }
        }

        registerMessageHandler("message:new", notification: .socketMessageNew, on: socket)
        registerMessageHandler("message:updated", notification: .socketMessageUpdated, on: socket)
        registerMessageHandler("message:deleted", notification: .socketMessageDeleted, on: socket)
        registerMessageHandler(
            "message:reaction:updated",
            notification: .socketMessageReactionUpdated,
            on: socket
        )
        registerMessageHandler("message:delivered", notification: .socketMessageDelivered, on: socket)
        registerMessageHandler("message:read", notification: .socketMessageRead, on: socket)

        socket.on("chat:updated") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let value = payload["chat"],
                let chat = Self.decode(Chat.self, from: value)
            else { return }
            self.debug("chat:updated", id: chat.id)
            self.notificationCenter.post(name: .socketChatUpdated, object: chat)
        }

        socket.on("typing:start") { [weak self] data, _ in
            self?.handleTyping(data, notification: .socketTypingStarted)
        }
        socket.on("typing:stop") { [weak self] data, _ in
            self?.handleTyping(data, notification: .socketTypingStopped)
        }
        socket.on("presence:update") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let userId = payload["userId"] as? String,
                let isOnline = payload["isOnline"] as? Bool
            else { return }
            let event = SocketPresenceEvent(
                userId: userId,
                isOnline: isOnline,
                lastSeenAt: payload["lastSeenAt"] as? String
            )
            self.debug("presence:update", id: userId)
            self.notificationCenter.post(name: .socketPresenceUpdated, object: event)
        }

        socket.on("status:created") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first,
                let event = Self.decode(StatusCreatedSocketEvent.self, from: payload)
            else { return }
            self.debug("status:created", id: event.status.id)
            self.notificationCenter.post(name: .socketStatusCreated, object: event)
        }
        socket.on("status:deleted") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first,
                let event = Self.decode(StatusDeletedSocketEvent.self, from: payload)
            else { return }
            self.debug("status:deleted", id: event.statusId)
            self.notificationCenter.post(name: .socketStatusDeleted, object: event)
        }
        socket.on("status:viewed") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first,
                let event = Self.decode(StatusViewedSocketEvent.self, from: payload)
            else { return }
            self.debug("status:viewed", id: event.statusId)
            self.notificationCenter.post(name: .socketStatusViewed, object: event)
        }

        registerCallHandlers(on: socket)
    }

    private func registerMessageHandler(
        _ eventName: String,
        notification: Notification.Name,
        on socket: SocketIOClient
    ) {
        socket.on(eventName) { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let chatId = payload["chatId"] as? String,
                let value = payload["message"],
                let message = Self.decode(Message.self, from: value)
            else { return }
            self.debug(eventName, id: message.id)
            self.notificationCenter.post(
                name: notification,
                object: SocketMessageEvent(chatId: chatId, message: message)
            )
        }
    }

    private func handleTyping(_ data: [Any], notification: Notification.Name) {
        guard
            let payload = data.first as? [String: Any],
            let chatId = payload["chatId"] as? String,
            let userId = payload["userId"] as? String
        else { return }
        notificationCenter.post(
            name: notification,
            object: SocketTypingEvent(chatId: chatId, userId: userId)
        )
    }

    private func registerCallHandlers(on socket: SocketIOClient) {
        registerCallSignalHandler("call:offer", notification: .socketCallOffer, signalKey: "offer", on: socket)
        registerCallSignalHandler("call:answer", notification: .socketCallAnswer, signalKey: "answer", on: socket)
        registerCallSignalHandler(
            "call:ice-candidate",
            notification: .socketCallIceCandidate,
            signalKey: "candidate",
            on: socket
        )
        registerCallStatusHandler("call:ringing", notification: .socketCallRinging, on: socket)
        registerCallStatusHandler("call:reject", notification: .socketCallReject, on: socket)
        registerCallStatusHandler("call:cancel", notification: .socketCallCancel, on: socket)
        registerCallStatusHandler("call:end", notification: .socketCallEnd, on: socket)

        socket.on("call:history:updated") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let callValue = payload["call"],
                let call = Self.decode(CallHistoryItem.self, from: callValue)
            else { return }
            self.debug("call:history:updated", id: call.callId)
            self.notificationCenter.post(name: .socketCallHistoryUpdated, object: call)
        }

        socket.on("call:busy") { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let chatId = payload["chatId"] as? String,
                let callerId = payload["callerId"] as? String,
                let calleeId = payload["calleeId"] as? String,
                let busyUserId = payload["busyUserId"] as? String,
                let reason = payload["reason"] as? String
            else { return }

            let event = SocketCallBusyEvent(
                chatId: chatId,
                callerId: callerId,
                calleeId: calleeId,
                busyUserId: busyUserId,
                reason: reason,
                staleCleaned: payload["staleCleaned"] as? Bool ?? false,
                activeCallId: payload["activeCallId"] as? String,
                message: payload["message"] as? String
            )
            self.debug("call:busy", id: chatId)
            self.notificationCenter.post(name: .socketCallBusy, object: event)
        }
    }

    private func registerCallSignalHandler(
        _ eventName: String,
        notification: Notification.Name,
        signalKey: String,
        on socket: SocketIOClient
    ) {
        socket.on(eventName) { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let callValue = payload["call"],
                let call = Self.decode(VoiceCall.self, from: callValue)
            else { return }

            let event = SocketCallEvent(
                call: call,
                offer: signalKey == "offer" ? payload[signalKey] as? [String: Any] : nil,
                answer: signalKey == "answer" ? payload[signalKey] as? [String: Any] : nil,
                candidate: signalKey == "candidate" ? payload[signalKey] as? [String: Any] : nil,
                fromUserId: payload["fromUserId"] as? String,
                reason: payload["reason"] as? String
            )
            self.debug(eventName, id: call.callId)
            self.notificationCenter.post(name: notification, object: event)
        }
    }

    private func registerCallStatusHandler(
        _ eventName: String,
        notification: Notification.Name,
        on socket: SocketIOClient
    ) {
        socket.on(eventName) { [weak self] data, _ in
            guard
                let self,
                let payload = data.first as? [String: Any],
                let callValue = payload["call"],
                let call = Self.decode(VoiceCall.self, from: callValue)
            else { return }

            let event = SocketCallEvent(
                call: call,
                offer: nil,
                answer: nil,
                candidate: nil,
                fromUserId: payload["fromUserId"] as? String,
                reason: payload["reason"] as? String
            )
            self.debug(eventName, id: call.callId)
            self.notificationCenter.post(name: notification, object: event)
        }
    }

    private func joinDesiredChat(_ chatId: String) {
        guard
            isConnected,
            !joinedChatIDs.contains(chatId),
            !joiningChatIDs.contains(chatId)
        else { return }
        joiningChatIDs.insert(chatId)
        emitAcknowledged("chat:join", payload: ["chatId": chatId]) { [weak self] succeeded in
            guard let self else { return }
            self.joiningChatIDs.remove(chatId)
            guard self.isConnected, succeeded, self.desiredChatIDs.contains(chatId) else { return }
            self.joinedChatIDs.insert(chatId)
        }
    }

    private func emitAcknowledged(
        _ event: String,
        payload: [String: Any],
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let socket, isConnected else { return }
        socket.emitWithAck(event, payload).timingOut(after: 8) { [weak self] data in
            guard let self else { return }
            do {
                _ = try self.parseAcknowledgement(data)
                self.debug("\(event) acknowledged")
                completion?(true)
            } catch {
                self.debug("\(event) failed")
                completion?(false)
            }
        }
    }

    private func emitAcknowledgedResponse(
        _ event: String,
        payload: [String: Any],
        timeout: Double
    ) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
            DispatchQueue.main.async {
                guard let socket = self.socket, self.isConnected else {
                    continuation.resume(throwing: SocketServiceError.disconnected)
                    return
                }

                socket.emitWithAck(event, payload).timingOut(after: timeout) { data in
                    do {
                        let response = try self.parseAcknowledgement(data)
                        self.debug("\(event) acknowledged")
                        continuation.resume(returning: response)
                    } catch {
                        self.debug("\(event) failed")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func parseAcknowledgement(_ data: [Any]) throws -> [String: Any] {
        if let status = data.first as? String, status == SocketAckStatus.noAck {
            throw SocketServiceError.acknowledgementTimeout
        }
        guard let response = data.first as? [String: Any] else {
            throw SocketServiceError.invalidPayload
        }
        if response["success"] as? Bool == true {
            return response
        }
        if let error = response["error"] as? [String: Any] {
            throw SocketServiceError.server(
                code: error["code"] as? String ?? "SOCKET_EVENT_FAILED",
                message: error["message"] as? String ?? "Socket event failed."
            )
        }
        throw SocketServiceError.invalidPayload
    }

    private static func call(fromAcknowledgement response: [String: Any]) throws -> VoiceCall {
        guard
            let responseData = response["data"] as? [String: Any],
            let callValue = responseData["call"],
            let call = decode(VoiceCall.self, from: callValue)
        else {
            throw SocketServiceError.invalidPayload
        }
        return call
    }

    private static func message(fromAcknowledgement response: [String: Any]) throws -> Message {
        guard
            let responseData = response["data"] as? [String: Any],
            let messageValue = responseData["message"],
            let message = decode(Message.self, from: messageValue)
        else {
            throw SocketServiceError.invalidPayload
        }
        return message
    }

    private func handleAuthenticationError() {
        guard !isRecoveringAuthentication else { return }
        isRecoveringAuthentication = true
        notificationCenter.post(name: .socketAuthenticationError, object: nil)
        socket?.disconnect()

        Task { [weak self] in
            guard let self else { return }
            let recovered = await self.authenticationRecovery?() ?? false
            await MainActor.run {
                self.isRecoveringAuthentication = false
                if recovered {
                    self.reconnectUsingLatestToken()
                }
            }
        }
    }

    private func isAuthenticationError(_ data: [Any]) -> Bool {
        let description = data.map { String(describing: $0) }.joined(separator: " ")
        return description.range(
            of: "auth|token|unauthorized|session|jwt",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func teardown(clearRooms: Bool, clearToken: Bool) {
        isConnected = false
        joinedChatIDs.removeAll()
        joiningChatIDs.removeAll()
        socket?.removeAllHandlers()
        socket?.disconnect()
        manager?.disconnect()
        socket = nil
        manager = nil
        if clearToken {
            activeToken = nil
        }
        if clearRooms {
            desiredChatIDs.removeAll()
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from value: Any) -> T? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        do {
            let data = try JSONSerialization.data(withJSONObject: value)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            debugStatic("payload decode failed")
            return nil
        }
    }

    private func debug(_ event: String, id: String? = nil) {
        #if DEBUG
        if let id {
            print("[native-socket] \(event) id=\(id)")
        } else {
            print("[native-socket] \(event)")
        }
        #endif
    }

    private static func debugStatic(_ message: String) {
        #if DEBUG
        print("[native-socket] \(message)")
        #endif
    }
}
