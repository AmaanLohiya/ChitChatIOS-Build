import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

private enum MediaSendError: LocalizedError {
    case selectedFileUnavailable
    case fileCopyFailed
    case uploadFailed
    case sendFailed
    case previewDownloadFailed
    case cannotOpenDocument

    var errorDescription: String? {
        switch self {
        case .selectedFileUnavailable:
            return "Selected file could not be read."
        case .fileCopyFailed:
            return "Selected file could not be copied."
        case .uploadFailed:
            return "Upload failed. Please try again."
        case .sendFailed:
            return "Message could not be sent."
        case .previewDownloadFailed:
            return "Document preview could not be downloaded."
        case .cannotOpenDocument:
            return "Document could not be opened."
        }
    }
}

private enum PickedMediaFile {
    static func copyToTemporaryFile(sourceURL: URL, preferredFileName: String) throws -> URL {
        let destination = uniqueTemporaryURL(
            preferredFileName: preferredFileName,
            prefix: "chitchat-upload",
            excluding: sourceURL
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        try validateReadableFile(at: destination)
        return destination
    }

    static func coordinatedCopyToTemporaryFile(sourceURL: URL, preferredFileName: String) throws -> URL {
        let destination = uniqueTemporaryURL(
            preferredFileName: preferredFileName,
            prefix: "chitchat-upload",
            excluding: sourceURL
        )
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { readableURL in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let copyError {
            throw copyError
        }
        if let coordinatorError {
            throw coordinatorError
        }
        try validateReadableFile(at: destination)
        return destination
    }

    static func safeFileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "upload" : trimmed
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = fallback.unicodeScalars
            .map { forbidden.contains($0) ? "-" : String($0) }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return cleaned.isEmpty ? "upload" : cleaned
    }

    static func fileName(
        suggestedName: String?,
        sourceURL: URL,
        fallbackBase: String,
        fallbackExtension: String,
        mimeType: String? = nil
    ) -> String {
        let sourceName = displayName(for: sourceURL) ?? sourceURL.lastPathComponent
        let trimmedSuggestion = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName: String
        if let resolvedSuggestion = trimmedSuggestion, !resolvedSuggestion.isEmpty {
            rawName = resolvedSuggestion
        } else {
            rawName = sourceName.isEmpty ? fallbackBase : sourceName
        }
        let safeName = safeFileName(rawName)
        if URL(fileURLWithPath: safeName).pathExtension.isEmpty {
            let resolvedExtension = normalizedExtension(
                fallbackExtension.isEmpty ? preferredExtension(forMimeType: mimeType) ?? "dat" : fallbackExtension
            )
            return "\(safeName).\(resolvedExtension)"
        }
        return safeName
    }

    static func displayName(for url: URL) -> String? {
        if let localizedName = try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName,
           !localizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedName
        }
        let lastPathComponent = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return lastPathComponent.isEmpty ? nil : lastPathComponent
    }

    static func fileSize(at url: URL) -> Int? {
        guard
            let value = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            value > 0
        else {
            return nil
        }
        return value
    }

