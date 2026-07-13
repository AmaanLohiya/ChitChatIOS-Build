import PhotosUI
import UIKit

final class StatusCreationViewController: BaseViewController, PHPickerViewControllerDelegate, UITextViewDelegate {
    var onCreated: (() -> Void)?

    private let statusService = StatusService()
    private let uploadService = UploadService()
    private let modeControl = UISegmentedControl(items: ["Text", "Image"])
    private let textView = UITextView()
    private let imageView = UIImageView()
    private let chooseImageButton = UIButton(type: .system)
    private let colorStack = UIStackView()
    private let publishButton = UIButton(type: .system)
    private let countLabel = UILabel()
    private var selectedStyle: StatusBackgroundStyle = .teal
    private var selectedImageURL: URL?
    private var uploadedMediaURL: String?
    private var isPublishing = false

    private let backgroundColors: [StatusBackgroundStyle: UIColor] = [
        .teal: UIColor(red: 0.09, green: 0.55, blue: 0.46, alpha: 1),
        .purple: UIColor(red: 0.39, green: 0.28, blue: 0.67, alpha: 1),
        .blue: UIColor(red: 0.10, green: 0.48, blue: 0.67, alpha: 1),
        .pink: UIColor(red: 0.69, green: 0.24, blue: 0.46, alpha: 1),
        .green: UIColor(red: 0.24, green: 0.53, blue: 0.30, alpha: 1),
        .orange: UIColor(red: 0.68, green: 0.38, blue: 0.17, alpha: 1)
    ]

    deinit {
        removeTemporaryImage()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyMode()
    }

    private func buildUI() {
        navigationItem.title = "New Status"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = ChitChatColors.header
        navigationController?.navigationBar.isTranslucent = false

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.22)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.tintColor = .white
        textView.font = UIFont.systemFont(ofSize: 29, weight: .bold)
        textView.textAlignment = .center
        textView.delegate = self
        textView.returnKeyType = .done
        textView.accessibilityLabel = "Status text"

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.text = "0/500"
        countLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        countLabel.font = UIFont.systemFont(ofSize: 12)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        chooseImageButton.translatesAutoresizingMaskIntoConstraints = false
        chooseImageButton.setTitle("Choose image", for: .normal)
        chooseImageButton.setTitleColor(.white, for: .normal)
        chooseImageButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        chooseImageButton.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        chooseImageButton.layer.cornerRadius = 22
        chooseImageButton.addTarget(self, action: #selector(chooseImageTapped), for: .touchUpInside)

        colorStack.translatesAutoresizingMaskIntoConstraints = false
        colorStack.axis = .horizontal
        colorStack.spacing = 10
        colorStack.distribution = .fillEqually
        for (index, style) in StatusBackgroundStyle.allCases.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.backgroundColor = backgroundColors[style]
            button.layer.cornerRadius = 19
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = style == selectedStyle ? 3 : 0
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorStack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        }

