import UIKit
import WebRTC

final class VideoCallViewController: UIViewController {
    var onDismissed: (() -> Void)?

    private let service: VoiceCallService
    private let remoteVideoView = RTCMTLVideoView()
    private let localVideoView = RTCMTLVideoView()
    private let remotePlaceholder = UIView()
    private let remotePlaceholderIcon = UIImageView()
    private let remotePlaceholderLabel = UILabel()
    private let localPreviewContainer = UIView()
    private let localPlaceholder = UIView()
    private let localPlaceholderIcon = UIImageView()
    private let nameLabel = UILabel()
    private let stateLabel = UILabel()
    private let durationLabel = UILabel()
    private let incomingStack = UIStackView()
    private let activeStack = UIStackView()
    private let wideButton = UIButton(type: .system)
    private let acceptButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)
    private let muteButton = UIButton(type: .system)
    private let cameraButton = UIButton(type: .system)
    private let switchCameraButton = UIButton(type: .system)
    private let audioRouteButton = UIButton(type: .system)
    private let endButton = UIButton(type: .system)
    private var currentState: VoiceCallPresentationState?
    private var pendingState: VoiceCallPresentationState?
    private var durationTimer: Timer?

    init(service: VoiceCallService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoSurfaces()
        configureLabels()
        configureControls()
        service.attachVideoRenderers(local: localVideoView, remote: remoteVideoView)
        if let pendingState {
            self.pendingState = nil
            apply(state: pendingState)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        durationTimer?.invalidate()
        durationTimer = nil
        service.detachVideoRenderers(local: localVideoView, remote: remoteVideoView)
        onDismissed?()
    }

    func render(_ state: VoiceCallPresentationState?) {
        guard let state else { return }
        currentState = state
        guard isViewLoaded else {
            pendingState = state
            return
        }
        apply(state: state)
    }

    private func apply(state: VoiceCallPresentationState) {
        nameLabel.text = state.participant.displayName
        localVideoView.transform = state.isUsingFrontCamera ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        remotePlaceholder.isHidden = state.hasRemoteVideo
        localPlaceholder.isHidden = state.hasLocalVideo
        switchCameraButton.isEnabled = state.isCameraEnabled
        updateLabels(for: state)
        updateControls(for: state)
        updateDurationTimer(for: state)
    }

    private func configureVideoSurfaces() {
        view.backgroundColor = ChitChatColors.background

        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        remoteVideoView.videoContentMode = .scaleAspectFill
        view.addSubview(remoteVideoView)

        remotePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        remotePlaceholder.backgroundColor = ChitChatColors.background
        view.addSubview(remotePlaceholder)

        remotePlaceholderIcon.translatesAutoresizingMaskIntoConstraints = false
        remotePlaceholderIcon.image = UIImage(systemName: "video.fill")
        remotePlaceholderIcon.tintColor = ChitChatColors.accent.withAlphaComponent(0.72)
        remotePlaceholderIcon.contentMode = .scaleAspectFit

        remotePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        remotePlaceholderLabel.text = "Waiting for video"
        remotePlaceholderLabel.textColor = ChitChatColors.textSecondary
        remotePlaceholderLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        remotePlaceholderLabel.textAlignment = .center

        remotePlaceholder.addSubview(remotePlaceholderIcon)
        remotePlaceholder.addSubview(remotePlaceholderLabel)

        localPreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        localPreviewContainer.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        localPreviewContainer.layer.cornerRadius = 16
        localPreviewContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        localPreviewContainer.layer.borderWidth = 1
        localPreviewContainer.clipsToBounds = true
        view.addSubview(localPreviewContainer)

        localVideoView.translatesAutoresizingMaskIntoConstraints = false
        localVideoView.videoContentMode = .scaleAspectFill
        localPreviewContainer.addSubview(localVideoView)

        localPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        localPlaceholder.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        localPreviewContainer.addSubview(localPlaceholder)

        localPlaceholderIcon.translatesAutoresizingMaskIntoConstraints = false
        localPlaceholderIcon.image = UIImage(systemName: "video.slash.fill")
        localPlaceholderIcon.tintColor = ChitChatColors.textSecondary
        localPlaceholderIcon.contentMode = .scaleAspectFit
        localPlaceholder.addSubview(localPlaceholderIcon)

        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            remotePlaceholder.topAnchor.constraint(equalTo: view.topAnchor),
            remotePlaceholder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remotePlaceholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remotePlaceholder.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            remotePlaceholderIcon.centerXAnchor.constraint(equalTo: remotePlaceholder.centerXAnchor),
            remotePlaceholderIcon.centerYAnchor.constraint(equalTo: remotePlaceholder.centerYAnchor, constant: -18),
            remotePlaceholderIcon.widthAnchor.constraint(equalToConstant: 52),
            remotePlaceholderIcon.heightAnchor.constraint(equalToConstant: 52),

            remotePlaceholderLabel.topAnchor.constraint(equalTo: remotePlaceholderIcon.bottomAnchor, constant: 14),
            remotePlaceholderLabel.leadingAnchor.constraint(equalTo: remotePlaceholder.leadingAnchor, constant: 24),
            remotePlaceholderLabel.trailingAnchor.constraint(equalTo: remotePlaceholder.trailingAnchor, constant: -24),

            localPreviewContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            localPreviewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            localPreviewContainer.widthAnchor.constraint(equalToConstant: 112),
            localPreviewContainer.heightAnchor.constraint(equalToConstant: 160),

            localVideoView.topAnchor.constraint(equalTo: localPreviewContainer.topAnchor),
            localVideoView.leadingAnchor.constraint(equalTo: localPreviewContainer.leadingAnchor),
            localVideoView.trailingAnchor.constraint(equalTo: localPreviewContainer.trailingAnchor),
            localVideoView.bottomAnchor.constraint(equalTo: localPreviewContainer.bottomAnchor),

            localPlaceholder.topAnchor.constraint(equalTo: localPreviewContainer.topAnchor),
            localPlaceholder.leadingAnchor.constraint(equalTo: localPreviewContainer.leadingAnchor),
            localPlaceholder.trailingAnchor.constraint(equalTo: localPreviewContainer.trailingAnchor),
            localPlaceholder.bottomAnchor.constraint(equalTo: localPreviewContainer.bottomAnchor),

            localPlaceholderIcon.centerXAnchor.constraint(equalTo: localPlaceholder.centerXAnchor),
            localPlaceholderIcon.centerYAnchor.constraint(equalTo: localPlaceholder.centerYAnchor),
            localPlaceholderIcon.widthAnchor.constraint(equalToConstant: 34),
            localPlaceholderIcon.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func configureLabels() {
        let labelBackdrop = UIView()
        labelBackdrop.translatesAutoresizingMaskIntoConstraints = false
        labelBackdrop.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        labelBackdrop.layer.cornerRadius = 18
        view.addSubview(labelBackdrop)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.textColor = ChitChatColors.textPrimary
        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        nameLabel.numberOfLines = 1

        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.textColor = ChitChatColors.textSecondary
        stateLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        stateLabel.numberOfLines = 1

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.textColor = ChitChatColors.accent
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        durationLabel.numberOfLines = 1

        labelBackdrop.addSubview(nameLabel)
        labelBackdrop.addSubview(stateLabel)
        labelBackdrop.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            labelBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            labelBackdrop.trailingAnchor.constraint(lessThanOrEqualTo: localPreviewContainer.leadingAnchor, constant: -14),
            labelBackdrop.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),

            nameLabel.topAnchor.constraint(equalTo: labelBackdrop.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: labelBackdrop.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: labelBackdrop.trailingAnchor, constant: -16),

            stateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            stateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            stateLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            durationLabel.topAnchor.constraint(equalTo: stateLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            durationLabel.bottomAnchor.constraint(equalTo: labelBackdrop.bottomAnchor, constant: -14)
        ])
    }

    private func configureControls() {
        configureCircleButton(declineButton, symbol: "phone.down.fill", background: ChitChatColors.danger, size: 74)
        configureCircleButton(acceptButton, symbol: "video.fill", background: ChitChatColors.accent, size: 74)
        configureControlButton(muteButton, symbol: "mic.fill", title: "Mute")
        configureControlButton(cameraButton, symbol: "video.fill", title: "Camera")
        configureControlButton(switchCameraButton, symbol: "camera.rotate.fill", title: "Flip")
        configureControlButton(audioRouteButton, symbol: "speaker.wave.2.fill", title: "Audio")
        configureControlButton(endButton, symbol: "phone.down.fill", title: "End")
        endButton.backgroundColor = ChitChatColors.danger
        endButton.layer.borderWidth = 0

        declineButton.addTarget(self, action: #selector(declineCall), for: .touchUpInside)
        acceptButton.addTarget(self, action: #selector(acceptCall), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(toggleCamera), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        audioRouteButton.addTarget(self, action: #selector(showAudioRoutes), for: .touchUpInside)
        endButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)

        incomingStack.translatesAutoresizingMaskIntoConstraints = false
        incomingStack.axis = .horizontal
        incomingStack.alignment = .center
        incomingStack.distribution = .equalSpacing
        incomingStack.addArrangedSubview(declineButton)
        incomingStack.addArrangedSubview(acceptButton)
        view.addSubview(incomingStack)

        activeStack.translatesAutoresizingMaskIntoConstraints = false
        activeStack.axis = .horizontal
        activeStack.alignment = .center
        activeStack.distribution = .fillEqually
        activeStack.spacing = 4
        activeStack.addArrangedSubview(muteButton)
        activeStack.addArrangedSubview(cameraButton)
        activeStack.addArrangedSubview(switchCameraButton)
        activeStack.addArrangedSubview(audioRouteButton)
        activeStack.addArrangedSubview(endButton)
        view.addSubview(activeStack)

        wideButton.translatesAutoresizingMaskIntoConstraints = false
        wideButton.backgroundColor = ChitChatColors.danger
        wideButton.layer.cornerRadius = 28
        wideButton.setTitleColor(.white, for: .normal)
        wideButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        wideButton.addTarget(self, action: #selector(wideButtonTapped), for: .touchUpInside)
        view.addSubview(wideButton)

        NSLayoutConstraint.activate([
            incomingStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 54),
            incomingStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -54),
            incomingStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -58),

            activeStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            activeStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            activeStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            activeStack.heightAnchor.constraint(equalToConstant: 64),

            wideButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            wideButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            wideButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -52),
            wideButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func configureCircleButton(_ button: UIButton, symbol: String, background: UIColor, size: CGFloat) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = background
        button.tintColor = .white
        button.layer.cornerRadius = size / 2
        button.setImage(
            UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .semibold)),
            for: .normal
        )
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func configureControlButton(_ button: UIButton, symbol: String, title: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        button.tintColor = ChitChatColors.textPrimary
        button.layer.cornerRadius = 29
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        configuration.imagePlacement = .top
        configuration.imagePadding = 3
        configuration.title = title
        configuration.baseForegroundColor = ChitChatColors.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 2)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            return attributes
        }
        button.configuration = configuration
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.75
        button.heightAnchor.constraint(equalToConstant: 64).isActive = true
    }

    private func updateLabels(for state: VoiceCallPresentationState) {
        switch state.status {
        case .incoming:
            stateLabel.text = "Incoming video call"
            durationLabel.text = "Private call"
        case .outgoing:
            stateLabel.text = "Calling..."
            durationLabel.text = "Video call"
        case .ringing:
            stateLabel.text = "Ringing..."
            durationLabel.text = "Video call"
        case .connecting:
            stateLabel.text = "Connecting..."
            durationLabel.text = "Video call"
        case .active:
            stateLabel.text = state.hasRemoteVideo ? "Connected" : "Waiting for remote video"
            durationLabel.text = formattedDuration(from: state.connectedAt)
        case .busy(let message):
            stateLabel.text = "User busy"
            durationLabel.text = message
        case .ended(let reason):
            stateLabel.text = "Call ended"
            durationLabel.text = reason ?? "Video call ended"
        case .failed(let message):
            stateLabel.text = "Call failed"
            durationLabel.text = message
        }
    }

    private func updateControls(for state: VoiceCallPresentationState) {
        let isIncoming = state.status == .incoming
        let isActive = state.status == .active
        incomingStack.isHidden = !isIncoming
        activeStack.isHidden = !isActive
        wideButton.isHidden = isIncoming || isActive

        switch state.status {
        case .busy, .ended, .failed:
            wideButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            wideButton.layer.borderWidth = 1
            wideButton.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            wideButton.setTitle("Close", for: .normal)
        default:
            wideButton.backgroundColor = ChitChatColors.danger
            wideButton.layer.borderWidth = 0
            wideButton.setTitle("Cancel call", for: .normal)
        }

        updateMuteButton(state.isMuted)
        updateCameraButton(state.isCameraEnabled)
        updateAudioRouteButton(state)
    }

    private func updateMuteButton(_ isMuted: Bool) {
        var configuration = muteButton.configuration
        configuration?.title = isMuted ? "Unmute" : "Mute"
        configuration?.image = UIImage(
            systemName: isMuted ? "mic.slash.fill" : "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        configuration?.baseForegroundColor = isMuted ? ChitChatColors.accent : ChitChatColors.textPrimary
        muteButton.configuration = configuration
    }

    private func updateCameraButton(_ isEnabled: Bool) {
        var configuration = cameraButton.configuration
        configuration?.title = "Camera"
        configuration?.image = UIImage(
            systemName: isEnabled ? "video.fill" : "video.slash.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        configuration?.baseForegroundColor = isEnabled ? ChitChatColors.textPrimary : ChitChatColors.accent
        cameraButton.configuration = configuration
        cameraButton.accessibilityLabel = "Camera"
        cameraButton.accessibilityValue = isEnabled ? "On" : "Off"
    }

    private func updateAudioRouteButton(_ state: VoiceCallPresentationState) {
        var configuration = audioRouteButton.configuration
        configuration?.title = "Audio"
        configuration?.image = UIImage(
            systemName: state.audioRouteIconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        configuration?.baseForegroundColor = state.isSpeakerOn ? ChitChatColors.accent : ChitChatColors.textPrimary
        audioRouteButton.configuration = configuration
        audioRouteButton.accessibilityLabel = "Audio route"
        audioRouteButton.accessibilityValue = state.audioRouteName
    }

    private func updateDurationTimer(for state: VoiceCallPresentationState) {
        durationTimer?.invalidate()
        durationTimer = nil
        guard state.status == .active else { return }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let currentState = self.currentState else { return }
            self.durationLabel.text = self.formattedDuration(from: currentState.connectedAt)
        }
    }

    private func formattedDuration(from connectedAt: Date?) -> String {
        guard let connectedAt else { return "00:00" }
        let totalSeconds = max(0, Int(Date().timeIntervalSince(connectedAt)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @objc private func declineCall() {
        service.rejectIncomingCall()
    }

    @objc private func acceptCall() {
        service.acceptIncomingCall()
    }

    @objc private func toggleMute() {
        service.toggleMute()
    }

    @objc private func toggleCamera() {
        service.toggleCamera()
    }

    @objc private func switchCamera() {
        service.switchCamera()
    }

    @objc private func showAudioRoutes() {
        guard presentedViewController == nil else { return }
        let routes = service.availableAudioRoutes()
        guard !routes.isEmpty else { return }

        let currentRouteID = service.currentAudioRouteID()
        let alert = UIAlertController(title: "Audio", message: nil, preferredStyle: .actionSheet)
        routes.forEach { route in
            let title = route.id == currentRouteID ? "✓ \(route.title)" : route.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.service.selectAudioRoute(route)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = audioRouteButton
            popover.sourceRect = audioRouteButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func endCall() {
        service.endActiveCall()
    }

    @objc private func wideButtonTapped() {
        guard let state = currentState else {
            dismiss(animated: true)
            return
        }
        switch state.status {
        case .busy, .ended, .failed:
            dismiss(animated: true)
        default:
            service.cancelOutgoingCall()
        }
    }
}
