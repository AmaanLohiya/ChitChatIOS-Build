import AVFoundation
import Foundation

enum VoiceNoteAudioError: LocalizedError {
    case permissionDenied
    case recorderUnavailable
    case recordingTooShort
    case recordingTooLarge
    case recordingMissing
    case unsupportedURL
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record voice notes."
        case .recorderUnavailable:
            return "Voice-note recording could not be started."
        case .recordingTooShort:
            return "Voice note is too short. Record for at least half a second."
        case .recordingTooLarge:
            return "Voice note is too large. Record a shorter note."
        case .recordingMissing:
            return "Recording is no longer available. Record it again."
        case .unsupportedURL:
            return "Voice note is unavailable."
        case .playbackFailed:
            return "Voice note could not be played."
        }
    }
}

struct VoiceNoteRecording {
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let duration: TimeInterval
    let size: Int
}

struct VoiceNotePlaybackState: Equatable {
    let sourceID: String?
    let elapsed: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let isBuffering: Bool
    let errorMessage: String?

    static func idle(sourceID: String? = nil, duration: TimeInterval = 0) -> VoiceNotePlaybackState {
        VoiceNotePlaybackState(
            sourceID: sourceID,
            elapsed: 0,
            duration: max(0, duration),
            isPlaying: false,
            isBuffering: false,
            errorMessage: nil
        )
    }
}

@MainActor
final class VoiceNoteRecorder: NSObject, AVAudioRecorderDelegate {
    static let minimumDuration: TimeInterval = 0.5
    static let maximumDuration: TimeInterval = 10 * 60
    static let maximumFileSize = 10 * 1024 * 1024

    var onDurationChanged: ((TimeInterval) -> Void)?
    var onAutomaticStop: ((Result<VoiceNoteRecording, Error>) -> Void)?
    var onInterrupted: ((String) -> Void)?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private var previousCategory: AVAudioSession.Category?
    private var previousMode: AVAudioSession.Mode?
    private var previousOptions: AVAudioSession.CategoryOptions?
    private var isFinishing = false

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    override init() {
        super.init()
        observeAudioInterruptions()
    }

    deinit {
        timer?.invalidate()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        guard recorder == nil, !isRecording else {
            throw VoiceNoteAudioError.recorderUnavailable
        }

        let session = AVAudioSession.sharedInstance()
        previousCategory = session.category
        previousMode = session.mode
        previousOptions = session.categoryOptions

        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            restoreAudioSession()
            throw VoiceNoteAudioError.recorderUnavailable
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-note-\(UUID().uuidString.lowercased())")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let nextRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            nextRecorder.delegate = self
            nextRecorder.isMeteringEnabled = false
            guard nextRecorder.prepareToRecord(), nextRecorder.record(forDuration: Self.maximumDuration) else {
                try? FileManager.default.removeItem(at: fileURL)
                restoreAudioSession()
                throw VoiceNoteAudioError.recorderUnavailable
            }
            recorder = nextRecorder
            isFinishing = false
            startTimer()
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            restoreAudioSession()
            throw VoiceNoteAudioError.recorderUnavailable
        }
    }

    func stop() throws -> VoiceNoteRecording {
        guard let recorder else {
            throw VoiceNoteAudioError.recordingMissing
        }
        isFinishing = true
        let duration = min(max(recorder.currentTime, 0), Self.maximumDuration)
        let fileURL = recorder.url
        recorder.stop()
        self.recorder = nil
        stopTimer()
        restoreAudioSession()

        guard duration >= Self.minimumDuration else {
            try? FileManager.default.removeItem(at: fileURL)
            throw VoiceNoteAudioError.recordingTooShort
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw VoiceNoteAudioError.recordingMissing
        }
        let size = (
            try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        ) ?? 0
        guard size > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            throw VoiceNoteAudioError.recordingMissing
        }
        guard size <= Self.maximumFileSize else {
            try? FileManager.default.removeItem(at: fileURL)
            throw VoiceNoteAudioError.recordingTooLarge
        }

        return VoiceNoteRecording(
            fileURL: fileURL,
            fileName: "voice-note-\(Int(Date().timeIntervalSince1970)).m4a",
            mimeType: "audio/mp4",
            duration: duration,
            size: size
        )
    }

    func cancel() {
        let fileURL = recorder?.url
        isFinishing = true
        recorder?.stop()
        recorder = nil
        stopTimer()
        restoreAudioSession()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func removeTemporaryFile(at url: URL?) {
        guard let url, url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard self.recorder === recorder, !isFinishing else { return }
        do {
            let recording = try stop()
            onAutomaticStop?(.success(recording))
        } catch {
            onAutomaticStop?(.failure(error))
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        guard self.recorder === recorder else { return }
        cancel()
        onInterrupted?(error?.localizedDescription ?? "Voice-note recording was interrupted.")
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder else { return }
                self.onDurationChanged?(min(recorder.currentTime, Self.maximumDuration))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func observeAudioInterruptions() {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                self.isRecording,
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: rawType) == .began
            else { return }
            self.cancel()
            self.onInterrupted?("Voice-note recording was interrupted.")
        }
        routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                self.isRecording,
                let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable
            else { return }
            self.cancel()
            self.onInterrupted?("The audio input changed. Record the voice note again.")
        }
    }

    private func restoreAudioSession() {
        guard previousCategory != nil || previousMode != nil || previousOptions != nil else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            if let previousCategory, let previousMode, let previousOptions {
                try session.setCategory(previousCategory, mode: previousMode, options: previousOptions)
            }
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            #if DEBUG
            print("[voice-note] audio session restore failed: \(error.localizedDescription)")
            #endif
        }
        previousCategory = nil
        previousMode = nil
        previousOptions = nil
    }
}