        publishButton.translatesAutoresizingMaskIntoConstraints = false
        publishButton.setTitle("Post Status", for: .normal)
        publishButton.setTitleColor(.white, for: .normal)
        publishButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        publishButton.backgroundColor = UIColor(white: 0.22, alpha: 1)
        publishButton.layer.cornerRadius = 29
        publishButton.addTarget(self, action: #selector(publishTapped), for: .touchUpInside)

        view.addSubview(modeControl)
        view.addSubview(textView)
        view.addSubview(countLabel)
        view.addSubview(imageView)
        view.addSubview(chooseImageButton)
        view.addSubview(colorStack)
        view.addSubview(publishButton)

        let keyboard = view.keyboardLayoutGuide
        let publishBottom = publishButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -14
        )
        publishBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 190),

            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            textView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -52),
            textView.heightAnchor.constraint(equalToConstant: 250),
            countLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 4),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            imageView.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 18),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: publishButton.topAnchor, constant: -20),
            chooseImageButton.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            chooseImageButton.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            chooseImageButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            chooseImageButton.heightAnchor.constraint(equalToConstant: 44),

            colorStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            colorStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            colorStack.bottomAnchor.constraint(equalTo: publishButton.topAnchor, constant: -18),

            publishButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            publishButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            publishBottom,
            publishButton.bottomAnchor.constraint(lessThanOrEqualTo: keyboard.topAnchor, constant: -10),
            publishButton.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private func applyMode() {
        let isText = modeControl.selectedSegmentIndex == 0
        textView.isHidden = !isText
        countLabel.isHidden = !isText
        colorStack.isHidden = !isText
        imageView.isHidden = isText
        chooseImageButton.isHidden = isText
        view.backgroundColor = isText ? backgroundColors[selectedStyle] : .black
        updatePublishState()
        if isText {
            textView.becomeFirstResponder()
        } else {
            textView.resignFirstResponder()
        }
    }

    private func updatePublishState() {
        let canPublish: Bool
        if modeControl.selectedSegmentIndex == 0 {
            canPublish = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            canPublish = selectedImageURL != nil
        }
        publishButton.isEnabled = canPublish && !isPublishing
        publishButton.alpha = publishButton.isEnabled ? 1 : 0.48
        chooseImageButton.isEnabled = !isPublishing
        modeControl.isEnabled = !isPublishing
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView.text.count > 500 {
            textView.text = String(textView.text.prefix(500))
        }
        countLabel.text = "\(textView.text.count)/500"
        updatePublishState()
    }

    @objc private func modeChanged() {
        applyMode()
    }

    @objc private func colorTapped(_ sender: UIButton) {
        guard StatusBackgroundStyle.allCases.indices.contains(sender.tag) else { return }
        selectedStyle = StatusBackgroundStyle.allCases[sender.tag]
        for (index, caseButton) in colorStack.arrangedSubviews.compactMap({ $0 as? UIButton }).enumerated() {
            caseButton.layer.borderWidth = index == sender.tag ? 3 : 0
        }
        view.backgroundColor = backgroundColors[selectedStyle]
    }

    @objc private func chooseImageTapped() {
        guard !isPublishing else { return }
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            showAlert(message: "The selected image could not be read.")
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard error == nil, let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.84) else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "The selected image could not be prepared.")
                }
                return
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("status-\(UUID().uuidString).jpg")
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(message: "The selected image could not be prepared.")
                }
                return
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.removeTemporaryImage()
                self.selectedImageURL = url
                self.uploadedMediaURL = nil
                self.imageView.image = image
                self.chooseImageButton.setTitle("Choose another image", for: .normal)
                self.updatePublishState()
            }
        }
    }

    @objc private func publishTapped() {
        view.endEditing(true)
        guard !isPublishing, publishButton.isEnabled else { return }
        isPublishing = true
        publishButton.setTitle("Posting...", for: .normal)
        updatePublishState()

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isPublishing = false
                self.publishButton.setTitle("Post Status", for: .normal)
                self.updatePublishState()
            }
            do {
                if self.modeControl.selectedSegmentIndex == 0 {
                    let text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    _ = try await self.statusService.createText(text: text, backgroundStyle: self.selectedStyle)
                } else {
                    guard let imageURL = self.selectedImageURL else { return }
                    var mediaURL = self.uploadedMediaURL
                    if mediaURL == nil {
                        let upload = try await self.uploadService.uploadLocalFile(
                            fileURL: imageURL,
                            fileName: imageURL.lastPathComponent,
                            mimeType: "image/jpeg",
                            usage: .story,
                            resourceType: .image
                        )
                        let uploadedURL = upload.secureUrl.isEmpty ? upload.url : upload.secureUrl
                        guard !uploadedURL.isEmpty else { throw UploadServiceError.invalidResponse }
                        self.uploadedMediaURL = uploadedURL
                        mediaURL = uploadedURL
                    }
                    guard let mediaURL else { throw UploadServiceError.invalidResponse }
                    _ = try await self.statusService.createImage(mediaURL: mediaURL)
                }
                self.onCreated?()
                self.dismiss(animated: true)
            } catch {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }

    @objc private func cancelTapped() {
        guard !isPublishing else { return }
        dismiss(animated: true)
    }

    private func removeTemporaryImage() {
        guard let selectedImageURL else { return }
        try? FileManager.default.removeItem(at: selectedImageURL)
        self.selectedImageURL = nil
    }
}
