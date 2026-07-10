import AVFoundation
import Foundation
import WebRTC

enum CallAudioRouteKind: String, Equatable {
    case receiver
    case speaker
    case wired
    case bluetooth
    case usb
    case car
    case external

    var defaultTitle: String {
        switch self {
        case .receiver:
            return "iPhone"
        case .speaker:
            return "Speaker"
        case .wired:
            return "Wired Headset"
        case .bluetooth:
            return "Bluetooth Headset"
        case .usb:
            return "USB Audio"
        case .car:
            return "Car Audio"
        case .external:
            return "Audio Device"
        }
    }

    var iconName: String {
        switch self {
        case .receiver:
            return "iphone"
        case .speaker:
            return "speaker.wave.2.fill"
        case .wired, .bluetooth, .usb, .car, .external:
            return "headphones"
        }
    }
}

struct CallAudioRouteOption: Equatable {
    let id: String
    let kind: CallAudioRouteKind
    let title: String
    let portUID: String?
    let portTypeRawValue: String?
    let hasInput: Bool
}

struct CallAudioRouteSnapshot: Equatable {
    let current: CallAudioRouteOption
    let availableRoutes: [CallAudioRouteOption]
}

final class CallAudioRouteManager {
    static let shared = CallAudioRouteManager()

    private let session = AVAudioSession.sharedInstance()
    private lazy var rtcAudioSession = RTCAudioSession.sharedInstance()
    private var routeObserver: NSObjectProtocol?
    private var userSelectedRouteID: String?

    var onRouteChanged: ((CallAudioRouteSnapshot) -> Void)?

    private init() {}

    var snapshot: CallAudioRouteSnapshot {
        makeSnapshot()
    }

    func startObserving() {
        guard routeObserver == nil else {
            notifyRouteChanged()
            return
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        notifyRouteChanged()
    }

    func stopObserving() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        userSelectedRouteID = nil
    }

    func resetToReceiver() {
        do {
            rtcAudioSession.lockForConfiguration()
            defer { rtcAudioSession.unlockForConfiguration() }

            try session.setPreferredInput(builtInMicrophone())
            try rtcAudioSession.overrideOutputAudioPort(.none)
        } catch {
            debug("receiver reset failed")
        }
        userSelectedRouteID = receiverOption.id
        notifyRouteChanged()
    }

    func select(route: CallAudioRouteOption) throws {
        do {
            rtcAudioSession.lockForConfiguration()
            defer { rtcAudioSession.unlockForConfiguration() }

            switch route.kind {
            case .speaker:
                try session.setPreferredInput(builtInMicrophone())
                try rtcAudioSession.overrideOutputAudioPort(.speaker)
            case .receiver:
                try session.setPreferredInput(builtInMicrophone())
                try rtcAudioSession.overrideOutputAudioPort(.none)
            case .wired, .bluetooth, .usb, .car, .external:
                try rtcAudioSession.overrideOutputAudioPort(.none)
                if let input = inputPort(for: route) {
                    try session.setPreferredInput(input)
                } else if route.kind == .wired {
                    try session.setPreferredInput(builtInMicrophone())
                }
            }
        }

        userSelectedRouteID = route.id
        notifyRouteChanged()
    }

    private func handleRouteChange(_ notification: Notification) {
        let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
        debug("route changed reason=\(String(describing: reason))")

        let routes = availableRouteOptions()
        if let selected = userSelectedRouteID, !routes.contains(where: { $0.id == selected }) {
            userSelectedRouteID = nil
            resetToReceiver()
            return
        }

        switch reason {
        case .newDeviceAvailable?:
            if userSelectedRouteID == nil, let external = preferredExternalRoute(from: routes) {
                try? select(route: external)
                return
            }
        case .oldDeviceUnavailable?:
            if snapshot.current.kind != .receiver {
                resetToReceiver()
                return
            }
        default:
            break
        }

        notifyRouteChanged()
    }

    private func notifyRouteChanged() {
        onRouteChanged?(makeSnapshot())
    }

    private func makeSnapshot() -> CallAudioRouteSnapshot {
        let routes = availableRouteOptions()
        let current = currentRouteOption(matching: routes)
        return CallAudioRouteSnapshot(current: current, availableRoutes: routes)
    }

