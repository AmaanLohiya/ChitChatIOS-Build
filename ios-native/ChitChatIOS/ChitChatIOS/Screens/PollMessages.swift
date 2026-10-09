import UIKit

struct PollDraft: Codable, Equatable {
    let question: String
    let options: [String]
    static func clean(_ value: String) -> String { value.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines) }
    var normalized: PollDraft { PollDraft(question: Self.clean(question), options: options.map(Self.clean)) }
    var validationError: String? {
        let p = normalized
        if p.question.isEmpty || p.question.utf16.count > 300 { return "Enter a question of 1-300 characters." }
        if !(2...10).contains(p.options.count) || p.options.contains(where: { $0.isEmpty || $0.utf16.count > 100 }) { return "Add 2-10 answers, each 1-100 characters." }
        if ([p.question] + p.options).contains(where: { $0.range(of: "[\\x{0000}-\\x{001f}\\x{007f}-\\x{009f}\\x{202a}-\\x{202e}\\x{2066}-\\x{2069}]", options: .regularExpression) != nil }) { return "Remove unsupported control characters." }
        if Set(p.options.map { $0.lowercased() }).count != p.options.count { return "Each answer must be different." }
        return nil
    }
}

struct MessagePoll: Codable, Equatable {
    struct Option: Codable, Equatable { let id: String; let text: String; var votes: Int? = nil; var percentage: Int? = nil }
    let question: String
    let options: [Option]
    var totalVotes: Int? = nil
    var currentUserOptionId: String? = nil
    var isValid: Bool {
        PollDraft(question: question, options: options.map(\.text)).validationError == nil &&
        options.allSatisfy { !$0.id.isEmpty } && Set(options.map(\.id)).count == options.count
    }
    var hasResults: Bool {
        guard isValid, let totalVotes, totalVotes >= 0, totalVotes <= 1_000_000_000,
              options.allSatisfy({ ($0.votes ?? -1) >= 0 && ($0.votes ?? Int.max) <= totalVotes && (0...100).contains($0.percentage ?? -1) }) else { return false }
        return options.reduce(0, { $0 + ($1.votes ?? 0) }) == totalVotes &&
            (currentUserOptionId == nil || options.contains { $0.id == currentUserOptionId })
    }
    init(draft: PollDraft) {
        question = draft.question
        options = draft.options.enumerated().map { Option(id: "draft-\($0.offset)", text: $0.element) }
    }
    enum CodingKeys: String, CodingKey { case question, options, totalVotes, currentUserOptionId }
    init(from decoder: Decoder) throws {
        let values = try? decoder.container(keyedBy: CodingKeys.self)
        question = (try? values?.decode(String.self, forKey: .question)) ?? ""
        options = (try? values?.decode([Option].self, forKey: .options)) ?? []
        totalVotes = try? values?.decode(Int.self, forKey: .totalVotes)
        currentUserOptionId = try? values?.decode(String.self, forKey: .currentUserOptionId)
    }
}