    static func contentType(for url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }
        return nil
    }

    static func preferredExtension(
        sourceURL: URL,
        mimeType: String?,
        fallback: String = "dat"
    ) -> String {
        if !sourceURL.pathExtension.isEmpty {
            return normalizedExtension(sourceURL.pathExtension)
        }
        if let type = contentType(for: sourceURL), let fileExtension = type.preferredFilenameExtension {
            return normalizedExtension(fileExtension)
        }
        if let mimeExtension = preferredExtension(forMimeType: mimeType) {
            return mimeExtension
        }
        return normalizedExtension(fallback)
    }

    static func preferredExtension(forMimeType mimeType: String?) -> String? {
        switch mimeType?.lowercased() {
        case "application/pdf":
            return "pdf"
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            return "xlsx"
        case "application/vnd.ms-excel":
            return "xls"
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "docx"
        case "application/msword":
            return "doc"
        case "text/csv", "application/csv":
            return "csv"
        case "text/plain":
            return "txt"
        case "application/zip", "application/x-zip-compressed":
            return "zip"
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/heic", "image/heif":
            return "heic"
        default:
            return nil
        }
    }

    static func uniqueTemporaryURL(
        preferredFileName: String,
        prefix: String,
        excluding sourceURL: URL? = nil
    ) -> URL {
        let safeName = safeFileName(preferredFileName)
        let plainDestination = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        let matchesSource = sourceURL.map {
            $0.standardizedFileURL == plainDestination.standardizedFileURL
        } ?? false
        if !matchesSource, !FileManager.default.fileExists(atPath: plainDestination.path) {
            return plainDestination
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)-\(safeName)")
    }

    private static func normalizedExtension(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return trimmed.isEmpty ? "dat" : trimmed.lowercased()
    }

    private static func validateReadableFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaSendError.selectedFileUnavailable
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw MediaSendError.selectedFileUnavailable
        }
    }
}

private final class ChatHeaderAvatarView: UIView {
    private static let cache = NSCache<NSString, UIImage>()

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var imageTask: URLSessionDataTask?
    private var representedURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ChitChatColors.surface
        clipsToBounds = true

        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        initialsLabel.textColor = ChitChatColors.accent
        initialsLabel.textAlignment = .center

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        addSubview(initialsLabel)
        addSubview(imageView)
        initialsLabel.pinEdges(to: self)
        imageView.pinEdges(to: self)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func configure(name: String, avatarURL: String, seed: String, isGroup: Bool) {
        imageTask?.cancel()
        imageView.image = nil
        imageView.isHidden = true
        initialsLabel.text = Self.initials(from: name)

        let encodedSeed = seed.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? seed
        let style = isGroup ? "identicon" : "avataaars"
        let resolvedURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://api.dicebear.com/7.x/\(style)/png?seed=\(encodedSeed)"
            : avatarURL
        representedURL = resolvedURL

        if let cached = Self.cache.object(forKey: resolvedURL as NSString) {
            imageView.image = cached
            imageView.isHidden = false
            return
        }

        guard let url = URL(string: resolvedURL) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: resolvedURL as NSString)
            DispatchQueue.main.async {
                guard self?.representedURL == resolvedURL else { return }
                self?.imageView.image = image
                self?.imageView.isHidden = false
            }
        }
        imageTask?.resume()
    }

    func cancelImageLoad() {
        imageTask?.cancel()
        imageTask = nil
        representedURL = nil
    }

    private static func initials(from name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        return letters.isEmpty ? "C" : letters
    }
}

private final class ImagePreviewViewController: UIViewController {
    private let imageURL: URL
    private let imageView = UIImageView()
    private let errorLabel = UILabel()
    private var imageTask: URLSessionDataTask?

    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Image could not be loaded."
        errorLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        errorLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .white
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            ),
            for: .normal
        )
        closeButton.accessibilityLabel = "Close preview"
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        loadImage()
    }

    deinit {
        imageTask?.cancel()
    }

    private func loadImage() {
        imageTask = URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let image = UIImage(data: data) else {
                    self.errorLabel.isHidden = false
                    return
                }
                self.errorLabel.isHidden = true
                self.imageView.image = image
            }
        }
        imageTask?.resume()
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class DocumentPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        fileURL as NSURL
    }
}

final class ChatDetailViewController: BaseViewController {
    private let chat: Chat
    private let currentUser: User
    private let messageService: MessageService
    private let uploadService: UploadService

    private let headerView = UIView()
    private let headerAvatar = ChatHeaderAvatarView()
    private let onlineDot = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = MessageInputBar()

