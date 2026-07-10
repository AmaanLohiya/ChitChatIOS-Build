import Foundation

enum NativeCallConfig {
    static let voiceCallsEnabled = true
    // Keep the call UI available while isolating the native M137 startup crash.
    static let webRTCEnabled = false
}
