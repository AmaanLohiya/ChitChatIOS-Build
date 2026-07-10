import Foundation

enum VoiceCallStartupStep: String {
    case tapReceived = "tap_received"
    case chatValidated = "chat_validated"
    case calleeResolved = "callee_resolved"
    case sessionChecked = "session_checked"
    case microphonePermissionRequested = "microphone_permission_requested"
    case microphonePermissionGranted = "microphone_permission_granted"
    case callUIPresented = "call_ui_presented"
    case beforeAudioSessionStart = "before_audio_session_start"
    case afterAudioSessionStart = "after_audio_session_start"
    case beforeWebRTCFactoryCreate = "before_webrtc_factory_create"
    case afterWebRTCFactoryCreate = "after_webrtc_factory_create"
    case beforePeerConnectionCreate = "before_peer_connection_create"
    case afterPeerConnectionCreate = "after_peer_connection_create"
    case beforeLocalAudioTrackCreate = "before_local_audio_track_create"
    case afterLocalAudioTrackCreate = "after_local_audio_track_create"
    case beforeOfferCreate = "before_offer_create"
    case afterOfferCreate = "after_offer_create"
    case beforeSocketCallOffer = "before_socket_call_offer"
    case afterSocketCallOffer = "after_socket_call_offer"
}

enum VoiceCallDiagnostics {
    static let defaultsKey = "lastVoiceCallStartupStep"

    static var lastStartupStep: String {
        UserDefaults.standard.string(forKey: defaultsKey) ?? "not_started"
    }

    static func record(_ step: VoiceCallStartupStep) {
        UserDefaults.standard.set(step.rawValue, forKey: defaultsKey)
        _ = UserDefaults.standard.synchronize()

        #if DEBUG
        print("[native-call-startup] step=\(step.rawValue)")
        #endif
    }
}
