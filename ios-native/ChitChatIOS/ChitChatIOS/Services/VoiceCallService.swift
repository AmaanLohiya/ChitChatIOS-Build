import Foundation
import UIKit
import WebRTC

private enum VoiceCallServiceError: LocalizedError {
    case groupCallsUnsupported
    case missingParticipant
    case alreadyInCall
    case socketUnavailable
    case invalidSignal
    case unsupportedVideo
    case microphonePermissionDenied
    case engineUnavailable

    var errorDescription: String? {
        switch self {
        case .groupCallsUnsupported:
            return "Group voice calls are coming later."
        case .missingParticipant:
            return "Unable to find the person for this call."
        case .alreadyInCall:
            return "You are already in a call."
        case .socketUnavailable:
            return "Realtime connection is unavailable."
        case .invalidSignal:
            return "Call setup data was invalid."
        case .unsupportedVideo:
            return "Video calls are coming later."
        case .microphonePermissionDenied:
            return "Microphone permission is required for voice calls."
        case .engineUnavailable:
            return "Voice engine unavailable."
        }
    }

    var diagnosticName: String {
        switch self {
        case .groupCallsUnsupported:
            return "groupCallsUnsupported"
        case .missingParticipant:
            return "missingParticipant"
        case .alreadyInCall:
            return "alreadyInCall"
        case .socketUnavailable:
            return "socketUnavailable"
        case .invalidSignal:
            return "invalidSignal"
        case .unsupportedVideo:
            return "unsupportedVideo"
        case .microphonePermissionDenied:
            return "microphonePermissionDenied"
        case .engineUnavailable:
            return "engineUnavailable"
        }
    }
}

final class VoiceCallService: NSObject {
    static let shared = VoiceCallService()

    private let chatService = ChatService()
    private let audioSession = CallAudioSession.shared
    private var factory: RTCPeerConnectionFactory?
    private var observers: [NSObjectProtocol] = []

    private var currentUser: User?
    private var currentCall: VoiceCall?
    private var currentParticipant: VoiceCallParticipant?
    private var direction: VoiceCallDirection = .outgoing
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var pendingOffer: [String: Any]?
    private var queuedLocalIceCandidates: [[String: Any]] = []
    private var queuedRemoteIceCandidates: [[String: Any]] = []
    private var heartbeatTimer: Timer?
    private var callStartedAt = Date()
    private var callConnectedAt: Date?
    private var isMuted = false
    private var isSpeakerOn = false
    private var isStartingCall = false
    private weak var callViewController: VoiceCallViewController?

    private override init() {
        super.init()
        observeSocketCalls()
    }

    func configure(currentUser: User) {
        self.currentUser = currentUser
    }

    func resetForSignOut() {
        cleanup(shouldDismissUI: true)
    }