@MainActor
final class VoiceNotePlaybackCoordinator {
    var onStateChanged: ((VoiceNotePlaybackState) -> Void)?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var sourceID: String?
    private var declaredDuration: TimeInterval = 0
    private var previousCategory: AVAudioSession.Category?
    private var previousMode: AVAudioSession.Mode?
    private var previousOptions: AVAudioSession.CategoryOptions?

    private(set) var state = VoiceNotePlaybackState.idle()

    func toggle(sourceID: String, url: URL, declaredDuration: TimeInterval) throws {
        guard url.isFileURL || url.scheme?.lowercased() == "https" else {
            throw VoiceNoteAudioError.unsupportedURL
        }

        if self.sourceID == sourceID, let player {
            if player.timeControlStatus == .playing {
                player.pause()
                publishState()
            } else {
                player.play()
                publishState()
            }
            return
        }

        try start(sourceID: sourceID, url: url, declaredDuration: declaredDuration)
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        let duration = resolvedDuration
        let target = min(max(seconds, 0), max(duration, 0))
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.publishState()
            }
        }
    }

    func stop() {
        player?.pause()
        removeObservers()
        player = nil
        playerItem = nil
        sourceID = nil
        declaredDuration = 0
        restoreAudioSession()
        state = .idle()
        onStateChanged?(state)
    }

    private func start(sourceID: String, url: URL, declaredDuration: TimeInterval) throws {
        stop()
        try configurePlaybackSession()

        self.sourceID = sourceID
        self.declaredDuration = max(0, declaredDuration)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.playerItem = item
        self.player = player
        observe(item: item, player: player)
        state = VoiceNotePlaybackState(
            sourceID: sourceID,
            elapsed: 0,
            duration: max(0, declaredDuration),
            isPlaying: false,
            isBuffering: true,
            errorMessage: nil
        )
        onStateChanged?(state)
        player.play()
    }

    private func observe(item: AVPlayerItem, player: AVPlayer) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .failed {
                    self.publishState(error: VoiceNoteAudioError.playbackFailed.localizedDescription)
                } else {
                    self.publishState()
                }
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.publishState()
            }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.15, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.publishState()
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let sourceID = self.sourceID else { return }
                self.player?.seek(to: .zero)
                self.player?.pause()
                self.state = .idle(sourceID: sourceID, duration: self.resolvedDuration)
                self.onStateChanged?(self.state)
            }
        }
    }

    private var resolvedDuration: TimeInterval {
        guard let itemDuration = playerItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 else {
            return declaredDuration
        }
        return itemDuration
    }

    private func publishState(error: String? = nil) {
        guard let sourceID, let player else { return }
        let elapsed = player.currentTime().seconds
        state = VoiceNotePlaybackState(
            sourceID: sourceID,
            elapsed: elapsed.isFinite ? max(0, elapsed) : 0,
            duration: resolvedDuration,
            isPlaying: player.timeControlStatus == .playing,
            isBuffering: player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
            errorMessage: error
        )
        onStateChanged?(state)
    }

    private func removeObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func configurePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        previousCategory = session.category
        previousMode = session.mode
        previousOptions = session.categoryOptions
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            restoreAudioSession()
            throw VoiceNoteAudioError.playbackFailed
        }
    }

    private func restoreAudioSession() {
        guard previousCategory != nil || previousMode != nil || previousOptions != nil else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            if let previousCategory, let previousMode, let previousOptions {
                try session.setCategory(previousCategory, mode: previousMode, options: previousOptions)
            }
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            #if DEBUG
            print("[voice-note] playback audio session restore failed: \(error.localizedDescription)")
            #endif
        }
        previousCategory = nil
        previousMode = nil
        previousOptions = nil
    }
}