@MainActor
final class PollCreationViewController: UIViewController, UITextFieldDelegate {
    var onSend: ((PollDraft) -> Void)?
    private let stack = UIStackView()
    private let question = UITextField()
    private let optionsStack = UIStackView()
    private let addButton = UIButton(type: .system)
    private let validation = UILabel()
    private var fields: [UITextField] = []
    private var submitted = false
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Create poll"; view.backgroundColor = ChitChatColors.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Review", style: .done, target: self, action: #selector(review))
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)
        stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        let description = UILabel(); description.text = "Single choice. Results show counts, not voter names."; description.numberOfLines = 0
        description.font = .systemFont(ofSize: 13); description.textColor = ChitChatColors.textMuted; stack.addArrangedSubview(description)
        configure(question, placeholder: "Question (up to 300 characters)"); stack.addArrangedSubview(question)
        optionsStack.axis = .vertical; optionsStack.spacing = 12; stack.addArrangedSubview(optionsStack)
        addButton.setTitle("Add option", for: .normal); addButton.addTarget(self, action: #selector(addOption), for: .touchUpInside); stack.addArrangedSubview(addButton)
        validation.numberOfLines = 0; validation.font = .systemFont(ofSize: 13); validation.textColor = ChitChatColors.textMuted; stack.addArrangedSubview(validation)
        addOption(); addOption(); changed()
    }
    private func configure(_ field: UITextField, placeholder: String) {
        field.delegate = self
        field.placeholder = placeholder; field.borderStyle = .roundedRect; field.textColor = ChitChatColors.textPrimary
        field.backgroundColor = ChitChatColors.surface; field.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
        field.addTarget(self, action: #selector(changed), for: .editingChanged)
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let current = textField.text, let swiftRange = Range(range, in: current) else { return false }
        return current.replacingCharacters(in: swiftRange, with: string).utf16.count <= (textField === question ? 300 : 100)
    }
    @objc private func addOption() {
        guard fields.count < 10 else { return }
        let field = UITextField(); configure(field, placeholder: "Answer (up to 100 characters)"); fields.append(field); rebuildOptions()
    }
    private func rebuildOptions() {
        optionsStack.arrangedSubviews.forEach { optionsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (index, field) in fields.enumerated() {
            field.accessibilityLabel = "Option \(index + 1)"
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 10; row.addArrangedSubview(field)
            if fields.count > 2 {
                let remove = UIButton(type: .system); remove.setTitle("Remove", for: .normal)
                remove.setContentCompressionResistancePriority(.required, for: .horizontal)
                remove.addAction(UIAction { [weak self, weak field] _ in
                    guard let self, let field, self.fields.count > 2 else { return }
                    self.fields.removeAll { $0 === field }; self.rebuildOptions()
                }, for: .touchUpInside); row.addArrangedSubview(remove)
            }
            optionsStack.addArrangedSubview(row)
        }
        changed()
    }
    private var draft: PollDraft { PollDraft(question: question.text ?? "", options: fields.map { $0.text ?? "" }).normalized }
    @objc private func changed() {
        validation.text = draft.validationError; addButton.isEnabled = fields.count < 10 && !submitted
        navigationItem.rightBarButtonItem?.isEnabled = draft.validationError == nil && !submitted
    }
    @objc private func cancel() { guard !submitted else { return }; dismiss(animated: true) }
    @objc private func review() {
        let poll = draft
        guard !submitted, poll.validationError == nil, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Share this poll?", message: ([poll.question] + poll.options.enumerated().map { "\($0.offset + 1). \($0.element)" }).joined(separator: "\n\n"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Edit", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send poll", style: .default) { [weak self] _ in
            guard let self, !self.submitted else { return }; self.submitted = true; self.changed()
            let send = self.onSend; self.dismiss(animated: true) { send?(poll) }
        })
        present(alert, animated: true)
    }
}