    func startOutgoingVoiceCall(chat: Chat, currentUser: User, presenter: UIViewController) {
        debug("call button tapped")
        guard NativeCallConfig.voiceCallsEnabled else {
            presenter.presentVoiceCallAlert(message: "Voice calls are temporarily unavailable.")
            return
        }
        guard chat.type == .direct else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.groupCallsUnsupported.localizedDescription)
            return
        }
        VoiceCallDiagnostics.record(.chatValidated)
        guard peerConnection == nil, currentCall == nil, !isStartingCall else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.alreadyInCall.localizedDescription)
            return
        }
        guard let participant = Self.participant(from: chat, viewerUserId: currentUser.id) else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.missingParticipant.localizedDescription)
            return
        }
        VoiceCallDiagnostics.record(.calleeResolved)
        debug("callee resolved id=\(participant.id)")
        self.currentUser = currentUser
        VoiceCallDiagnostics.record(.sessionChecked)

        isStartingCall = true
        guard NativeCallConfig.webRTCEnabled else {
            beginOutgoingVoiceCall(
                chat: chat,
                currentUser: currentUser,
                participant: participant,
                presenter: presenter
            )
            return
        }

        guard SocketService.shared.isConnected else {
            isStartingCall = false
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.socketUnavailable.localizedDescription)
            return
        }
        debug("socket connected for call start")

        VoiceCallDiagnostics.record(.microphonePermissionRequested)
        Task { @MainActor [weak self, weak presenter] in
            guard let self else { return }
            let hasMicrophonePermission = await self.audioSession.requestMicrophonePermission()
            guard let presenter else {
                self.isStartingCall = false
                return
            }
            self.debug("microphone permission state granted=\(hasMicrophonePermission)")
            guard hasMicrophonePermission else {
                self.isStartingCall = false
                presenter.presentVoiceCallAlert(message: VoiceCallServiceError.microphonePermissionDenied.localizedDescription)
                return
            }
            VoiceCallDiagnostics.record(.microphonePermissionGranted)
            self.beginOutgoingVoiceCall(
                chat: chat,
                currentUser: currentUser,
                participant: participant,
                presenter: presenter
            )
        }
    }

    private func beginOutgoingVoiceCall(
        chat: Chat,
        currentUser: User,
        participant: VoiceCallParticipant,
        presenter: UIViewController
    ) {
        guard peerConnection == nil, currentCall == nil else {
            isStartingCall = false
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.alreadyInCall.localizedDescription)
            return
        }
        guard !NativeCallConfig.webRTCEnabled || SocketService.shared.isConnected else {
            isStartingCall = false
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.socketUnavailable.localizedDescription)
            return
        }
        self.currentUser = currentUser
        self.currentParticipant = participant
        self.direction = .outgoing
        self.callStartedAt = Date()
        self.callConnectedAt = nil
        self.isMuted = false
        self.isSpeakerOn = false
        presentCallUI(from: presenter) { [weak self, weak presenter] in
            guard let self else { return }
            VoiceCallDiagnostics.record(.callUIPresented)
            guard self.isStartingCall, self.currentParticipant?.id == participant.id else { return }
            guard NativeCallConfig.webRTCEnabled else {
                self.isStartingCall = false
                self.publishFailure(VoiceCallServiceError.engineUnavailable.localizedDescription)
                return
            }
            guard let presenter else {
                self.isStartingCall = false
                return
            }
            self.startOutgoingEngine(
                chat: chat,
                participant: participant,
                presenter: presenter
            )
        }
        publish(
            status: .outgoing,
            callId: nil,
            chatId: chat.id,
            callerId: currentUser.id,
            calleeId: participant.id
        )
    }

    private func startOutgoingEngine(
        chat: Chat,
        participant: VoiceCallParticipant,
        presenter: UIViewController
    ) {
        Task { @MainActor [weak self, weak presenter] in
            guard let self else { return }
            do {
                VoiceCallDiagnostics.record(.beforeAudioSessionStart)
                try self.audioSession.start()
                VoiceCallDiagnostics.record(.afterAudioSessionStart)
                try await self.preparePeerConnection()
                VoiceCallDiagnostics.record(.beforeOfferCreate)
                let offer = try await self.createOffer()
                VoiceCallDiagnostics.record(.afterOfferCreate)
                VoiceCallDiagnostics.record(.beforeSocketCallOffer)
                let call = try await SocketService.shared.sendCallOffer(
                    chatId: chat.id,
                    calleeId: participant.id,
                    offer: offer
                )
                VoiceCallDiagnostics.record(.afterSocketCallOffer)
                self.currentCall = call
                self.isStartingCall = false
                self.publish(status: .ringing)
                self.flushLocalIceCandidates()
                self.debug("outgoing call emitted", callId: call.callId)
            } catch {
                self.debug("outgoing call failed", callId: self.currentCall?.callId)
                self.handleStartupFailure(error, presenter: presenter)
            }
        }
    }

    func acceptIncomingCall() {
        guard let call = currentCall, let offer = pendingOffer else { return }
        guard NativeCallConfig.voiceCallsEnabled else {
            rejectIncomingCall(reason: "voice_calls_disabled")
            return
        }
        guard call.type == .voice else {
            rejectIncomingCall(reason: "unsupported_video")
            return
        }
        guard NativeCallConfig.webRTCEnabled else {
            publishFailure(VoiceCallServiceError.engineUnavailable.localizedDescription)
            return
        }
        publish(status: .connecting)

        VoiceCallDiagnostics.record(.microphonePermissionRequested)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let hasMicrophonePermission = await self.audioSession.requestMicrophonePermission()
                self.debug("incoming microphone permission granted=\(hasMicrophonePermission)", callId: call.callId)
                guard hasMicrophonePermission else {
                    throw VoiceCallServiceError.microphonePermissionDenied
                }
                VoiceCallDiagnostics.record(.microphonePermissionGranted)
                VoiceCallDiagnostics.record(.beforeAudioSessionStart)
                try self.audioSession.start()
                VoiceCallDiagnostics.record(.afterAudioSessionStart)
                try await self.preparePeerConnection()
                try await self.applyRemoteDescription(signal: offer)
                let answer = try await self.createAnswer()
                let answered = try await SocketService.shared.sendCallAnswer(callId: call.callId, answer: answer)
                self.currentCall = answered
                self.callConnectedAt = Date()
                self.publish(status: .active)
                self.flushLocalIceCandidates()
                self.flushRemoteIceCandidates()
                self.startHeartbeat()
            } catch {
                self.debug("accept failed", callId: call.callId)
                Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "accept_failed") }
                self.handleStartupFailure(error, presenter: nil)
            }
        }
    }

    func rejectIncomingCall(reason: String = "rejected") {
        let callId = currentCall?.callId
        if let callId {
            Task { try? await SocketService.shared.sendCallReject(callId: callId, reason: reason) }
        }
        cleanup(shouldDismissUI: true)
    }

    func cancelOutgoingCall() {
        let callId = currentCall?.callId
        if let callId {
            Task { try? await SocketService.shared.sendCallCancel(callId: callId, reason: "cancelled") }
        }
        cleanup(shouldDismissUI: true)
    }

    func endActiveCall(reason: String = "ended") {
        let callId = currentCall?.callId
        if let callId {
            Task { try? await SocketService.shared.sendCallEnd(callId: callId, reason: reason) }
        }
        cleanup(shouldDismissUI: true)
    }

    func toggleMute() {
        isMuted.toggle()
        localAudioTrack?.isEnabled = !isMuted
        publishCurrentState()
    }

    func toggleSpeaker() {
        do {
            let next = !isSpeakerOn
            try audioSession.setSpeakerEnabled(next)
            isSpeakerOn = audioSession.isSpeakerEnabled
            publishCurrentState()
        } catch {
            debug("speaker toggle failed", callId: currentCall?.callId)
        }
    }

    private func observeSocketCalls() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .socketCallOffer, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? SocketCallEvent else { return }
            self?.handleIncomingOffer(event)
        })
        observers.append(center.addObserver(forName: .socketCallAnswer, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? SocketCallEvent else { return }
            self?.handleAnswer(event)
        })
        observers.append(center.addObserver(forName: .socketCallIceCandidate, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? SocketCallEvent else { return }
            self?.handleRemoteIceCandidate(event)
        })
        observers.append(center.addObserver(forName: .socketCallRinging, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? SocketCallEvent else { return }
            self?.handleRinging(event)
        })
        [.socketCallReject, .socketCallCancel, .socketCallEnd].forEach { name in
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let event = notification.object as? SocketCallEvent else { return }
                self?.handleTerminalEvent(event)
            })
        }
        observers.append(center.addObserver(forName: .socketCallBusy, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? SocketCallBusyEvent else { return }
            self?.handleBusy(event)
        })
        observers.append(center.addObserver(forName: .socketDisconnected, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.currentCall != nil else { return }
            self.finishLocally(reason: "Connection lost")
        })
    }

    private func handleIncomingOffer(_ event: SocketCallEvent) {
        let call = event.call
        guard NativeCallConfig.voiceCallsEnabled else {
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "voice_calls_disabled") }
            return
        }
        guard let offer = event.offer else {
            debug("incoming offer missing signal", callId: call.callId)
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "invalid_signal") }
            return
        }
        guard call.type == .voice else {
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "unsupported_video") }
            UIApplication.shared.topMostViewController()?.presentVoiceCallAlert(message: VoiceCallServiceError.unsupportedVideo.localizedDescription)
            return
        }
        guard currentCall == nil, peerConnection == nil else {
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "busy") }
            return
        }
        guard let currentUser else {
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "not_ready") }
            return
        }

        currentCall = call
        pendingOffer = offer
        queuedRemoteIceCandidates.removeAll()
        queuedLocalIceCandidates.removeAll()
        direction = .incoming
        callStartedAt = Date()
        callConnectedAt = nil
        isMuted = false
        isSpeakerOn = false

        Task { [weak self] in
            let chat = try? await self?.chatService.getChat(id: call.chatId)
            let participant = chat.flatMap { Self.participant(from: $0, userId: call.callerId) }
                ?? VoiceCallParticipant(id: call.callerId, name: "ChitChat user", avatarUrl: "")
            await MainActor.run {
                guard let self else { return }
                self.currentParticipant = participant
                if let presenter = UIApplication.shared.topMostViewController() {
                    self.presentCallUI(from: presenter) {
                        VoiceCallDiagnostics.record(.callUIPresented)
                    }
                }
                self.publish(
                    status: .incoming,
                    callId: call.callId,
                    chatId: call.chatId,
                    callerId: call.callerId,
                    calleeId: currentUser.id
                )
                Task { try? await SocketService.shared.sendCallRinging(callId: call.callId) }
                self.debug("incoming offer", callId: call.callId)
            }
        }
    }

    private func handleAnswer(_ event: SocketCallEvent) {
        guard isCurrentCall(event.call), let answer = event.answer else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.applyRemoteDescription(signal: answer)
                await MainActor.run {
                    self.currentCall = event.call
                    self.callConnectedAt = Date()
                    self.publish(status: .active)
                    self.flushRemoteIceCandidates()
                    self.startHeartbeat()
                }
            } catch {
                await MainActor.run {
                    self.endActiveCall(reason: "answer_failed")
                }
            }
        }
    }

    private func handleRemoteIceCandidate(_ event: SocketCallEvent) {
        guard isCurrentCall(event.call), let candidate = event.candidate else { return }
        guard peerConnection != nil else {
            queuedRemoteIceCandidates.append(candidate)
            return
        }
        addRemoteIceCandidate(candidate)
    }

    private func handleRinging(_ event: SocketCallEvent) {
        guard isCurrentCall(event.call), direction == .outgoing else { return }
        currentCall = event.call
        publish(status: .ringing)
    }

    private func handleTerminalEvent(_ event: SocketCallEvent) {
        guard isCurrentCall(event.call) else { return }
        let reason = event.reason ?? event.call.endReason ?? terminalReason(for: event.call.status)
        finishLocally(reason: reason)
    }

    private func handleBusy(_ event: SocketCallBusyEvent) {
        guard currentCall?.chatId == event.chatId || currentCall == nil else { return }
        let message = event.message ?? "User is already in a call."
        publishBusy(message)
        cleanup(shouldDismissUI: false)
    }

    private func preparePeerConnection() async throws {
        if peerConnection != nil { return }
        debug("preparing peer connection", callId: currentCall?.callId)

        guard NativeCallConfig.webRTCEnabled else {
            throw VoiceCallServiceError.engineUnavailable
        }

        let factory = try makePeerConnectionFactory()
        let peer = try makePeerConnection(factory: factory)
        let audioTrack = try makeLocalAudioTrack(factory: factory, peerConnection: peer)
        audioTrack.isEnabled = !isMuted
        localAudioTrack = audioTrack
        peerConnection = peer
        debug("local audio track added", callId: currentCall?.callId)
    }

    private func makePeerConnectionFactory() throws -> RTCPeerConnectionFactory {
        VoiceCallDiagnostics.record(.beforeWebRTCFactoryCreate)
        if let factory {
            VoiceCallDiagnostics.record(.afterWebRTCFactoryCreate)
            return factory
        }

        guard NSClassFromString("RTCPeerConnectionFactory") != nil else {
            throw VoiceCallServiceError.engineUnavailable
        }

        RTCInitializeSSL()
        let createdFactory = RTCPeerConnectionFactory(encoderFactory: nil, decoderFactory: nil)
        factory = createdFactory
        VoiceCallDiagnostics.record(.afterWebRTCFactoryCreate)
        debug("WebRTC factory created", callId: currentCall?.callId)
        return createdFactory
    }

    private func makePeerConnection(factory: RTCPeerConnectionFactory) throws -> RTCPeerConnection {
        VoiceCallDiagnostics.record(.beforePeerConnectionCreate)

        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
        ]
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )
        guard let peer = factory.peerConnection(with: configuration, constraints: constraints, delegate: self) else {
            throw VoiceCallServiceError.engineUnavailable
        }
        VoiceCallDiagnostics.record(.afterPeerConnectionCreate)
        debug("peer connection created", callId: currentCall?.callId)
        return peer
    }

    private func makeLocalAudioTrack(
        factory: RTCPeerConnectionFactory,
        peerConnection: RTCPeerConnection
    ) throws -> RTCAudioTrack {
        VoiceCallDiagnostics.record(.beforeLocalAudioTrackCreate)
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio-\(UUID().uuidString)")
        guard peerConnection.add(audioTrack, streamIds: ["chitchat-audio"]) != nil else {
            throw VoiceCallServiceError.engineUnavailable
        }
        VoiceCallDiagnostics.record(.afterLocalAudioTrackCreate)
        return audioTrack
    }

    private func createOffer() async throws -> [String: Any] {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil
        )
        let offer = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RTCSessionDescription, Error>) in
            peerConnection.offer(for: constraints) { description, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let description {
                    continuation.resume(returning: description)
                } else {
                    continuation.resume(throwing: VoiceCallServiceError.invalidSignal)
                }
            }
        }
        try await setLocalDescription(offer)
        return Self.signal(from: offer)
    }

    private func createAnswer() async throws -> [String: Any] {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil
        )
        let answer = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RTCSessionDescription, Error>) in
            peerConnection.answer(for: constraints) { description, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let description {
                    continuation.resume(returning: description)
                } else {
                    continuation.resume(throwing: VoiceCallServiceError.invalidSignal)
                }
            }
        }
        try await setLocalDescription(answer)
        return Self.signal(from: answer)
    }

    private func setLocalDescription(_ description: RTCSessionDescription) async throws {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setLocalDescription(description) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func applyRemoteDescription(signal: [String: Any]) async throws {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        let description = try Self.sessionDescription(from: signal)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setRemoteDescription(description) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func addRemoteIceCandidate(_ signal: [String: Any]) {
        guard let peerConnection, let candidate = Self.iceCandidate(from: signal) else {
            queuedRemoteIceCandidates.append(signal)
            return
        }
        peerConnection.add(candidate, completionHandler: { [weak self] error in
            if error != nil {
                self?.debug("remote ice failed", callId: self?.currentCall?.callId)
            }
        })
    }

    private func flushRemoteIceCandidates() {
        guard !queuedRemoteIceCandidates.isEmpty else { return }
        let candidates = queuedRemoteIceCandidates
        queuedRemoteIceCandidates.removeAll()
        candidates.forEach(addRemoteIceCandidate)
    }

    private func flushLocalIceCandidates() {
        guard let callId = currentCall?.callId, !queuedLocalIceCandidates.isEmpty else { return }
        let candidates = queuedLocalIceCandidates
        queuedLocalIceCandidates.removeAll()
        candidates.forEach { candidate in
            Task { try? await SocketService.shared.sendIceCandidate(callId: callId, candidate: candidate) }
        }
    }

    private func sendIceCandidate(_ candidate: [String: Any]) {
        guard let callId = currentCall?.callId else {
            queuedLocalIceCandidates.append(candidate)
            return
        }
        Task { try? await SocketService.shared.sendIceCandidate(callId: callId, candidate: candidate) }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        guard let callId = currentCall?.callId else { return }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: true) { _ in
            Task { try? await SocketService.shared.sendCallHeartbeat(callId: callId) }
        }
        Task { try? await SocketService.shared.sendCallHeartbeat(callId: callId) }
    }

    private func publishCurrentState() {
        if callConnectedAt != nil {
            publish(status: .active)
        } else if direction == .incoming {
            publish(status: .incoming)
        } else if currentCall != nil {
            publish(status: .ringing)
        } else {
            publish(status: .outgoing)
        }
    }

    private func publish(
        status: VoiceCallPresentationStatus,
        callId: String? = nil,
        chatId: String? = nil,
        callerId: String? = nil,
        calleeId: String? = nil
    ) {
        guard let participant = currentParticipant else { return }
        let call = currentCall
        let state = VoiceCallPresentationState(
            direction: direction,
            status: status,
            callId: callId ?? call?.callId,
            chatId: chatId ?? call?.chatId ?? "",
            callerId: callerId ?? call?.callerId ?? currentUser?.id ?? "",
            calleeId: calleeId ?? call?.calleeId ?? participant.id,
            participant: participant,
            startedAt: callStartedAt,
            connectedAt: callConnectedAt,
            isMuted: isMuted,
            isSpeakerOn: isSpeakerOn
        )
        callViewController?.render(state)
    }

    private func publishFailure(_ message: String) {
        publish(status: .failed(message))
    }

    private func publishBusy(_ message: String) {
        publish(status: .busy(message))
    }

    private func presentCallUI(from presenter: UIViewController, completion: @escaping () -> Void) {
        if callViewController != nil {
            DispatchQueue.main.async(execute: completion)
            return
        }
        assert(Thread.isMainThread)
        let controller = VoiceCallViewController(service: self)
        controller.modalPresentationStyle = .fullScreen
        controller.onDismissed = { [weak self] in
            self?.callViewController = nil
        }
        controller.loadViewIfNeeded()
        callViewController = controller
        let top = UIApplication.shared.topMostViewController() ?? presenter.presentedViewController ?? presenter
        top.present(controller, animated: true, completion: completion)
    }

    private func handleStartupFailure(_ error: Error, presenter: UIViewController?) {
        isStartingCall = false
        let publicMessage = "Could not start call. Please try again."
        publishFailure(publicMessage)
        cleanup(shouldDismissUI: false)

        let errorName: String
        if let callError = error as? VoiceCallServiceError {
            errorName = callError.diagnosticName
        } else {
            errorName = String(describing: type(of: error))
        }
        debug("startup failed step=\(VoiceCallDiagnostics.lastStartupStep) error=\(errorName)")

        var alertMessage = publicMessage
        #if DEBUG
        alertMessage += "\nStep: \(VoiceCallDiagnostics.lastStartupStep)\nError: \(errorName)"
        #endif

        let alertPresenter = callViewController
            ?? UIApplication.shared.topMostViewController()
            ?? presenter
        if let alertPresenter, alertPresenter.presentedViewController == nil {
            alertPresenter.presentVoiceCallAlert(message: alertMessage)
        }
    }

    private func finishLocally(reason: String?) {
        publish(status: .ended(reason))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.cleanup(shouldDismissUI: true)
        }
    }

    private func cleanup(shouldDismissUI: Bool) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        currentCall = nil
        pendingOffer = nil
        queuedLocalIceCandidates.removeAll()
        queuedRemoteIceCandidates.removeAll()
        currentParticipant = nil
        callConnectedAt = nil
        isMuted = false
        isSpeakerOn = false
        isStartingCall = false
        audioSession.stop()
        if shouldDismissUI, let controller = callViewController {
            controller.dismiss(animated: true)
            callViewController = nil
        }
    }

    private func isCurrentCall(_ call: VoiceCall) -> Bool {
        currentCall?.callId == call.callId
    }

    private func terminalReason(for status: VoiceCallStatus) -> String? {
        switch status {
        case .rejected:
            return "Call rejected"
        case .missed:
            return "Missed call"
        case .cancelled:
            return "Call cancelled"
        case .ended:
            return "Call ended"
        case .ringing, .active:
            return nil
        }
    }

    private static func participant(from chat: Chat, viewerUserId: String) -> VoiceCallParticipant? {
        guard let other = chat.otherParticipant(viewerUserId: viewerUserId) else { return nil }
        return participant(from: chat, userId: other.userId)
    }

    private static func participant(from chat: Chat, userId: String) -> VoiceCallParticipant? {
        guard let member = chat.members.first(where: { $0.userId == userId }) else { return nil }
        return VoiceCallParticipant(
            id: member.userId,
            name: member.user?.name ?? "ChitChat user",
            avatarUrl: member.user?.avatarUrl ?? ""
        )
    }

    private static func signal(from description: RTCSessionDescription) -> [String: Any] {
        [
            "type": description.type.chitchatString,
            "sdp": description.sdp
        ]
    }

    private static func sessionDescription(from signal: [String: Any]) throws -> RTCSessionDescription {
        guard let sdp = signal["sdp"] as? String, !sdp.isEmpty else {
            throw VoiceCallServiceError.invalidSignal
        }
        let typeValue = (signal["type"] as? String) ?? "offer"
        return RTCSessionDescription(type: RTCSdpType(chitchatString: typeValue), sdp: sdp)
    }

    private static func iceCandidate(from signal: [String: Any]) -> RTCIceCandidate? {
        guard let candidate = signal["candidate"] as? String, !candidate.isEmpty else { return nil }
        let mid = signal["sdpMid"] as? String
        let mLineIndex: Int32
        if let value = signal["sdpMLineIndex"] as? Int {
            mLineIndex = Int32(value)
        } else if let value = signal["sdpMLineIndex"] as? Double {
            mLineIndex = Int32(value)
        } else {
            mLineIndex = 0
        }
        return RTCIceCandidate(sdp: candidate, sdpMLineIndex: mLineIndex, sdpMid: mid)
    }

    private func debug(_ message: String, callId: String? = nil) {
        #if DEBUG
        if let callId {
            print("[native-call] \(message) callId=\(callId)")
        } else {
            print("[native-call] \(message)")
        }
        #endif
    }
}

