import AVFoundation
import Foundation
import WebRTC

enum CallAudioSessionError: LocalizedError {
    case microphonePermissionDenied
    case routeChangeFailed
    case activationFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required for voice calls."
        case .routeChangeFailed:
            return "Unable to change audio route."
        case .activationFailed:
            return "Unable to start call audio."
        }
    }
}

final class CallAudioSession {
    static let shared = CallAudioSession()

    private let permissionSession = AVAudioSession.sharedInstance()
    private lazy var rtcAudioSession = RTCAudioSession.sharedInstance()
    private(set) var isSpeakerEnabled = false
    private(set) var isActive = false

    private init() {}

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            switch permissionSession.recordPermission {
            case .granted:
                debug("microphone permission granted")
                continuation.resume(returning: true)
            case .denied:
                debug("microphone permission denied")
                continuation.resume(returning: false)
            case .undetermined:
                debug("requesting microphone permission")
                permissionSession.requestRecordPermission { [weak self] granted in
                    self?.debug("microphone permission result granted=\(granted)")
                    continuation.resume(returning: granted)
                }
            @unknown default:
                debug("microphone permission unknown")
                continuation.resume(returning: false)
            }
        }
    }

    func start() throws {
        guard !isActive else { return }
        rtcAudioSession.lockForConfiguration()
        defer { rtcAudioSession.unlockForConfiguration() }

        do {
            try rtcAudioSession.setCategory(.playAndRecord)
            try rtcAudioSession.setMode(.voiceChat)
            try rtcAudioSession.overrideOutputAudioPort(.none)
            try rtcAudioSession.setActive(true)
        } catch {
            isActive = false
            isSpeakerEnabled = false
            debug("audio session activation failed")
            throw CallAudioSessionError.activationFailed
        }

        isActive = true
        isSpeakerEnabled = false
    }

    func setSpeakerEnabled(_ enabled: Bool) throws {
        guard isActive else {
            isSpeakerEnabled = enabled
            return
        }
        rtcAudioSession.lockForConfiguration()
        defer { rtcAudioSession.unlockForConfiguration() }

        do {
            try rtcAudioSession.setCategory(.playAndRecord)
            try rtcAudioSession.overrideOutputAudioPort(enabled ? .speaker : .none)
            isSpeakerEnabled = enabled
        } catch {
            debug("audio route change failed")
            throw CallAudioSessionError.routeChangeFailed
        }
    }

    func stop() {
        guard isActive else {
            isSpeakerEnabled = false
            return
        }
        rtcAudioSession.lockForConfiguration()
        defer { rtcAudioSession.unlockForConfiguration() }

        do {
            try rtcAudioSession.overrideOutputAudioPort(.none)
            try rtcAudioSession.setActive(false)
        } catch {
            debug("audio session cleanup failed")
        }
        isSpeakerEnabled = false
        isActive = false
    }

    private func debug(_ message: String) {
        #if DEBUG
        print("[native-call-audio] \(message)")
        #endif
    }
}
