import ImageIO
import UIKit

struct ChitChatSticker: Equatable {
    let packId: String
    let stickerId: String
    let name: String
    let shortLabel: String
    let accent: UIColor
}

enum ChitChatStickerCatalog {
    static let packId = "chitchat-default"
    static let stickers: [ChitChatSticker] = [
        .init(packId: packId, stickerId: "thumbs-up", name: "Thumbs Up", shortLabel: "OK", accent: UIColor(hex: "#4BC5A6")),
        .init(packId: packId, stickerId: "heart", name: "Heart", shortLabel: "LOVE", accent: UIColor(hex: "#EF6A8A")),
        .init(packId: packId, stickerId: "laugh", name: "Laugh", shortLabel: "LOL", accent: UIColor(hex: "#F4A32E")),
        .init(packId: packId, stickerId: "wow", name: "Wow", shortLabel: "WOW", accent: UIColor(hex: "#7C8CF8")),
        .init(packId: packId, stickerId: "hello", name: "Hello", shortLabel: "HI", accent: UIColor(hex: "#58A7F5")),
        .init(packId: packId, stickerId: "thanks", name: "Thanks", shortLabel: "TY", accent: UIColor(hex: "#65D072")),
        .init(packId: packId, stickerId: "on-it", name: "On It", shortLabel: "ON IT", accent: UIColor(hex: "#36B6D8")),
        .init(packId: packId, stickerId: "celebrate", name: "Celebrate", shortLabel: "YAY", accent: UIColor(hex: "#F7C948")),
        .init(packId: packId, stickerId: "good-night", name: "Good Night", shortLabel: "ZZZ", accent: UIColor(hex: "#9B87F5")),
        .init(packId: packId, stickerId: "spark", name: "Spark", shortLabel: "WOW", accent: UIColor(hex: "#FFB454")),
        .init(packId: packId, stickerId: "coffee", name: "Coffee", shortLabel: "BRB", accent: UIColor(hex: "#B7794A")),
        .init(packId: packId, stickerId: "done", name: "Done", shortLabel: "DONE", accent: UIColor(hex: "#38A169"))
    ]

    static func sticker(id: String?) -> ChitChatSticker? {
        guard let id else { return nil }
        return stickers.first { $0.stickerId == id }
    }
}

final class ChitChatStickerArtView: UIView {
    private let inner = UIView()
    private let label = UILabel()
    private let spark = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        layer.borderWidth = 2
        transform = CGAffineTransform(rotationAngle: -0.07)

        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.layer.cornerCurve = .continuous
        inner.transform = CGAffineTransform(rotationAngle: 0.07)
        addSubview(inner)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = UIColor(hex: "#06151F")
        label.font = UIFont.systemFont(ofSize: 14, weight: .black)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        inner.addSubview(label)

        spark.translatesAutoresizingMaskIntoConstraints = false
        spark.backgroundColor = ChitChatColors.background
        spark.layer.borderWidth = 2
        addSubview(spark)

        NSLayoutConstraint.activate([
            inner.centerXAnchor.constraint(equalTo: centerXAnchor),
            inner.centerYAnchor.constraint(equalTo: centerYAnchor),
            inner.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.64),
            inner.heightAnchor.constraint(equalTo: inner.widthAnchor),
            label.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: inner.centerYAnchor),
            spark.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            spark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            spark.widthAnchor.constraint(equalToConstant: 14),
            spark.heightAnchor.constraint(equalTo: spark.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width * 0.22
        inner.layer.cornerRadius = inner.bounds.width * 0.2
        spark.layer.cornerRadius = spark.bounds.width / 2
    }

    func configure(_ sticker: ChitChatSticker?) {
        let value = sticker
        let accent = value?.accent ?? ChitChatColors.accent
        layer.borderColor = accent.cgColor
        backgroundColor = accent.withAlphaComponent(0.16)
        inner.backgroundColor = accent
        spark.layer.borderColor = accent.cgColor
        label.text = value?.shortLabel ?? "STK"
    }
}