extension VoiceCallService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch newState {
            case .connected, .completed:
                self.callConnectedAt = self.callConnectedAt ?? Date()
                self.publish(status: .active)
                self.startHeartbeat()
            case .failed:
                self.endActiveCall(reason: "ice_failed")
            case .disconnected:
                self.debug("ice disconnected", callId: self.currentCall?.callId)
            default:
                break
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch newState {
            case .connected:
                self.callConnectedAt = self.callConnectedAt ?? Date()
                self.publish(status: .active)
                self.startHeartbeat()
            case .failed:
                self.endActiveCall(reason: "connection_failed")
            default:
                break
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let payload: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMLineIndex": Int(candidate.sdpMLineIndex),
            "sdpMid": candidate.sdpMid ?? ""
        ]
        DispatchQueue.main.async { [weak self] in
            self?.sendIceCandidate(payload)
        }
    }
}

private extension RTCSdpType {
    init(chitchatString: String) {
        switch chitchatString.lowercased() {
        case "answer":
            self = .answer
        case "pranswer":
            self = .prAnswer
        case "rollback":
            self = .rollback
        default:
            self = .offer
        }
    }

    var chitchatString: String {
        switch self {
        case .offer:
            return "offer"
        case .prAnswer:
            return "pranswer"
        case .answer:
            return "answer"
        case .rollback:
            return "rollback"
        @unknown default:
            return "offer"
        }
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController()
    }
}

private extension UIViewController {
    func topMostPresentedViewController() -> UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController()
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostPresentedViewController() ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostPresentedViewController() ?? tab
        }
        return self
    }

    func presentVoiceCallAlert(message: String) {
        let alert = UIAlertController(title: "ChitChat", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
