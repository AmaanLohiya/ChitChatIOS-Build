import UIKit

private final class VoiceCallAvatarView: UIView {
    private static let cache = NSCache<NSString, UIImage>()

    private let imageView = UIImageView()
    private let initialLabel = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.white.withAlphaComponent(0.09)
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true

        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        initialLabel.textColor = .white
        initialLabel.font = UIFont.systemFont(ofSize: 44, weight: .bold)
        initialLabel.textAlignment = .center

        addSubview(initialLabel)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            initialLabel.topAnchor.constraint(equalTo: topAnchor),
            initialLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            initialLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            initialLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        imageView.layer.cornerRadius = imageView.bounds.width / 2
    }

    func configure(participant: VoiceCallParticipant) {
        imageTask?.cancel()
        imageView.image = nil
        imageView.isHidden = true
        initialLabel.text = String(participant.displayName.prefix(1)).uppercased()

        let avatarURL = participant.avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !avatarURL.isEmpty, let url = URL(string: avatarURL) else { return }
        representedURL = avatarURL
        if let cached = Self.cache.object(forKey: avatarURL as NSString) {
            imageView.image = cached
            imageView.isHidden = false
            return
        }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: avatarURL as NSString)
            DispatchQueue.main.async {
                guard self?.representedURL == avatarURL else { return }
                self?.imageView.image = image
                self?.imageView.isHidden = false
            }
        }
        imageTask?.resume()
    }

    deinit {
        imageTask?.cancel()
    }
}

final class VoiceCallViewController: UIViewController {
    var onDismissed: (() -> Void)?

