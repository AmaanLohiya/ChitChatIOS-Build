import AVFoundation
import AVKit
import UIKit

/// Reuses the system player controls for both a selected video draft and a persisted video message.
final class VideoMessagePreviewViewController: UIViewController {
    private let videoURL: URL
    private let fileName: String
    private let duration: TimeInterval?
    private let fileSize: Int?
    private let onSend: (() -> Void)?
    private let onDiscard: (() -> Void)?

    private let player: AVPlayer
    private let playerViewController = AVPlayerViewController()
    private let titleLabel = UILabel()
    private let fileNameLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let discardButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let controlsStack = UIStackView()
    private let detailsView = UIView()
    private var statusObservation: NSKeyValueObservation?
    private var failedToPlayObserver: NSObjectProtocol?
    private var didCompleteAction = false

    init(
        videoURL: URL,
        fileName: String,
        duration: TimeInterval?,
        fileSize: Int?,
        onSend: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.fileName = fileName
        self.duration = duration
        self.fileSize = fileSize
        self.onSend = onSend
        self.onDiscard = onDiscard
        self.player = AVPlayer(url: videoURL)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        statusObservation?.invalidate()
        if let failedToPlayObserver {
            NotificationCenter.default.removeObserver(failedToPlayObserver)
        }
        player.pause()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.chatDetailScreen
        configureViews()
        configurePlayer()
        observePlayback()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            completeDiscardIfNeeded()
        }
    }

    private func configureViews() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.chatDetailHeader
        view.addSubview(header)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = ChitChatColors.textPrimary
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = "Close video"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        header.addSubview(closeButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = onSend == nil ? "Video" : "Video preview"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        header.addSubview(titleLabel)

        playerViewController.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true
        playerViewController.videoGravity = .resizeAspect
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Loading video..."
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        playerViewController.contentOverlayView?.addSubview(statusLabel)

        detailsView.translatesAutoresizingMaskIntoConstraints = false
        detailsView.backgroundColor = ChitChatColors.chatDetailHeader
        view.addSubview(detailsView)

        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.text = fileName
        fileNameLabel.textColor = ChitChatColors.textPrimary
        fileNameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        fileNameLabel.numberOfLines = 1
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.addSubview(fileNameLabel)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.text = Self.metadataText(duration: duration, fileSize: fileSize)
        detailLabel.textColor = ChitChatColors.textMuted
        detailLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        detailLabel.numberOfLines = 1
        detailsView.addSubview(detailLabel)

        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.alignment = .fill
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 10
        detailsView.addSubview(controlsStack)

        configureActionButtons()

        let controlsHeight: CGFloat = onSend == nil ? 0 : 46
        controlsStack.isHidden = onSend == nil

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),

            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            closeButton.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -9),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -54),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            playerViewController.view.topAnchor.constraint(equalTo: header.bottomAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: detailsView.topAnchor),

            detailsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            fileNameLabel.topAnchor.constraint(equalTo: detailsView.topAnchor, constant: 14),
            fileNameLabel.leadingAnchor.constraint(equalTo: detailsView.leadingAnchor, constant: 20),
            fileNameLabel.trailingAnchor.constraint(equalTo: detailsView.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: fileNameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: fileNameLabel.trailingAnchor),

            controlsStack.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: onSend == nil ? 0 : 14),
            controlsStack.leadingAnchor.constraint(equalTo: detailsView.leadingAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: detailsView.trailingAnchor, constant: -20),
            controlsStack.heightAnchor.constraint(equalToConstant: controlsHeight),
            controlsStack.bottomAnchor.constraint(equalTo: detailsView.bottomAnchor, constant: onSend == nil ? -14 : -20),
        ])

        if let overlay = playerViewController.contentOverlayView {
            NSLayoutConstraint.activate([
                statusLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                statusLabel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
                statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24),
            ])
        }
    }

    private func configureActionButtons() {
        guard onSend != nil else { return }
        discardButton.setTitle("Discard", for: .normal)
        discardButton.setTitleColor(ChitChatColors.textPrimary, for: .normal)
        discardButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        discardButton.backgroundColor = ChitChatColors.chatDetailInput
        discardButton.layer.cornerRadius = 23
        discardButton.accessibilityLabel = "Discard video"
        discardButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        sendButton.setTitle("Send", for: .normal)
        sendButton.setTitleColor(ChitChatColors.textOnAccent, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        sendButton.backgroundColor = ChitChatColors.accent
        sendButton.layer.cornerRadius = 23
        sendButton.accessibilityLabel = "Send video"
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        controlsStack.addArrangedSubview(discardButton)
        controlsStack.addArrangedSubview(sendButton)
    }

    private func configurePlayer() {
        player.pause()
    }

    private func observePlayback() {
        statusObservation = player.currentItem?.observe(\AVPlayerItem.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.statusLabel.isHidden = true
                case .failed:
                    self.statusLabel.isHidden = false
                    self.statusLabel.text = "This video could not be played."
                default:
                    self.statusLabel.isHidden = false
                    self.statusLabel.text = "Loading video..."
                }
            }
        }
        failedToPlayObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.statusLabel.isHidden = false
            self?.statusLabel.text = "This video could not be played."
        }
    }

    @objc private func closeTapped() {
        completeDiscardIfNeeded()
        dismiss(animated: true)
    }

    @objc private func sendTapped() {
        guard !didCompleteAction else { return }
        didCompleteAction = true
        player.pause()
        sendButton.isEnabled = false
        discardButton.isEnabled = false
        onSend?()
        dismiss(animated: true)
    }

    private func completeDiscardIfNeeded() {
        guard !didCompleteAction else { return }
        didCompleteAction = true
        player.pause()
        onDiscard?()
    }

    private static func metadataText(duration: TimeInterval?, fileSize: Int?) -> String {
        var values: [String] = []
        if let duration, duration > 0 {
            let totalSeconds = Int(duration.rounded())
            values.append("\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))")
        }
        if let fileSize, fileSize > 0 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            values.append(formatter.string(fromByteCount: Int64(fileSize)))
        }
        return values.isEmpty ? "Video" : values.joined(separator: " | ")
    }
}