    private var stateOverlay: UIView?
    private var messages: [Message] = []
    private var animatedMessageIDs = Set<String>()
    private var loadTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var mediaTask: Task<Void, Never>?
    private var documentPreviewTask: Task<Void, Never>?
    private var documentPreviewDataSource: DocumentPreviewDataSource?
    private var documentInteractionController: UIDocumentInteractionController?
    private var hasLoaded = false
    private var socketObservers: [NSObjectProtocol] = []

    init(
        chat: Chat,
        currentUser: User,
        messageService: MessageService = MessageService(),
        uploadService: UploadService = UploadService()
    ) {
        self.chat = chat
        self.currentUser = currentUser
        self.messageService = messageService
        self.uploadService = uploadService
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.chatDetailScreen
        configureHeader()
        configureTable()
        configureInputBar()
        observeRealtimeMessages()
        loadMessages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        SocketService.shared.joinChat(chat.id)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            SocketService.shared.leaveChat(chat.id)
        }
    }

    deinit {
        loadTask?.cancel()
        sendTask?.cancel()
        mediaTask?.cancel()
        documentPreviewTask?.cancel()
        headerAvatar.cancelImageLoad()
        socketObservers.forEach { NotificationCenter.default.removeObserver($0) }
        SocketService.shared.leaveChat(chat.id)
    }

    private func configureHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = ChitChatColors.chatDetailHeader

        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = ChitChatColors.textPrimary
        backButton.accessibilityLabel = "Back"
        backButton.setImage(
            UIImage(
                systemName: "chevron.left",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
            ),
            for: .normal
        )
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        let displayName = chat.displayName(viewerUserId: currentUser.id)
        headerAvatar.configure(
            name: displayName,
            avatarURL: chat.displayAvatarURL(viewerUserId: currentUser.id),
            seed: displayName.isEmpty ? chat.id : displayName,
            isGroup: chat.type == .group
        )

        let partner = chat.otherParticipant(viewerUserId: currentUser.id)?.user
        onlineDot.translatesAutoresizingMaskIntoConstraints = false
        onlineDot.backgroundColor = ChitChatColors.accent
        onlineDot.layer.cornerRadius = 6
        onlineDot.layer.borderWidth = 2
        onlineDot.layer.borderColor = ChitChatColors.chatDetailHeader.cgColor
        onlineDot.isHidden = chat.type == .group || !(partner?.isOnline ?? false)

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.attributedText = NSAttributedString(
            string: displayName,
            attributes: [
                .font: ChitChatTypography.chatDetailName,
                .foregroundColor: ChitChatColors.textPrimary,
                .kern: -0.2
            ]
        )
        nameLabel.numberOfLines = 1

        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = headerStatus(partner: partner)
        statusLabel.font = ChitChatTypography.chatDetailStatus
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.numberOfLines = 1

        let userMeta = UIStackView(arrangedSubviews: [nameLabel, statusLabel])
        userMeta.translatesAutoresizingMaskIntoConstraints = false
        userMeta.axis = .vertical
        userMeta.alignment = .fill
        userMeta.spacing = 0
        userMeta.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let videoButton = makeHeaderAction(
            symbol: "video",
            color: ChitChatColors.accent,
            accessibilityLabel: "Video call"
        )
        videoButton.addTarget(self, action: #selector(showVideoComingSoon), for: .touchUpInside)
        let phoneButton = makeHeaderAction(
            symbol: "phone",
            color: ChitChatColors.accent,
            accessibilityLabel: "Voice call"
        )
        phoneButton.addTarget(self, action: #selector(startVoiceCall), for: .touchUpInside)
        videoButton.isHidden = chat.type == .group
        phoneButton.isHidden = chat.type == .group
        let moreButton = makeHeaderAction(
            symbol: "ellipsis",
            color: ChitChatColors.textMuted,
            accessibilityLabel: "Chat options"
        )
        moreButton.transform = CGAffineTransform(rotationAngle: .pi / 2)

        let actions = UIStackView(arrangedSubviews: [videoButton, phoneButton, moreButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .horizontal
        actions.alignment = .center
        actions.spacing = 2

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = ChitChatColors.chatDetailBorder

        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(headerAvatar)
        headerView.addSubview(onlineDot)
        headerView.addSubview(userMeta)
        headerView.addSubview(actions)
        headerView.addSubview(divider)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerAvatar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: ChitChatSpacing.chatDetailHeaderTop
            ),
            headerAvatar.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 6),
            headerAvatar.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailAvatar),
            headerAvatar.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailAvatar),
            headerAvatar.bottomAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: -ChitChatSpacing.chatDetailHeaderBottom
            ),

            backButton.leadingAnchor.constraint(
                equalTo: headerView.leadingAnchor,
                constant: ChitChatSpacing.chatDetailHeaderHorizontal
            ),
            backButton.centerYAnchor.constraint(equalTo: headerAvatar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            backButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),

            onlineDot.trailingAnchor.constraint(equalTo: headerAvatar.trailingAnchor, constant: 2),
            onlineDot.bottomAnchor.constraint(equalTo: headerAvatar.bottomAnchor),
            onlineDot.widthAnchor.constraint(equalToConstant: 12),
            onlineDot.heightAnchor.constraint(equalToConstant: 12),

            userMeta.leadingAnchor.constraint(equalTo: headerAvatar.trailingAnchor, constant: 9),
            userMeta.centerYAnchor.constraint(equalTo: headerAvatar.centerYAnchor),
            userMeta.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -4),
            nameLabel.heightAnchor.constraint(equalToConstant: 19),
            statusLabel.heightAnchor.constraint(equalToConstant: 14),

            actions.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: -ChitChatSpacing.chatDetailHeaderHorizontal
            ),
            actions.centerYAnchor.constraint(equalTo: headerAvatar.centerYAnchor),
            videoButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            videoButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            phoneButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            phoneButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            moreButton.widthAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),
            moreButton.heightAnchor.constraint(equalToConstant: ChitChatSpacing.chatDetailHeaderButton),

            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func makeHeaderAction(
        symbol: String,
        color: UIColor,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = color
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            ),
            for: .normal
        )
        return button
    }

    private func headerStatus(partner: ChatMemberUser?) -> String {
        if chat.type == .group {
            let activeMemberCount = chat.members.filter {
                $0.leftAt == nil && $0.deletedAt == nil
            }.count
            return "\(activeMemberCount) members"
        }
        if partner?.isOnline == true {
            return "online"
        }
        guard let lastSeenAt = partner?.lastSeenAt else {
            return "offline"
        }
        return ChitChatDateFormatter.messageTime(from: lastSeenAt)
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = ChitChatColors.chatDetailScreen
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 62
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(
            top: ChitChatSpacing.chatDetailMessageTop,
            left: 0,
            bottom: ChitChatSpacing.chatDetailMessageBottom + 8,
            right: 0
        )
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.showsVerticalScrollIndicator = true
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            MessageBubbleCell.self,
            forCellReuseIdentifier: MessageBubbleCell.reuseIdentifier
        )

        let wallpaper = UIView()
        wallpaper.backgroundColor = ChitChatColors.chatDetailWallpaperOverlay
        tableView.backgroundView = wallpaper

        let refresh = UIRefreshControl()
        refresh.tintColor = ChitChatColors.accent
        refresh.addTarget(self, action: #selector(refreshMessages), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)
    }

    private func configureInputBar() {
        inputBar.onSend = { [weak self] text in
            self?.sendMessage(text)
        }
        inputBar.onAttach = { [weak self] in
            self?.showAttachmentSheet()
        }
        view.addSubview(inputBar)

        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
    }

    private func loadMessages() {
        guard loadTask == nil else { return }
        if !hasLoaded {
            showLoadingState()
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await messageService.listMessages(chatId: chat.id)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.messages = page.values
                        .filter { !$0.isDeletedForMe }
                        .sorted(by: self.sortMessages)
                    self.hasLoaded = true
                    self.tableView.reloadData()
                    self.tableView.refreshControl?.endRefreshing()
                    self.loadTask = nil

                    if self.messages.isEmpty {
                        self.showMessageState(
                            title: "No messages yet",
                            body: "Send a message to start this conversation"
                        )
                    } else {
                        self.hideStateOverlay()
                        self.scrollToBottom(animated: false)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.tableView.refreshControl?.endRefreshing()
                    self.loadTask = nil
                    if self.messages.isEmpty {
                        self.showMessageState(
                            title: "Unable to load chat",
                            body: error.localizedDescription
                        )
                    } else {
                        self.showAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func sendMessage(_ text: String) {
        guard sendTask == nil, mediaTask == nil else { return }
        inputBar.setSending(true)

        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let created = try await self.createMessage(
                    CreateMessageRequest(type: .text, text: text, attachments: nil)
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.mergeCreatedMessage(created)
                    self.inputBar.clearText()
                    self.inputBar.setSending(false)
                    self.sendTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.inputBar.restoreText(text)
                    self.inputBar.setSending(false)
                    self.sendTask = nil
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func createMessage(_ request: CreateMessageRequest) async throws -> Message {
        if SocketService.shared.isConnected {
            do {
                return try await SocketService.shared.sendMessage(
                    chatId: chat.id,
                    type: request.type,
                    text: request.text,
                    attachments: request.attachments
                )
            } catch {
                return try await messageService.sendMessage(chatId: chat.id, request: request)
            }
        }

        return try await messageService.sendMessage(chatId: chat.id, request: request)
    }

    private func mergeCreatedMessage(_ created: Message) {
        if let index = messages.firstIndex(where: { $0.id == created.id }) {
            messages[index] = created
        } else {
            messages.append(created)
            messages.sort(by: sortMessages)
        }
        hideStateOverlay()
        tableView.reloadData()
        scrollToBottom(animated: true)
    }

    private func showAttachmentSheet() {
        guard sendTask == nil, mediaTask == nil else { return }

        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        sheet.addAction(UIAlertAction(title: "Document", style: .default) { [weak self] _ in
            self?.presentDocumentPicker()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = inputBar
        sheet.popoverPresentationController?.sourceRect = inputBar.bounds
        present(sheet, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentDocumentPicker() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func uploadAndSendImage(fileURL: URL, fileName: String, mimeType: String) {
        uploadAndSendMedia(
            fileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            usage: .message,
            resourceType: .image,
            messageType: .image,
            text: nil
        )
    }

    private func uploadAndSendDocument(fileURL: URL, fileName: String, mimeType: String) {
        uploadAndSendMedia(
            fileURL: fileURL,
            fileName: fileName,
            mimeType: mimeType,
            usage: .document,
            resourceType: .raw,
            messageType: .document,
            text: nil
        )
    }

    private func uploadAndSendMedia(
        fileURL: URL,
        fileName: String,
        mimeType: String,
        usage: UploadUsage,
        resourceType: UploadResourceType,
        messageType: MessageType,
        text: String?
    ) {
        guard mediaTask == nil, sendTask == nil else { return }
        inputBar.setSending(true)
        let localFileSize = PickedMediaFile.fileSize(at: fileURL)

        mediaTask = Task { [weak self] in
            guard let self else { return }
            do {
                let upload: Upload
                do {
                    upload = try await uploadService.uploadLocalFile(
                        fileURL: fileURL,
                        fileName: fileName,
                        mimeType: mimeType,
                        usage: usage,
                        resourceType: resourceType
                    )
                } catch {
                    throw MediaSendError.uploadFailed
                }

                let attachment = upload.attachment.resolvingSize(localFileSize)
                let created: Message
                do {
                    created = try await self.createMessage(
                        CreateMessageRequest(
                            type: messageType,
                            text: text,
                            attachments: [attachment]
                        )
                    )
                } catch {
                    throw MediaSendError.sendFailed
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.mergeCreatedMessage(created)
                    self.inputBar.setSending(false)
                    self.mediaTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.inputBar.setSending(false)
                    self.mediaTask = nil
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func openMediaMessage(_ message: Message) {
        guard !message.isDeletedForEveryone, let attachment = message.primaryAttachment else { return }

        switch message.type {
        case .image:
            guard let url = URL(string: attachment.url), !attachment.url.isEmpty else { return }
            present(ImagePreviewViewController(imageURL: url), animated: true)
        case .document:
            guard let url = URL(string: attachment.url), !attachment.url.isEmpty else {
                showAlert(message: "Document URL is missing.")
                return
            }
            previewDocument(attachment: attachment, sourceURL: url)
        default:
            break
        }
    }

    private func previewDocument(attachment: MessageAttachment, sourceURL: URL) {
        documentPreviewTask?.cancel()
        documentPreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let localURL = try await self.localDocumentPreviewURL(
                    for: attachment,
                    sourceURL: sourceURL
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.documentPreviewTask = nil
                    self.presentDocumentPreview(localURL: localURL, fallbackURL: sourceURL)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.documentPreviewTask = nil
                    self.openExternalDocumentURL(sourceURL)
                }
            }
        }
    }

    private func localDocumentPreviewURL(
        for attachment: MessageAttachment,
        sourceURL: URL
    ) async throws -> URL {
        if sourceURL.isFileURL {
            if !sourceURL.pathExtension.isEmpty {
                return sourceURL
            }
            let fileName = PickedMediaFile.fileName(
                suggestedName: attachment.fileName,
                sourceURL: sourceURL,
                fallbackBase: "document-\(Int(Date().timeIntervalSince1970))",
                fallbackExtension: PickedMediaFile.preferredExtension(sourceURL: sourceURL, mimeType: attachment.mimeType),
                mimeType: attachment.mimeType
            )
            return try PickedMediaFile.copyToTemporaryFile(sourceURL: sourceURL, preferredFileName: fileName)
        }

        let (downloadedURL, response) = try await URLSession.shared.download(from: sourceURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw MediaSendError.previewDownloadFailed
        }
        let fallbackExtension = PickedMediaFile.preferredExtension(
            sourceURL: sourceURL,
            mimeType: attachment.mimeType
        )
        let fileName = PickedMediaFile.fileName(
            suggestedName: attachment.fileName ?? response.suggestedFilename,
            sourceURL: sourceURL,
            fallbackBase: "document-\(Int(Date().timeIntervalSince1970))",
            fallbackExtension: fallbackExtension,
            mimeType: attachment.mimeType
        )
        let destination = PickedMediaFile.uniqueTemporaryURL(
            preferredFileName: fileName,
            prefix: "chitchat-preview"
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: downloadedURL, to: destination)
        return destination
    }

    private func presentDocumentPreview(localURL: URL, fallbackURL: URL) {
        guard QLPreviewController.canPreview(localURL as NSURL) else {
            presentDocumentInteraction(localURL: localURL, fallbackURL: fallbackURL)
            return
        }

        let previewDataSource = DocumentPreviewDataSource(fileURL: localURL)
        let preview = QLPreviewController()
        preview.dataSource = previewDataSource
        documentPreviewDataSource = previewDataSource
        present(preview, animated: true)
    }

    private func presentDocumentInteraction(localURL: URL, fallbackURL: URL) {
        let interactionController = UIDocumentInteractionController(url: localURL)
        interactionController.delegate = self
        documentInteractionController = interactionController
        if !interactionController.presentPreview(animated: true) {
            let presentedOptions = interactionController.presentOptionsMenu(
                from: view.bounds,
                in: view,
                animated: true
            )
            if !presentedOptions {
                openExternalDocumentURL(fallbackURL)
            }
        }
    }

    private func openExternalDocumentURL(_ url: URL) {
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                if !opened {
                    self?.showAlert(message: MediaSendError.cannotOpenDocument.localizedDescription)
                }
            }
        }
    }

    private func observeRealtimeMessages() {
        let center = NotificationCenter.default
        socketObservers.append(
            center.addObserver(forName: .socketMessageNew, object: nil, queue: .main) {
                [weak self] notification in
                self?.handleRealtimeMessage(notification, isNew: true)
            }
        )

        [
            Notification.Name.socketMessageUpdated,
            .socketMessageDeleted,
            .socketMessageReactionUpdated,
            .socketMessageRead
        ].forEach { name in
            socketObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] notification in
                    self?.handleRealtimeMessage(notification, isNew: false)
                }
            )
        }
    }

    private func handleRealtimeMessage(_ notification: Notification, isNew: Bool) {
        guard
            let event = notification.object as? SocketMessageEvent,
            event.chatId == chat.id
        else { return }

        let shouldFollow = isNearBottom || event.message.senderId == currentUser.id
        if event.message.isDeletedForMe {
            messages.removeAll { $0.id == event.message.id }
        } else if let index = messages.firstIndex(where: { $0.id == event.message.id }) {
            guard messages[index] != event.message else { return }
            messages[index] = event.message
        } else {
            messages.append(event.message)
        }

        messages.sort(by: sortMessages)
        hasLoaded = true
        tableView.reloadData()
        if messages.isEmpty {
            showMessageState(
                title: "No messages yet",
                body: "Send a message to start this conversation"
            )
        } else {
            hideStateOverlay()
        }

        if isNew, event.message.senderId != currentUser.id, !event.message.isDeletedForEveryone {
            SocketService.shared.markRead(chatId: chat.id, messageId: event.message.id)
        }
        if shouldFollow {
            scrollToBottom(animated: true)
        }
    }

    private var isNearBottom: Bool {
        guard tableView.contentSize.height > 0 else { return true }
        let visibleBottom = tableView.contentOffset.y + tableView.bounds.height
        return tableView.contentSize.height - visibleBottom < 120
    }

    private func sortMessages(_ left: Message, _ right: Message) -> Bool {
        let leftDate = ChitChatDateFormatter.date(from: left.createdAt) ?? .distantPast
        let rightDate = ChitChatDateFormatter.date(from: right.createdAt) ?? .distantPast
        return leftDate < rightDate
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        DispatchQueue.main.async {
            self.tableView.scrollToRow(
                at: IndexPath(row: self.messages.count - 1, section: 0),
                at: .bottom,
                animated: animated
            )
        }
    }

    private func showLoadingState() {
        let overlay = makeStateOverlay()
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14

        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16)
        ])

        for index in 0..<5 {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.backgroundColor = .clear

            let skeleton = UIView()
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            skeleton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            skeleton.layer.cornerRadius = 22
            row.addSubview(skeleton)

            let widthMultiplier: CGFloat = index.isMultiple(of: 2) ? 0.68 : 0.74
            let sideConstraint = index.isMultiple(of: 2)
                ? skeleton.leadingAnchor.constraint(equalTo: row.leadingAnchor)
                : skeleton.trailingAnchor.constraint(equalTo: row.trailingAnchor)

            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 86),
                skeleton.topAnchor.constraint(equalTo: row.topAnchor),
                skeleton.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                skeleton.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: widthMultiplier),
                sideConstraint
            ])
            stack.addArrangedSubview(row)
        }
    }

    private func showMessageState(title: String, body: String) {
        let overlay = makeStateOverlay()
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = ChitChatColors.chatDetailStateBackground
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = ChitChatColors.chatDetailBorder.cgColor

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.font = ChitChatTypography.chatDetailStateTitle
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = body
        bodyLabel.textColor = ChitChatColors.textMuted
        bodyLabel.font = ChitChatTypography.chatDetailStateText
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        overlay.addSubview(card)
        card.addSubview(titleLabel)
        card.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 80),
            card.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 18),
            card.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -18),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
    }

    @discardableResult
    private func makeStateOverlay() -> UIView {
        hideStateOverlay()
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
        stateOverlay = overlay
        return overlay
    }

    private func hideStateOverlay() {
        stateOverlay?.removeFromSuperview()
        stateOverlay = nil
    }

    @objc private func refreshMessages() {
        loadMessages()
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func startVoiceCall() {
        guard chat.type == .direct else {
            showAlert(message: "Voice calls are available only in direct chats.")
            return
        }
        guard chat.otherParticipant(viewerUserId: currentUser.id) != nil else {
            showAlert(message: "Voice calls are available only in direct chats.")
            return
        }
        VoiceCallService.shared.startOutgoingVoiceCall(
            chat: chat,
            currentUser: currentUser,
            presenter: self
        )
    }

    @objc private func showVideoComingSoon() {
        showAlert(message: "Video calls are coming later.")
    }
}

