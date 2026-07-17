import Foundation
import UIKit
import AVFoundation
import CoreMedia
import WebRTC

private enum VoiceCallServiceError: LocalizedError, Equatable {
    case groupCallsUnsupported
    case missingParticipant
    case alreadyInCall
    case socketUnavailable
    case invalidSignal
    case microphonePermissionDenied
    case cameraPermissionDenied
    case cameraUnavailable
    case videoCaptureFailed
    case peerConnectionUnavailable
    case presentationUnavailable

    var errorDescription: String? {
        switch self {
        case .groupCallsUnsupported:
            return "Group calls are available later."
        case .missingParticipant:
            return "Unable to find the person for this call."
        case .alreadyInCall:
            return "You are already in a call."
        case .socketUnavailable:
            return "Realtime connection is unavailable."
        case .invalidSignal:
            return "Call setup data was invalid."
        case .microphonePermissionDenied:
            return "Microphone permission is required for calls."
        case .cameraPermissionDenied:
            return "Camera permission is required for video calls."
        case .cameraUnavailable:
            return "Camera is unavailable on this device."
        case .videoCaptureFailed:
            return "Could not start the camera."
        case .peerConnectionUnavailable:
            return "Could not create the call connection."
        case .presentationUnavailable:
            return "The call screen could not be presented."
        }
    }
}

private struct CameraCaptureConfiguration {
    let device: AVCaptureDevice
    let format: AVCaptureDevice.Format
    let fps: Int
}

final class VoiceCallService: NSObject {
    static let shared = VoiceCallService()

    // Swift static initialization is lazy and thread-safe, so SSL is initialized once.
    private static let webRTCGlobalInitialization: Void = {
        RTCInitializeSSL()
    }()

    private let chatService = ChatService()
    private let audioSession = CallAudioSession.shared
    private var factory: RTCPeerConnectionFactory?
    private var observers: [NSObjectProtocol] = []

    private var currentUser: User?
    private var currentCall: VoiceCall?
    private var currentParticipant: VoiceCallParticipant?
    private var direction: VoiceCallDirection = .outgoing
    private var activeCallType: VoiceCallType = .voice
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoSource: RTCVideoSource?
    private var cameraCapturer: RTCCameraVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private weak var localVideoRenderer: RTCVideoRenderer?
    private weak var remoteVideoRenderer: RTCVideoRenderer?
    private var pendingOffer: [String: Any]?
    private var queuedLocalIceCandidates: [[String: Any]] = []
    private var queuedRemoteIceCandidates: [[String: Any]] = []
    private var heartbeatTimer: Timer?
    private var callStartedAt = Date()
    private var callConnectedAt: Date?
    private var isMuted = false
    private var isSpeakerOn = false
    private var isCameraEnabled = true
    private var isUsingFrontCamera = true
    private var isCameraCapturing = false
    private var isSwitchingCamera = false
    private var isStartingCall = false
    private var startupID: UUID?
    private weak var callViewController: VoiceCallViewController?
    private weak var videoCallViewController: VideoCallViewController?