final class AnimatedGIFImageView: UIImageView {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        cache.countLimit = 16
        return cache
    }()
    private var task: URLSessionDataTask?
    private var representedURL: String?
    private let stateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        stateLabel.textColor = ChitChatColors.textMuted
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 2
        addSubview(stateLabel)
        NSLayoutConstraint.activate([
            stateLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            stateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            stateLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { nil }
    deinit { task?.cancel() }

    func load(urlString: String) {
        cancelLoad()
        representedURL = urlString
        stateLabel.text = "Loading GIF..."
        guard MessageGif.isAllowedURL(urlString), let url = URL(string: urlString) else {
            stateLabel.text = "GIF unavailable"
            return
        }
        if let cached = Self.cache.object(forKey: urlString as NSString) {
            image = cached
            stateLabel.text = nil
            return
        }
        task = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 15)) { [weak self] data, response, _ in
            var decoded: UIImage?
            if let data, data.count <= 10 * 1024 * 1024,
               let response = response as? HTTPURLResponse, response.statusCode == 200,
               MessageGif.isAllowedURL(response.url?.absoluteString ?? "") {
                decoded = UIImage.boundedGIF(data: data)
            }
            if let decoded {
                let cost = Int(decoded.size.width * decoded.size.height) * 4 * max(decoded.images?.count ?? 1, 1)
                Self.cache.setObject(decoded, forKey: urlString as NSString, cost: cost)
            }
            DispatchQueue.main.async {
                guard let self, self.representedURL == urlString else { return }
                self.image = decoded
                self.stateLabel.text = decoded == nil ? "GIF unavailable" : nil
            }
        }
        task?.resume()
    }

    func cancelLoad() {
        task?.cancel()
        task = nil
        representedURL = nil
        stopAnimating()
        image = nil
        stateLabel.text = nil
    }
}

private extension UIImage {
    static func boundedGIF(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 1000 else { return nil }
        let step = max(1, Int(ceil(Double(count) / 40)))
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.08
            duration += delay.isFinite ? min(1, max(delay, 0.04)) : 0.08
            guard index % step == 0 else { continue }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 220, kCGImageSourceShouldCacheImmediately: true]
            if let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) {
                frames.append(UIImage(cgImage: frame))
            }
        }
        guard let first = frames.first else { return nil }
        return frames.count == 1 ? first : UIImage.animatedImage(with: frames, duration: max(duration, 0.1))
    }
}

final class StickerPickerViewController: UIViewController {
    var onSend: ((MessageSticker) -> Void)?
    private let scrollView = UIScrollView()
    private let grid = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Stickers"
        view.backgroundColor = ChitChatColors.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        buildGrid()
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    private func buildGrid() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.axis = .vertical
        grid.spacing = 12
        scrollView.addSubview(grid)

        let titleLabel = UILabel()
        titleLabel.text = "ChitChat Stickers"
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        grid.addArrangedSubview(titleLabel)

        var row: UIStackView?
        for (index, sticker) in ChitChatStickerCatalog.stickers.enumerated() {
            if index % 3 == 0 {
                row = UIStackView()
                row?.axis = .horizontal
                row?.spacing = 10
                row?.distribution = .fillEqually
                if let row { grid.addArrangedSubview(row) }
            }
            row?.addArrangedSubview(button(for: sticker))
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            grid.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            grid.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func button(for sticker: ChitChatSticker) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = sticker.name
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 104, leading: 4, bottom: 12, trailing: 4)
        configuration.baseForegroundColor = ChitChatColors.textPrimary
        configuration.background.backgroundColor = ChitChatColors.chatDetailInput
        configuration.background.cornerRadius = 18
        let button = UIButton(configuration: configuration)
        button.heightAnchor.constraint(equalToConstant: 138).isActive = true
        let art = ChitChatStickerArtView()
        art.configure(sticker)
        button.addSubview(art)
        NSLayoutConstraint.activate([
            art.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            art.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            art.widthAnchor.constraint(equalToConstant: 78),
            art.heightAnchor.constraint(equalTo: art.widthAnchor)
        ])
        button.addAction(UIAction { [weak self] _ in
            self?.confirm(sticker)
        }, for: .touchUpInside)
        return button
    }

    private func confirm(_ sticker: ChitChatSticker) {
        let alert = UIAlertController(title: "Send this sticker?", message: sticker.name, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { [onSend = self.onSend] in
                onSend?(MessageSticker(packId: sticker.packId, stickerId: sticker.stickerId))
            }
        })
        present(alert, animated: true)
    }
}

private struct GifSearchResponse: Decodable {
    let provider: String
    let providerConfigured: Bool
    let items: [GifSearchItem]
    let nextOffset: Int?
    let unavailableReason: String?
}

private struct GifSearchItem: Decodable, Hashable {
    let provider: String
    let providerId: String
    let title: String
    let mediaUrl: String
    let previewUrl: String
    let width: Int
    let height: Int

    var messageGif: MessageGif {
        MessageGif(
            provider: provider,
            providerId: providerId,
            mediaUrl: mediaUrl,
            previewUrl: previewUrl,
            width: width,
            height: height
        )
    }
}