extension ChatDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MessageBubbleCell.reuseIdentifier,
            for: indexPath
        ) as? MessageBubbleCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        cell.configure(message: message, isOutgoing: message.senderId == currentUser.id)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let messageID = messages[indexPath.row].id
        guard !animatedMessageIDs.contains(messageID) else { return }
        animatedMessageIDs.insert(messageID)

        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(
            withDuration: 0.22,
            delay: min(Double(indexPath.row) * 0.018, 0.22),
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        openMediaMessage(messages[indexPath.row])
    }
}

extension ChatDetailViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }

        let typeIdentifier = provider.registeredTypeIdentifiers.first {
            guard let type = UTType($0) else { return false }
            return type.conforms(to: .image)
        } ?? UTType.image.identifier

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(message: error.localizedDescription)
                }
                return
            }
            guard let url else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Selected photo could not be read.")
                }
                return
            }

            do {
                let fileType = UTType(typeIdentifier)
                let fallbackExtension = fileType?.preferredFilenameExtension ?? "jpg"
                let mimeType = fileType?.preferredMIMEType
                    ?? UploadService.mimeType(for: url, fallback: "image/jpeg")
                let fileName = PickedMediaFile.fileName(
                    suggestedName: provider.suggestedName,
                    sourceURL: url,
                    fallbackBase: "photo-\(Int(Date().timeIntervalSince1970))",
                    fallbackExtension: fallbackExtension,
                    mimeType: mimeType
                )
                let tempURL = try PickedMediaFile.copyToTemporaryFile(
                    sourceURL: url,
                    preferredFileName: fileName
                )
                DispatchQueue.main.async {
                    self.uploadAndSendImage(fileURL: tempURL, fileName: fileName, mimeType: mimeType)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(message: MediaSendError.fileCopyFailed.localizedDescription)
                }
            }
        }
    }
}

extension ChatDetailViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let contentType = PickedMediaFile.contentType(for: url)
            let mimeType = contentType?.preferredMIMEType ?? UploadService.mimeType(for: url)
            let fallbackExtension = contentType?.preferredFilenameExtension
                ?? PickedMediaFile.preferredExtension(sourceURL: url, mimeType: mimeType)
            let fileName = PickedMediaFile.fileName(
                suggestedName: nil,
                sourceURL: url,
                fallbackBase: "document-\(Int(Date().timeIntervalSince1970))",
                fallbackExtension: fallbackExtension,
                mimeType: mimeType
            )
            let tempURL = try PickedMediaFile.coordinatedCopyToTemporaryFile(
                sourceURL: url,
                preferredFileName: fileName
            )
            uploadAndSendDocument(fileURL: tempURL, fileName: fileName, mimeType: mimeType)
        } catch {
            showAlert(message: MediaSendError.fileCopyFailed.localizedDescription)
        }
    }
}

extension ChatDetailViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        self
    }
}