    private override init() {
        super.init()
        audioSession.onRouteChanged = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.handleAudioRouteChanged(snapshot)
            }
        }
        observeSocketCalls()
    }

    func configure(currentUser: User) {
        self.currentUser = currentUser
    }

    func resetForSignOut() {
        cleanup(shouldDismissUI: true)
    }

    func startOutgoingVoiceCall(chat: Chat, currentUser: User, presenter: UIViewController) {
        startOutgoingCall(type: .voice, chat: chat, currentUser: currentUser, presenter: presenter)
    }

    func startOutgoingVideoCall(chat: Chat, currentUser: User, presenter: UIViewController) {
        startOutgoingCall(type: .video, chat: chat, currentUser: currentUser, presenter: presenter)
    }

    private func startOutgoingCall(
        type: VoiceCallType,
        chat: Chat,
        currentUser: User,
        presenter: UIViewController
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak presenter] in
                guard let presenter else { return }
                self.startOutgoingCall(type: type, chat: chat, currentUser: currentUser, presenter: presenter)
            }
            return
        }
        debug("\(type.rawValue) call button tapped")
        guard chat.type == .direct else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.groupCallsUnsupported.localizedDescription)
            return
        }
        guard peerConnection == nil, currentCall == nil, !isStartingCall else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.alreadyInCall.localizedDescription)
            return
        }
        guard let participant = Self.participant(from: chat, viewerUserId: currentUser.id) else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.missingParticipant.localizedDescription)
            return
        }
        debug("callee resolved id=\(participant.id)")
        self.currentUser = currentUser

        guard SocketService.shared.isConnected else {
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.socketUnavailable.localizedDescription)
            return
        }
        debug("socket connected for \(type.rawValue) call start")

        let startupID = UUID()
        self.startupID = startupID
        isStartingCall = true
        Task { @MainActor [weak self, weak presenter] in
            guard let self else { return }
            let hasMicrophonePermission = await self.audioSession.requestMicrophonePermission()
            guard self.startupID == startupID else { return }
            guard let presenter else {
                self.isStartingCall = false
                self.startupID = nil
                return
            }
            self.debug("microphone permission state granted=\(hasMicrophonePermission)")
            guard hasMicrophonePermission else {
                self.isStartingCall = false
                self.startupID = nil
                presenter.presentVoiceCallAlert(message: VoiceCallServiceError.microphonePermissionDenied.localizedDescription)
                return
            }
            if type == .video {
                let hasCameraPermission = await self.requestCameraPermission()
                guard self.startupID == startupID else { return }
                self.debug("camera permission state granted=\(hasCameraPermission)")
                guard hasCameraPermission else {
                    self.isStartingCall = false
                    self.startupID = nil
                    presenter.presentVoiceCallAlert(message: VoiceCallServiceError.cameraPermissionDenied.localizedDescription)
                    return
                }
            }
            self.beginOutgoingCall(
                type: type,
                chat: chat,
                currentUser: currentUser,
                participant: participant,
                presenter: presenter,
                startupID: startupID
            )
        }
    }

    private func beginOutgoingCall(
        type: VoiceCallType,
        chat: Chat,
        currentUser: User,
        participant: VoiceCallParticipant,
        presenter: UIViewController,
        startupID: UUID
    ) {
        guard self.startupID == startupID, peerConnection == nil, currentCall == nil else {
            isStartingCall = false
            self.startupID = nil
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.alreadyInCall.localizedDescription)
            return
        }
        guard SocketService.shared.isConnected else {
            isStartingCall = false
            self.startupID = nil
            presenter.presentVoiceCallAlert(message: VoiceCallServiceError.socketUnavailable.localizedDescription)
            return
        }
        self.currentUser = currentUser
        self.currentParticipant = participant
        self.direction = .outgoing
        self.activeCallType = type
        self.callStartedAt = Date()
        self.callConnectedAt = nil
        self.isMuted = false
        self.isSpeakerOn = false
        self.isCameraEnabled = true
        self.isUsingFrontCamera = true
        presentCallUI(from: presenter) { [weak self, weak presenter] presented in
            guard let self else { return }
            guard self.startupID == startupID,
                  self.isStartingCall,
                  self.currentParticipant?.id == participant.id else { return }
            guard let presenter else {
                self.isStartingCall = false
                self.startupID = nil
                return
            }
            guard presented else {
                self.handleStartupFailure(VoiceCallServiceError.presentationUnavailable, presenter: presenter)
                return
            }
            self.startOutgoingEngine(
                type: type,
                chat: chat,
                participant: participant,
                presenter: presenter,
                startupID: startupID
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
        type: VoiceCallType,
        chat: Chat,
        participant: VoiceCallParticipant,
        presenter: UIViewController,
        startupID: UUID
    ) {
        Task { @MainActor [weak self, weak presenter] in
            guard let self else { return }
            do {
                guard self.startupID == startupID else { return }
                try await self.preparePeerConnection(for: type)
                guard self.startupID == startupID else { return }
                try self.audioSession.start()
                self.applyInitialAudioRoute(for: type)
                let offer = try await self.createOffer(for: type)
                guard self.startupID == startupID else { return }
                let call = try await SocketService.shared.sendCallOffer(
                    chatId: chat.id,
                    calleeId: participant.id,
                    type: type,
                    offer: offer
                )
                guard self.startupID == startupID else {
                    Task { try? await SocketService.shared.sendCallCancel(callId: call.callId, reason: "cancelled") }
                    return
                }
                self.currentCall = call
                self.activeCallType = call.type
                self.isStartingCall = false
                self.startupID = nil
                self.publish(status: .ringing)
                self.flushLocalIceCandidates()
                self.debug("outgoing call emitted", callId: call.callId)
            } catch {
                guard self.startupID == startupID else { return }
                self.debug("outgoing call failed", callId: self.currentCall?.callId)
                self.handleStartupFailure(error, presenter: presenter)
            }
        }
    }

    func acceptIncomingCall() {
        guard let call = currentCall, let offer = pendingOffer else { return }
        guard !isStartingCall, peerConnection == nil else { return }
        guard SocketService.shared.isConnected else {
            publishFailure(VoiceCallServiceError.socketUnavailable.localizedDescription)
            return
        }
        let startupID = UUID()
        self.startupID = startupID
        isStartingCall = true
        publish(status: .connecting)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let hasMicrophonePermission = await self.audioSession.requestMicrophonePermission()
                guard self.startupID == startupID else { return }
                self.debug("incoming microphone permission granted=\(hasMicrophonePermission)", callId: call.callId)
                guard hasMicrophonePermission else {
                    throw VoiceCallServiceError.microphonePermissionDenied
                }
                if call.type == .video {
                    let hasCameraPermission = await self.requestCameraPermission()
                    guard self.startupID == startupID else { return }
                    self.debug("incoming camera permission granted=\(hasCameraPermission)", callId: call.callId)
                    guard hasCameraPermission else {
                        throw VoiceCallServiceError.cameraPermissionDenied
                    }
                }
                try await self.preparePeerConnection(for: call.type)
                guard self.startupID == startupID else { return }
                try self.audioSession.start()
                self.applyInitialAudioRoute(for: call.type)
                try await self.applyRemoteDescription(signal: offer)
                let answer = try await self.createAnswer(for: call.type)
                guard self.startupID == startupID else { return }
                let answered = try await SocketService.shared.sendCallAnswer(callId: call.callId, answer: answer)
                guard self.startupID == startupID else {
                    Task { try? await SocketService.shared.sendCallEnd(callId: answered.callId, reason: "cancelled") }
                    return
                }
                self.currentCall = answered
                self.activeCallType = answered.type
                self.isStartingCall = false
                self.startupID = nil
                self.callConnectedAt = Date()
                self.publish(status: .active)
                self.flushLocalIceCandidates()
                self.flushRemoteIceCandidates()
                self.startHeartbeat()
            } catch {
                guard self.startupID == startupID else { return }
                self.debug("accept failed", callId: call.callId)
                let reason = (error as? VoiceCallServiceError) == .cameraPermissionDenied ? "permission_denied" : "accept_failed"
                Task { try? await SocketService.shared.sendCallEnd(callId: call.callId, reason: reason) }
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

    func availableAudioRoutes() -> [CallAudioRouteOption] {
        audioSession.availableRoutes()
    }

    func currentAudioRouteID() -> String {
        audioSession.currentRoute().id
    }

    func selectAudioRoute(_ route: CallAudioRouteOption) {
        do {
            try audioSession.selectRoute(route)
            isSpeakerOn = audioSession.currentRoute().kind == .speaker
            publishCurrentState()
        } catch {
            debug("audio route selection failed", callId: currentCall?.callId)
        }
    }

    func toggleCamera() {
        guard activeCallType == .video else { return }
        isCameraEnabled.toggle()
        localVideoTrack?.isEnabled = isCameraEnabled
        publishCurrentState()
    }

    func switchCamera() {
        guard activeCallType == .video,
              !isSwitchingCamera,
              let capturer = cameraCapturer else { return }
        isSwitchingCamera = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isSwitchingCamera = false
                self.publishCurrentState()
            }
            do {
                let capture = try Self.captureConfiguration(preferFrontCamera: !self.isUsingFrontCamera)
                try await self.startCapture(capturer: capturer, configuration: capture)
                self.isUsingFrontCamera = capture.device.position == .front
                self.isCameraCapturing = true
                self.debug("camera switched front=\(self.isUsingFrontCamera)", callId: self.currentCall?.callId)
            } catch {
                self.debug("camera switch failed", callId: self.currentCall?.callId)
            }
        }
    }

    func attachVideoRenderers(local: RTCVideoRenderer, remote: RTCVideoRenderer) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.attachVideoRenderers(local: local, remote: remote)
            }
            return
        }
        if let localVideoRenderer {
            localVideoTrack?.remove(localVideoRenderer)
        }
        if let remoteVideoRenderer {
            remoteVideoTrack?.remove(remoteVideoRenderer)
        }
        localVideoRenderer = local
        remoteVideoRenderer = remote
        localVideoTrack?.add(local)
        remoteVideoTrack?.add(remote)
        publishCurrentState()
    }

    func detachVideoRenderers(local: RTCVideoRenderer, remote: RTCVideoRenderer) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.detachVideoRenderers(local: local, remote: remote)
            }
            return
        }
        if let localVideoRenderer {
            localVideoTrack?.remove(localVideoRenderer)
            self.localVideoRenderer = nil
        }
        if let remoteVideoRenderer {
            remoteVideoTrack?.remove(remoteVideoRenderer)
            self.remoteVideoRenderer = nil
        }
        publishCurrentState()
    }

    private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }

    private func applyInitialAudioRoute(for type: VoiceCallType) {
        guard type == .video else { return }
        guard audioSession.currentRoute().kind == .receiver,
              let speaker = audioSession.availableRoutes().first(where: { $0.kind == .speaker }) else { return }
        do {
            try audioSession.selectRoute(speaker)
            isSpeakerOn = true
        } catch {
            debug("video speaker default failed", callId: currentCall?.callId)
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
            guard let self, self.currentCall != nil || self.isStartingCall || self.peerConnection != nil else { return }
            self.finishLocally(reason: "Connection lost")
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.activeCallType == .video, self.currentCall != nil || self.isStartingCall else { return }
            self.endActiveCall(reason: "backgrounded")
        })
    }

    private func handleIncomingOffer(_ event: SocketCallEvent) {
        let call = event.call
        guard let offer = event.offer else {
            debug("incoming offer missing signal", callId: call.callId)
            Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "invalid_signal") }
            return
        }
        guard currentCall == nil, peerConnection == nil, !isStartingCall else {
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
        activeCallType = call.type
        callStartedAt = Date()
        callConnectedAt = nil
        isMuted = false
        isSpeakerOn = false
        isCameraEnabled = true
        isUsingFrontCamera = true

        Task { [weak self] in
            let chat = try? await self?.chatService.getChat(id: call.chatId)
            let participant = chat.flatMap { Self.participant(from: $0, userId: call.callerId) }
                ?? VoiceCallParticipant(id: call.callerId, name: "ChitChat user", avatarUrl: "")
            await MainActor.run {
                guard let self else { return }
                guard self.currentCall?.callId == call.callId else { return }
                self.currentParticipant = participant
                guard let presenter = UIApplication.shared.topMostViewController() else {
                    Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "not_ready") }
                    self.cleanup(shouldDismissUI: false)
                    return
                }
                self.presentCallUI(from: presenter) { [weak self] presented in
                    guard let self, self.currentCall?.callId == call.callId else { return }
                    guard presented else {
                        Task { try? await SocketService.shared.sendCallReject(callId: call.callId, reason: "not_ready") }
                        self.cleanup(shouldDismissUI: false)
                        return
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
    }

    private func handleAnswer(_ event: SocketCallEvent) {
        guard isCurrentCall(event.call), let answer = event.answer else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.applyRemoteDescription(signal: answer)
                self.currentCall = event.call
                self.activeCallType = event.call.type
                self.callConnectedAt = Date()
                self.publish(status: .active)
                self.flushRemoteIceCandidates()
                self.startHeartbeat()
            } catch {
                self.endActiveCall(reason: "answer_failed")
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
        activeCallType = event.call.type
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

    private func preparePeerConnection(for type: VoiceCallType) async throws {
        if peerConnection != nil { return }
        debug("preparing peer connection", callId: currentCall?.callId)

        let factory = makePeerConnectionFactory()
        let peer = try makePeerConnection(factory: factory)
        let audioTrack = try makeLocalAudioTrack(factory: factory, peerConnection: peer)
        audioTrack.isEnabled = !isMuted
        localAudioTrack = audioTrack
        peerConnection = peer
        if type == .video {
            let videoTrack = try await makeLocalVideoTrack(factory: factory, peerConnection: peer)
            videoTrack.isEnabled = isCameraEnabled
            localVideoTrack = videoTrack
            if let localVideoRenderer {
                videoTrack.add(localVideoRenderer)
            }
            debug("local video track added", callId: currentCall?.callId)
        }
        debug("local audio track added", callId: currentCall?.callId)
    }

    private func makePeerConnectionFactory() -> RTCPeerConnectionFactory {
        if let factory {
            return factory
        }

        _ = Self.webRTCGlobalInitialization
        let createdFactory = RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
        factory = createdFactory
        debug("WebRTC factory created", callId: currentCall?.callId)
        return createdFactory
    }

    private func makePeerConnection(factory: RTCPeerConnectionFactory) throws -> RTCPeerConnection {
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
            throw VoiceCallServiceError.peerConnectionUnavailable
        }
        debug("peer connection created", callId: currentCall?.callId)
        return peer
    }

    private func makeLocalAudioTrack(
        factory: RTCPeerConnectionFactory,
        peerConnection: RTCPeerConnection
    ) throws -> RTCAudioTrack {
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio-\(UUID().uuidString)")
        guard peerConnection.add(audioTrack, streamIds: ["chitchat-audio"]) != nil else {
            throw VoiceCallServiceError.peerConnectionUnavailable
        }
        return audioTrack
    }

    private func makeLocalVideoTrack(
        factory: RTCPeerConnectionFactory,
        peerConnection: RTCPeerConnection
    ) async throws -> RTCVideoTrack {
        let videoSource = factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video-\(UUID().uuidString)")
        guard peerConnection.add(videoTrack, streamIds: ["chitchat-video"]) != nil else {
            throw VoiceCallServiceError.peerConnectionUnavailable
        }

        let capture = try Self.captureConfiguration(preferFrontCamera: isUsingFrontCamera)
        localVideoSource = videoSource
        cameraCapturer = capturer
        try await startCapture(capturer: capturer, configuration: capture)
        isUsingFrontCamera = capture.device.position == .front
        isCameraCapturing = true
        isCameraEnabled = true
        return videoTrack
    }

    private func startCapture(
        capturer: RTCCameraVideoCapturer,
        configuration: CameraCaptureConfiguration
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            capturer.startCapture(
                with: configuration.device,
                format: configuration.format,
                fps: configuration.fps
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func createOffer(for type: VoiceCallType) async throws -> [String: Any] {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: mediaConstraints(for: type),
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
        try await setLocalDescription(offer, on: peerConnection)
        return Self.signal(from: offer)
    }

    private func createAnswer(for type: VoiceCallType) async throws -> [String: Any] {
        guard let peerConnection else { throw VoiceCallServiceError.invalidSignal }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: mediaConstraints(for: type),
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
        try await setLocalDescription(answer, on: peerConnection)
        return Self.signal(from: answer)
    }

    private func mediaConstraints(for type: VoiceCallType) -> [String: String] {
        var constraints = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue]
        if type == .video {
            constraints[kRTCMediaConstraintsOfferToReceiveVideo] = kRTCMediaConstraintsValueTrue
        }
        return constraints
    }

    private func setLocalDescription(
        _ description: RTCSessionDescription,
        on peerConnection: RTCPeerConnection
    ) async throws {
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

    private func handleAudioRouteChanged(_ snapshot: CallAudioRouteSnapshot) {
        isSpeakerOn = snapshot.current.kind == .speaker
        guard currentParticipant != nil else { return }
        publishCurrentState()
    }

    private func setRemoteVideoTrack(_ track: RTCVideoTrack?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setRemoteVideoTrack(track)
            }
            return
        }
        if let remoteVideoRenderer {
            remoteVideoTrack?.remove(remoteVideoRenderer)
        }
        remoteVideoTrack = track
        if let track, let remoteVideoRenderer {
            track.add(remoteVideoRenderer)
        }
        publishCurrentState()
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
        let route = audioSession.currentRoute()
        isSpeakerOn = route.kind == .speaker
        let state = VoiceCallPresentationState(
            callType: activeCallType,
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
            isSpeakerOn: route.kind == .speaker,
            isCameraEnabled: isCameraEnabled,
            isUsingFrontCamera: isUsingFrontCamera,
            hasLocalVideo: localVideoTrack != nil && isCameraEnabled,
            hasRemoteVideo: remoteVideoTrack != nil,
            audioRouteName: route.title,
            audioRouteIconName: route.kind.iconName
        )
        callViewController?.render(state)
        videoCallViewController?.render(state)
    }

    private func publishFailure(_ message: String) {
        publish(status: .failed(message))
    }

    private func publishBusy(_ message: String) {
        publish(status: .busy(message))
    }

    private func presentCallUI(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak presenter] in
                guard let self, let presenter else {
                    completion(false)
                    return
                }
                self.presentCallUI(from: presenter, completion: completion)
            }
            return
        }

        if activeCallType == .video {
            if let controller = videoCallViewController {
                completion(controller.presentingViewController != nil || controller.viewIfLoaded?.window != nil)
                return
            }
        } else {
            if let controller = callViewController {
                completion(controller.presentingViewController != nil || controller.viewIfLoaded?.window != nil)
                return
            }
        }

        guard presenter.viewIfLoaded?.window != nil else {
            completion(false)
            return
        }
        let top = UIApplication.shared.topMostViewController() ?? presenter.topMostPresentedViewController()
        guard top.viewIfLoaded?.window != nil, !top.isBeingDismissed else {
            completion(false)
            return
        }

        let controller: UIViewController
        if activeCallType == .video {
            let videoController = VideoCallViewController(service: self)
            videoController.onDismissed = { [weak self] in
                self?.videoCallViewController = nil
            }
            videoCallViewController = videoController
            controller = videoController
        } else {
            let voiceController = VoiceCallViewController(service: self)
            voiceController.onDismissed = { [weak self] in
                self?.callViewController = nil
            }
            callViewController = voiceController
            controller = voiceController
        }
        controller.modalPresentationStyle = .fullScreen
        controller.loadViewIfNeeded()
        top.present(controller, animated: true) { [weak self, weak controller] in
            guard let self, let controller, self.isPresentedControllerCurrent(controller) else {
                completion(false)
                return
            }
            let presented = controller.presentingViewController != nil || controller.viewIfLoaded?.window != nil
            if !presented {
                self.clearPresentedController(controller)
            }
            completion(presented)
        }
    }

    private func isPresentedControllerCurrent(_ controller: UIViewController) -> Bool {
        if let voice = controller as? VoiceCallViewController {
            return callViewController === voice
        }
        if let video = controller as? VideoCallViewController {
            return videoCallViewController === video
        }
        return false
    }

    private func clearPresentedController(_ controller: UIViewController) {
        if let voice = controller as? VoiceCallViewController, callViewController === voice {
            callViewController = nil
        }
        if let video = controller as? VideoCallViewController, videoCallViewController === video {
            videoCallViewController = nil
        }
    }

    private func handleStartupFailure(_ error: Error, presenter: UIViewController?) {
        isStartingCall = false
        startupID = nil
        let publicMessage = "Could not start call. Please try again."
        publishFailure(publicMessage)
        cleanup(shouldDismissUI: false)

        debug("startup failed error=\(String(describing: type(of: error)))")

        let alertPresenter = callViewController
            ?? videoCallViewController
            ?? UIApplication.shared.topMostViewController()
            ?? presenter
        if let alertPresenter, alertPresenter.presentedViewController == nil {
            alertPresenter.presentVoiceCallAlert(message: publicMessage)
        }
    }

    private func finishLocally(reason: String?) {
        publish(status: .ended(reason))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.cleanup(shouldDismissUI: true)
        }
    }

    private func cleanup(shouldDismissUI: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.cleanup(shouldDismissUI: shouldDismissUI)
            }
            return
        }

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        localAudioTrack?.isEnabled = false
        localVideoTrack?.isEnabled = false
        if let localVideoRenderer {
            localVideoTrack?.remove(localVideoRenderer)
        }
        if let remoteVideoRenderer {
            remoteVideoTrack?.remove(remoteVideoRenderer)
        }
        cameraCapturer?.stopCapture()
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        localVideoTrack = nil
        localVideoSource = nil
        remoteVideoTrack = nil
        cameraCapturer = nil
        localVideoRenderer = nil
        remoteVideoRenderer = nil
        currentCall = nil
        pendingOffer = nil
        queuedLocalIceCandidates.removeAll()
        queuedRemoteIceCandidates.removeAll()
        currentParticipant = nil
        callConnectedAt = nil
        isMuted = false
        isSpeakerOn = false
        isCameraEnabled = true
        isUsingFrontCamera = true
        isCameraCapturing = false
        isSwitchingCamera = false
        activeCallType = .voice
        isStartingCall = false
        startupID = nil
        audioSession.stop()
        if shouldDismissUI, let controller = callViewController {
            controller.dismiss(animated: true)
            callViewController = nil
        }
        if shouldDismissUI, let controller = videoCallViewController {
            controller.dismiss(animated: true)
            videoCallViewController = nil
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

    private static func captureConfiguration(preferFrontCamera: Bool) throws -> CameraCaptureConfiguration {
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard !devices.isEmpty else { throw VoiceCallServiceError.cameraUnavailable }

        let preferredPosition: AVCaptureDevice.Position = preferFrontCamera ? .front : .back
        let fallbackPosition: AVCaptureDevice.Position = preferFrontCamera ? .back : .front
        let device = devices.first(where: { $0.position == preferredPosition })
            ?? devices.first(where: { $0.position == fallbackPosition })
            ?? devices[0]

        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        guard let format = formats.max(by: { lhs, rhs in
            score(format: lhs) < score(format: rhs)
        }) else {
            throw VoiceCallServiceError.cameraUnavailable
        }

        let maxFPS = format.videoSupportedFrameRateRanges
            .map { Int($0.maxFrameRate.rounded(.down)) }
            .filter { $0 > 0 }
            .max() ?? 15
        return CameraCaptureConfiguration(device: device, format: format, fps: min(maxFPS, 30))
    }

    private static func score(format: AVCaptureDevice.Format) -> Int {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        let maxDimensionPenalty = max(width - 1280, 0) + max(height - 720, 0)
        let fpsScore = format.videoSupportedFrameRateRanges
            .map { Int($0.maxFrameRate.rounded(.down)) }
            .max() ?? 0
        return (width * height) - (maxDimensionPenalty * 4) + fpsScore
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
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let track = stream.videoTracks.first {
            setRemoteVideoTrack(track)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        if let remoteVideoTrack, stream.videoTracks.contains(where: { $0.isEqual(remoteVideoTrack) }) {
            setRemoteVideoTrack(nil)
        }
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd rtpReceiver: RTCRtpReceiver,
        streams mediaStreams: [RTCMediaStream]
    ) {
        if let track = rtpReceiver.track as? RTCVideoTrack {
            setRemoteVideoTrack(track)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {
        if let remoteVideoTrack, let track = rtpReceiver.track as? RTCVideoTrack, track.isEqual(remoteVideoTrack) {
            setRemoteVideoTrack(nil)
        }
    }

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
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.presentVoiceCallAlert(message: message)
            }
            return
        }
        guard viewIfLoaded?.window != nil else { return }
        let presenter = topMostPresentedViewController()
        guard !(presenter is UIAlertController), !presenter.isBeingDismissed else { return }
        let alert = UIAlertController(title: "ChitChat", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
