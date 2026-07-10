import AVFoundation
import Foundation

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

    private let session = AVAudioSession.sharedInstance()
    private(set) var isSpeakerEnabled = false
    private(set) var isActive = false

    private init() {}

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            switch session.recordPermission {
            case .granted:
                debug("microphone permission granted")
                continuation.resume(returning: true)
            case .denied:
                debug("microphone permission denied")
                continuation.resume(returning: false)
            case .undetermined:
                debug("requesting microphone permission")
                session.requestRecordPermission { [weak self] granted in
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
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: [])
            isActive = true
            isSpeakerEnabled = false
            try session.overrideOutputAudioPort(.none)
        } catch {
            isActive = false
            isSpeakerEnabled = false
            debug("audio session activation failed")
            throw CallAudioSessionError.activationFailed
        }
    }

    func setSpeakerEnabled(_ enabled: Bool) throws {
        guard isActive else {
            isSpeakerEnabled = enabled
            return
        }
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
            isSpeakerEnabled = enabled
        } catch {
            debug("audio route change failed")
            throw CallAudioSessionError.routeChangeFailed
        }
    }

    func stop() {
        do {
            try session.overrideOutputAudioPort(.none)
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
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