@MainActor
final class PollMessageCardView: UIView {
    private let stack = UIStackView()
    private var message: Message?
    private var viewerID: String?
    private var results: MessagePoll?
    private var observers: [NSObjectProtocol] = []
    private var loadTask: Task<Void, Never>?
    private var voteTask: Task<Void, Never>?
    private var revision = 0
    private var voting = false
    private var errorText = ""
    override init(frame: CGRect) {
        super.init(frame: frame); translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: topAnchor, constant: 12), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)])
    }
    required init?(coder: NSCoder) { return nil }
    deinit { loadTask?.cancel(); voteTask?.cancel(); observers.forEach { NotificationCenter.default.removeObserver($0) } }
    func reset() {
        stop(); message = nil; results = nil; viewerID = nil; errorText = ""; voting = false
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
    }
    func configure(_ message: Message, viewerID: String) {
        reset(); self.message = message; self.viewerID = viewerID; render(); if window != nil { start() }
    }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { stop() } else { start() } }
    private func stop() {
        revision += 1; loadTask?.cancel(); loadTask = nil; voteTask?.cancel(); voteTask = nil; voting = false
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers = []
    }
    private var available: Bool {
        guard let message, message.poll?.isValid == true, !message.isDeletedForEveryone, !message.isDeletedForMe,
              message.id.range(of: "^[a-fA-F0-9]{24}$", options: .regularExpression) != nil else { return false }
        return viewerID != nil && viewerID == SessionManager.shared.authenticatedUser?.id
    }
    private func start() {
        guard observers.isEmpty, available else { return }
        let events: [Notification.Name] = [.socketPollUpdated, .socketMessageDeleted, .socketChatUpdated, .socketConnected, .socketDisconnected,
                     UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification, SessionManager.currentUserDidChange]
        observers = events.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor [weak self] in self?.receive(note) }
            }
        }
        reload()
    }
    private func receive(_ note: Notification) {
        guard let message else { return }
        if let chatID = note.userInfo?["chatId"] as? String, chatID != message.chatId { return }
        if let messageID = note.userInfo?["messageId"] as? String, messageID != message.id { return }
        if let chat = note.object as? Chat, chat.id != message.chatId { return }
        if let event = note.object as? SocketMessageEvent, event.chatId != message.chatId || event.message.id != message.id { return }
        if !available || note.name == .socketDisconnected || note.name == UIApplication.didEnterBackgroundNotification {
            revision += 1; loadTask?.cancel(); results = nil; render(); return
        }
        reload()
    }
    private var path: String { "/api/v1/chats/\(message?.chatId ?? "")/polls/\(message?.id ?? "")" }
    private func reload(preservingVoteError: Bool = false) {
        guard available else { return }
        revision += 1; let version = revision; loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result: MessagePoll = try await APIClient.shared.request(path)
                guard !Task.isCancelled, version == revision, available else { return }
                results = result.hasResults ? result : nil
                if !preservingVoteError || !result.hasResults { errorText = result.hasResults ? "" : "Poll unavailable" }
                render()
            } catch {
                guard !Task.isCancelled, version == revision else { return }
                results = nil; errorText = "Poll unavailable. Tap Refresh to try again."; render()
            }
        }
    }
    private func vote(_ optionID: String) {
        guard available, !voting, let results, results.currentUserOptionId != optionID else { return }
        voting = true; render()
        voteTask = Task { [weak self] in
            guard let self else { return }
            struct Vote: Encodable { let optionId: String }
            defer { if !Task.isCancelled { voting = false; render() } }
            do {
                let _: MessagePoll = try await APIClient.shared.request(path, method: .post, body: Vote(optionId: optionID))
                guard !Task.isCancelled, available else { return }; reload()
            } catch {
                guard !Task.isCancelled, available else { return }
                errorText = "Vote could not be confirmed. Refresh and try again."; reload(preservingVoteError: true)
            }
        }
    }
    private func label(_ text: String, bold: Bool = false) -> UILabel {
        let label = UILabel(); label.text = text; label.numberOfLines = 0
        label.font = .systemFont(ofSize: bold ? 16 : 13, weight: bold ? .semibold : .regular)
        label.textColor = bold ? ChitChatColors.textPrimary : ChitChatColors.textMuted; return label
    }
    private func render() {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        guard let poll = results ?? message?.poll, poll.isValid else { stack.addArrangedSubview(label("Poll unavailable")); return }
        stack.addArrangedSubview(label(poll.question, bold: true)); stack.addArrangedSubview(label("Choose one answer"))
        for option in poll.options {
            let result = results?.options.first { $0.id == option.id }; let selected = results?.currentUserOptionId == option.id
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain(); config.title = option.text
            config.image = UIImage(systemName: selected ? "largecircle.fill.circle" : "circle"); config.imagePadding = 8
            config.baseForegroundColor = selected ? ChitChatColors.accent : ChitChatColors.textPrimary
            config.titleLineBreakMode = .byWordWrapping; config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            button.configuration = config; button.contentHorizontalAlignment = .leading; button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.isEnabled = results != nil && available && !voting; button.accessibilityValue = selected ? "Selected" : "Not selected"
            button.addAction(UIAction { [weak self] _ in self?.vote(option.id) }, for: .touchUpInside)
            let row = UIStackView(); row.axis = .horizontal; row.alignment = .center; row.spacing = 6; row.addArrangedSubview(button)
            let counts = label(result.map { "\($0.votes ?? 0) / \($0.percentage ?? 0)%" } ?? "--")
            counts.textAlignment = .right; counts.widthAnchor.constraint(equalToConstant: 76).isActive = true; row.addArrangedSubview(counts); stack.addArrangedSubview(row)
            let progress = UIProgressView(progressViewStyle: .bar); progress.progressTintColor = ChitChatColors.accent; progress.trackTintColor = ChitChatColors.divider
            progress.progress = Float(result?.percentage ?? 0) / 100; stack.addArrangedSubview(progress)
        }
        stack.addArrangedSubview(label(results.map { "\($0.totalVotes ?? 0) votes" } ?? "Results unavailable"))
        let status = label(errorText); status.numberOfLines = 2; status.heightAnchor.constraint(equalToConstant: 34).isActive = true; stack.addArrangedSubview(status)
        let refresh = UIButton(type: .system); refresh.setTitle(voting ? "Updating..." : "Refresh", for: .normal); refresh.isEnabled = available && !voting
        refresh.addAction(UIAction { [weak self] _ in self?.reload() }, for: .touchUpInside); stack.addArrangedSubview(refresh)
    }
}
