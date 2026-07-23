import UIKit

final class VoiceNoteComposerView: UIView {
    var onStop: (() -> Void)?
    var onCancel: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onSend: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    private let statusDot = UIView()
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    private let slider = UISlider()
    private let cancelButton = UIButton(type: .system)
    private let primaryButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var isPreview = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func showRecording(duration: TimeInterval) {
        isHidden = false
        isPreview = false
        titleLabel.text = "Recording"
        statusDot.backgroundColor = UIColor(hex: "#FF6262")
        slider.isHidden = true
        sendButton.isHidden = true
        configureButton(primaryButton, symbol: "stop.fill", title: "Stop", filled: true)
        updateDuration(elapsed: duration, total: nil)
    }

    func showPreview(recording: VoiceNoteRecording, playback: VoiceNotePlaybackState) {
        isHidden = false
        isPreview = true
        titleLabel.text = playback.isBuffering ? "Loading preview..." : "Ready to send"
        statusDot.backgroundColor = ChitChatColors.accent
        slider.isHidden = false
        sendButton.isHidden = false
        slider.minimumValue = 0
        slider.maximumValue = Float(max(recording.duration, 0.1))
        updatePreview(playback, fallbackDuration: recording.duration)
        configureButton(
            primaryButton,
            symbol: playback.isPlaying ? "pause.fill" : "play.fill",
            title: playback.isPlaying ? "Pause" : "Preview",
            filled: false
        )
    }

    func updateRecordingDuration(_ duration: TimeInterval) {
        guard !isPreview else { return }
        updateDuration(elapsed: duration, total: nil)
    }

    func updatePreview(_ state: VoiceNotePlaybackState, fallbackDuration: TimeInterval) {
        guard isPreview else { return }
        let total = max(state.duration, fallbackDuration)
        slider.maximumValue = Float(max(total, 0.1))
        slider.value = Float(min(max(state.elapsed, 0), total))
        titleLabel.text = state.errorMessage ?? (state.isBuffering ? "Loading preview..." : "Ready to send")
        titleLabel.textColor = state.errorMessage == nil ? ChitChatColors.textPrimary : UIColor(hex: "#FF9292")
        configureButton(
            primaryButton,
            symbol: state.isPlaying ? "pause.fill" : "play.fill",
            title: state.isPlaying ? "Pause" : "Preview",
            filled: false
        )
        updateDuration(elapsed: state.elapsed, total: total)
    }

    func reset() {
        isPreview = false
        slider.value = 0
        isHidden = true
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.chatDetailHeader
        clipsToBounds = true
        isHidden = true

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.layer.cornerRadius = 5

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.numberOfLines = 1

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        durationLabel.textColor = ChitChatColors.textMuted
        durationLabel.numberOfLines = 1

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = ChitChatColors.accent
        slider.maximumTrackTintColor = ChitChatColors.textMuted.withAlphaComponent(0.35)
        slider.thumbTintColor = ChitChatColors.accent
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        configureButton(cancelButton, symbol: "trash", title: "Discard", filled: false)
        cancelButton.tintColor = UIColor(hex: "#FF9292")
        cancelButton.setTitleColor(UIColor(hex: "#FF9292"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        configureButton(sendButton, symbol: "paperplane.fill", title: "Send", filled: true)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        addSubview(statusDot)
        addSubview(titleLabel)
        addSubview(durationLabel)
        addSubview(slider)
        addSubview(cancelButton)
        addSubview(primaryButton)
        addSubview(sendButton)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            statusDot.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 9),
            titleLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: durationLabel.leadingAnchor, constant: -8),

            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            durationLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            slider.heightAnchor.constraint(equalToConstant: 24),

            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            cancelButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),

            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor),
            sendButton.heightAnchor.constraint(equalToConstant: 36),

            primaryButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            primaryButton.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func configureButton(_ button: UIButton, symbol: String, title: String, filled: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.title = title
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        configuration.baseForegroundColor = filled ? ChitChatColors.chatDetailScreen : ChitChatColors.accent
        configuration.background.backgroundColor = filled ? ChitChatColors.accent : ChitChatColors.chatDetailInput
        configuration.background.cornerRadius = 18
        button.configuration = configuration
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    }

    private func updateDuration(elapsed: TimeInterval, total: TimeInterval?) {
        let elapsedText = Self.formatDuration(elapsed)
        if let total {
            durationLabel.text = "\(elapsedText) / \(Self.formatDuration(total))"
        } else {
            durationLabel.text = elapsedText
        }
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }

    @objc private func sliderChanged() {
        onSeek?(TimeInterval(slider.value))
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func primaryTapped() {
        if isPreview {
            onPlayPause?()
        } else {
            onStop?()
        }
    }

    @objc private func sendTapped() {
        onSend?()
    }
}