private final class GifCell: UICollectionViewCell {
    static let reuseIdentifier = "GifCell"
    private let imageView = AnimatedGIFImageView()
    private let badge = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = ChitChatColors.chatDetailInput
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "GIF"
        badge.textColor = .white
        badge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.56)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        contentView.addSubview(badge)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            badge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            badge.widthAnchor.constraint(equalToConstant: 34),
            badge.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelLoad()
    }

    func configure(_ item: GifSearchItem) {
        imageView.load(urlString: item.previewUrl)
    }
}

final class GifPickerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {
    var onSend: ((MessageGif) -> Void)?
    private let searchBar = UISearchBar()
    private let statusLabel = UILabel()
    private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var items: [GifSearchItem] = []
    private var searchTask: Task<Void, Never>?
    private var requestID = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GIFs by GIPHY"
        view.backgroundColor = ChitChatColors.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Retry", style: .plain, target: self, action: #selector(retrySearch))
        buildUI()
        load(query: "")
    }

    deinit { searchTask?.cancel() }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    private func buildUI() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search GIFs"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        view.addSubview(searchBar)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GifCell.self, forCellWithReuseIdentifier: GifCell.reuseIdentifier)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchBar.heightAnchor.constraint(equalToConstant: 50),
            statusLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            collectionView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        requestID = UUID()
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.load(query: String(searchText.prefix(50))) }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        load(query: searchBar.text ?? "")
    }

    @objc private func retrySearch() { load(query: searchBar.text ?? "") }

    private func load(query: String) {
        requestID = UUID()
        let token = requestID
        statusLabel.text = "Loading GIFs..."
        items = []
        collectionView.reloadData()
        let normalized = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response: GifSearchResponse = try await APIClient.shared.request(
                    normalized.isEmpty ? "/api/v1/gifs/trending" : "/api/v1/gifs/search",
                    queryItems: normalized.isEmpty ? [URLQueryItem(name: "limit", value: "24")] : [
                        URLQueryItem(name: "q", value: normalized),
                        URLQueryItem(name: "limit", value: "24")
                    ]
                )
                await MainActor.run {
                    guard self.requestID == token, !Task.isCancelled else { return }
                    if !response.providerConfigured {
                        self.statusLabel.text = "GIF search is temporarily unavailable."
                    } else if response.items.isEmpty {
                        self.statusLabel.text = "No GIFs found."
                    } else {
                        self.statusLabel.text = ""
                    }
                    self.items = response.items
                    self.collectionView.reloadData()
                }
            } catch {
                await MainActor.run {
                    guard self.requestID == token, !Task.isCancelled else { return }
                    self.statusLabel.text = "Unable to load GIFs right now. Tap Retry."
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GifCell.reuseIdentifier, for: indexPath) as? GifCell ?? GifCell()
        if items.indices.contains(indexPath.item) { cell.configure(items[indexPath.item]) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.item) else { return }
        let item = items[indexPath.item]
        presentPreview(item)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 10) / 2)
        return CGSize(width: width, height: width * 1.12)
    }

    private func presentPreview(_ item: GifSearchItem) {
        let preview = UIViewController()
        preview.view.backgroundColor = ChitChatColors.background
        preview.title = "Send this GIF?"
        let imageView = AnimatedGIFImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.load(urlString: item.mediaUrl)
        preview.view.addSubview(imageView)
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissPreview))
        preview.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Send",
            primaryAction: UIAction { [weak self, weak preview] _ in
                preview?.dismiss(animated: true) {
                    guard let self else { return }
                    self.dismiss(animated: true) { [onSend = self.onSend] in
                        onSend?(item.messageGif)
                    }
                }
            }
        )
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: preview.view.safeAreaLayoutGuide.topAnchor, constant: 18),
            imageView.leadingAnchor.constraint(equalTo: preview.view.leadingAnchor, constant: 18),
            imageView.trailingAnchor.constraint(equalTo: preview.view.trailingAnchor, constant: -18),
            imageView.bottomAnchor.constraint(equalTo: preview.view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])
        present(UINavigationController(rootViewController: preview), animated: true)
    }

    @objc private func dismissPreview() {
        dismiss(animated: true)
    }
}

final class GifMessagePreviewController: UIViewController {
    private let gif: MessageGif
    private let imageView = AnimatedGIFImageView()
    init(gif: MessageGif) { self.gif = gif; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.background
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        imageView.load(urlString: gif.mediaUrl)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageView.cancelLoad()
    }
}