    private func availableRouteOptions() -> [CallAudioRouteOption] {
        var routes: [CallAudioRouteOption] = [receiverOption, speakerOption]
        var seen = Set(routes.map(\.id))

        for input in session.availableInputs ?? [] {
            guard let route = routeOption(for: input) else { continue }
            if seen.insert(route.id).inserted {
                routes.append(route)
            }
        }

        for output in session.currentRoute.outputs {
            guard let route = routeOption(for: output, hasInput: false) else { continue }
            if seen.insert(route.id).inserted {
                routes.append(route)
            }
        }

        return routes
    }

    private func currentRouteOption(matching routes: [CallAudioRouteOption]) -> CallAudioRouteOption {
        guard let output = session.currentRoute.outputs.first else {
            return receiverOption
        }
        let outputRoute = routeOption(for: output, hasInput: false) ?? receiverOption
        if let match = routes.first(where: { $0.portUID == outputRoute.portUID && $0.kind == outputRoute.kind }) {
            return match
        }
        if let selected = userSelectedRouteID, let match = routes.first(where: { $0.id == selected }) {
            return match
        }
        if let match = routes.first(where: { $0.kind == outputRoute.kind }) {
            return match
        }
        return outputRoute
    }

    private func routeOption(for port: AVAudioSessionPortDescription, hasInput: Bool = true) -> CallAudioRouteOption? {
        let kind = kind(for: port.portType)
        if !hasInput {
            switch kind {
            case .receiver:
                return receiverOption
            case .speaker:
                return speakerOption
            case .wired, .bluetooth, .usb, .car, .external:
                break
            }
        }
        guard kind != .receiver && kind != .speaker || !hasInput else { return nil }
        let title = title(for: port, kind: kind)
        return CallAudioRouteOption(
            id: "\(kind.rawValue):\(port.uid)",
            kind: kind,
            title: title,
            portUID: port.uid,
            portTypeRawValue: port.portType.rawValue,
            hasInput: hasInput
        )
    }

    private func inputPort(for route: CallAudioRouteOption) -> AVAudioSessionPortDescription? {
        guard let portUID = route.portUID else { return nil }
        return session.availableInputs?.first { input in
            input.uid == portUID || input.portType.rawValue == route.portTypeRawValue
        }
    }

    private func preferredExternalRoute(from routes: [CallAudioRouteOption]) -> CallAudioRouteOption? {
        routes.first { route in
            switch route.kind {
            case .wired, .bluetooth, .usb, .car, .external:
                return true
            case .receiver, .speaker:
                return false
            }
        }
    }

    private func builtInMicrophone() -> AVAudioSessionPortDescription? {
        session.availableInputs?.first { $0.portType == .builtInMic }
    }

    private var receiverOption: CallAudioRouteOption {
        CallAudioRouteOption(
            id: "receiver",
            kind: .receiver,
            title: CallAudioRouteKind.receiver.defaultTitle,
            portUID: nil,
            portTypeRawValue: AVAudioSession.Port.builtInReceiver.rawValue,
            hasInput: false
        )
    }

    private var speakerOption: CallAudioRouteOption {
        CallAudioRouteOption(
            id: "speaker",
            kind: .speaker,
            title: CallAudioRouteKind.speaker.defaultTitle,
            portUID: nil,
            portTypeRawValue: AVAudioSession.Port.builtInSpeaker.rawValue,
            hasInput: false
        )
    }

    private func kind(for portType: AVAudioSession.Port) -> CallAudioRouteKind {
        switch portType {
        case .builtInSpeaker:
            return .speaker
        case .builtInReceiver, .builtInMic:
            return .receiver
        case .headphones, .headsetMic:
            return .wired
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            return .bluetooth
        case .usbAudio:
            return .usb
        case .carAudio:
            return .car
        default:
            return .external
        }
    }

    private func title(for port: AVAudioSessionPortDescription, kind: CallAudioRouteKind) -> String {
        let trimmed = port.portName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.defaultTitle : trimmed
    }

    private func debug(_ message: String) {
        #if DEBUG
        print("[native-call-route] \(message)")
        #endif
    }
}