    private let service: VoiceCallService
    private let gradientLayer = CAGradientLayer()
    private let avatarView = VoiceCallAvatarView()
    private let nameLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let incomingStack = UIStackView()
    private let activeStack = UIStackView()
    private let wideButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)
    private let acceptButton = UIButton(type: .system)
    private let muteButton = UIButton(type: .system)
    private let speakerButton = UIButton(type: .system)
    private let hangupButton = UIButton(type: .system)
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
        configureView()
        configureIdentity()
        configureActions()
        if let pendingState {
            self.pendingState = nil
            apply(state: pendingState)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        durationTimer?.invalidate()
        durationTimer = nil
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
        avatarView.configure(participant: state.participant)
        nameLabel.text = state.participant.displayName
        updateLabels(for: state)
        updateActions(for: state)
        updateDurationTimer(for: state)
    }

    private func configureView() {
        view.backgroundColor = UIColor(hex: "#0D2231")
        gradientLayer.colors = [
            UIColor(hex: "#103D3D").cgColor,
            UIColor(hex: "#0D2231").cgColor,
            UIColor(hex: "#071825").cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func configureIdentity() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.textColor = UIColor(hex: "#F2F8FB")
        nameLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = UIColor(hex: "#F2F8FB")
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = UIColor(hex: "#93A7B2")
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2

        view.addSubview(avatarView)
        view.addSubview(nameLabel)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 76),
            avatarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 138),
            avatarView.heightAnchor.constraint(equalToConstant: 138),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 34),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -34)
        ])
    }

    private func configureActions() {
        configureCircleButton(rejectButton, systemName: "phone.down.fill", background: UIColor(hex: "#EF5350"))
        configureCircleButton(acceptButton, systemName: "phone.fill", background: UIColor(hex: "#4BC5A6"))
        configureControlButton(muteButton, title: "Mute", systemName: "mic.fill")
        configureControlButton(speakerButton, title: "Speaker", systemName: "speaker.wave.2.fill")
        configureCircleButton(hangupButton, systemName: "phone.down.fill", background: UIColor(hex: "#EF5350"), size: 82)

        rejectButton.addTarget(self, action: #selector(rejectCall), for: .touchUpInside)
        acceptButton.addTarget(self, action: #selector(acceptCall), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        speakerButton.addTarget(self, action: #selector(toggleSpeaker), for: .touchUpInside)
        hangupButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)

        incomingStack.translatesAutoresizingMaskIntoConstraints = false
        incomingStack.axis = .horizontal
        incomingStack.alignment = .center
        incomingStack.distribution = .equalSpacing
        incomingStack.addArrangedSubview(rejectButton)
        incomingStack.addArrangedSubview(acceptButton)

        activeStack.translatesAutoresizingMaskIntoConstraints = false
        activeStack.axis = .horizontal
        activeStack.alignment = .center
        activeStack.distribution = .equalSpacing
        activeStack.addArrangedSubview(muteButton)
        activeStack.addArrangedSubview(speakerButton)
        activeStack.addArrangedSubview(hangupButton)

        wideButton.translatesAutoresizingMaskIntoConstraints = false
        wideButton.backgroundColor = UIColor(hex: "#EF5350")
        wideButton.layer.cornerRadius = 28
        wideButton.setTitleColor(.white, for: .normal)
        wideButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        wideButton.addTarget(self, action: #selector(wideButtonTapped), for: .touchUpInside)

        view.addSubview(incomingStack)
        view.addSubview(activeStack)
        view.addSubview(wideButton)

        NSLayoutConstraint.activate([
            incomingStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            incomingStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            incomingStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -58),

            activeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            activeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            activeStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),

            wideButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            wideButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            wideButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -54),
            wideButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func configureCircleButton(
        _ button: UIButton,
        systemName: String,
        background: UIColor,
        size: CGFloat = 76
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = background
        button.tintColor = .white
        button.layer.cornerRadius = size / 2
        button.setImage(
            UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)),
            for: .normal
        )
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func configureControlButton(_ button: UIButton, title: String, systemName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.tintColor = UIColor(hex: "#F2F8FB")
        button.layer.cornerRadius = 26
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .medium))
        configuration.imagePlacement = .top
        configuration.imagePadding = 8
        configuration.title = title
        configuration.baseForegroundColor = UIColor(hex: "#F2F8FB")
        button.configuration = configuration
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 82),
            button.heightAnchor.constraint(equalToConstant: 82)
        ])
    }

    private func updateLabels(for state: VoiceCallPresentationState) {
        switch state.status {
        case .incoming:
            titleLabel.text = "Incoming voice call"
            subtitleLabel.text = "Private call"
        case .outgoing:
            titleLabel.text = "Calling..."
            subtitleLabel.text = "Private call"
        case .ringing:
            titleLabel.text = "Ringing..."
            subtitleLabel.text = "Private call"
        case .connecting:
            titleLabel.text = "Connecting..."
            subtitleLabel.text = "Private call"
        case .active:
            titleLabel.text = formattedDuration(from: state.connectedAt)
            subtitleLabel.text = "Voice call in progress"
        case .busy(let message):
            titleLabel.text = "User busy"
            subtitleLabel.text = message
        case .ended(let reason):
            titleLabel.text = "Call ended"
            subtitleLabel.text = reason ?? "Voice call ended"
        case .failed(let message):
            titleLabel.text = "Call failed"
            subtitleLabel.text = message
        }
    }

    private func updateActions(for state: VoiceCallPresentationState) {
        let isIncoming = state.status == .incoming
        let isActive = state.status == .active
        let showsWideButton = !isIncoming && !isActive

        incomingStack.isHidden = !isIncoming
        activeStack.isHidden = !isActive
        wideButton.isHidden = !showsWideButton

        switch state.status {
        case .busy, .ended, .failed:
            wideButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            wideButton.layer.borderWidth = 1
            wideButton.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
            wideButton.setTitle("Close", for: .normal)
        default:
            wideButton.backgroundColor = UIColor(hex: "#EF5350")
            wideButton.layer.borderWidth = 0
            wideButton.setTitle("Cancel call", for: .normal)
        }

        updateMuteButton(isMuted: state.isMuted)
        speakerButton.tintColor = state.isSpeakerOn ? UIColor(hex: "#4BC5A6") : UIColor(hex: "#F2F8FB")
    }

    private func updateMuteButton(isMuted: Bool) {
        var configuration = muteButton.configuration
        configuration?.title = isMuted ? "Unmute" : "Mute"
        configuration?.image = UIImage(
            systemName: isMuted ? "mic.slash.fill" : "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .medium)
        )
        muteButton.configuration = configuration
    }

    private func updateDurationTimer(for state: VoiceCallPresentationState) {
        durationTimer?.invalidate()
        durationTimer = nil
        guard state.status == .active else { return }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let currentState = self.currentState else { return }
            self.titleLabel.text = self.formattedDuration(from: currentState.connectedAt)
        }
    }

    private func formattedDuration(from connectedAt: Date?) -> String {
        guard let connectedAt else { return "00:00" }
        let totalSeconds = max(0, Int(Date().timeIntervalSince(connectedAt)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @objc private func rejectCall() {
        service.rejectIncomingCall()
    }

    @objc private func acceptCall() {
        service.acceptIncomingCall()
    }

    @objc private func toggleMute() {
        service.toggleMute()
    }

    @objc private func toggleSpeaker() {
        service.toggleSpeaker()
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
