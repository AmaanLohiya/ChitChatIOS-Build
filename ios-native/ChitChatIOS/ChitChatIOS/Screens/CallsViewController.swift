import UIKit

final class CallsViewController: BaseViewController {
    private let currentUser: User
    private let callHistoryService = CallHistoryService()
    private let chatService = ChatService()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let stateContainer = UIView()
    private let stateTitleLabel = UILabel()
    private let stateMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var history: [CallHistoryItem] = []
    private var filteredHistory: [CallHistoryItem] = []
    private var searchQuery = ""
    private var observers: [NSObjectProtocol] = []
    private var loadTask: Task<Void, Never>?
    private var isStartingCall = false

    init(currentUser: User) {
        self.currentUser = currentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
        observeHistoryUpdates()
        loadHistory(showLoading: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !history.isEmpty {
            loadHistory(showLoading: false)
        }
    }

    deinit {
        loadTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func buildUI() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Calls"
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 23, weight: .bold)

        let searchButton = makeIcon("magnifyingglass", color: ChitChatColors.textMuted)
        searchButton.accessibilityLabel = "Search calls"
        searchButton.addTarget(self, action: #selector(searchCalls), for: .touchUpInside)
        let newCallButton = makeIcon("phone", color: ChitChatColors.accent)
        newCallButton.accessibilityLabel = "Start new call"
        newCallButton.addTarget(self, action: #selector(startNewCall), for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [searchButton, newCallButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .horizontal
        actions.spacing = 4

        header.addSubview(title)
        header.addSubview(actions)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = ChitChatColors.background
        tableView.separatorStyle = .none
        tableView.rowHeight = 80
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset.bottom = 12
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CallHistoryCell.self, forCellReuseIdentifier: CallHistoryCell.reuseIdentifier)
        refreshControl.tintColor = ChitChatColors.accent
        refreshControl.addTarget(self, action: #selector(refreshHistory), for: .valueChanged)
        tableView.refreshControl = refreshControl

        stateContainer.translatesAutoresizingMaskIntoConstraints = false
        stateContainer.isHidden = true
        stateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateTitleLabel.textColor = ChitChatColors.textPrimary
        stateTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        stateTitleLabel.textAlignment = .center
        stateMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        stateMessageLabel.textColor = ChitChatColors.textMuted
        stateMessageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        stateMessageLabel.numberOfLines = 0
        stateMessageLabel.textAlignment = .center
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(ChitChatColors.background, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        retryButton.backgroundColor = ChitChatColors.accent
        retryButton.layer.cornerRadius = 21
        retryButton.addTarget(self, action: #selector(retryHistory), for: .touchUpInside)

        stateContainer.addSubview(stateTitleLabel)
        stateContainer.addSubview(stateMessageLabel)
        stateContainer.addSubview(retryButton)

        view.addSubview(header)
        view.addSubview(tableView)
        view.addSubview(stateContainer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),
            actions.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            actions.centerYAnchor.constraint(equalTo: title.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stateContainer.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -20),
            stateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            stateTitleLabel.topAnchor.constraint(equalTo: stateContainer.topAnchor),
            stateTitleLabel.leadingAnchor.constraint(equalTo: stateContainer.leadingAnchor),
            stateTitleLabel.trailingAnchor.constraint(equalTo: stateContainer.trailingAnchor),
            stateMessageLabel.topAnchor.constraint(equalTo: stateTitleLabel.bottomAnchor, constant: 8),
            stateMessageLabel.leadingAnchor.constraint(equalTo: stateContainer.leadingAnchor),
            stateMessageLabel.trailingAnchor.constraint(equalTo: stateContainer.trailingAnchor),
            retryButton.topAnchor.constraint(equalTo: stateMessageLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: stateContainer.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 104),
            retryButton.heightAnchor.constraint(equalToConstant: 42),
            retryButton.bottomAnchor.constraint(equalTo: stateContainer.bottomAnchor)
        ])
    }

    private func loadHistory(showLoading: Bool) {
        loadTask?.cancel()
        if showLoading && history.isEmpty {
            showState(title: "Loading calls...", message: "", retry: false)
        }

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let records = try await self.callHistoryService.listCalls()
                guard !Task.isCancelled else { return }
                self.history = self.sorted(records)
                self.applyFilter()
                self.refreshControl.endRefreshing()
                self.updateEmptyState()
            } catch {
                guard !Task.isCancelled else { return }
                self.refreshControl.endRefreshing()
                if self.history.isEmpty {
                    self.showState(
                        title: "Could not load calls",
                        message: error.localizedDescription,
                        retry: true
                    )
                }
            }
        }
    }

    private func observeHistoryUpdates() {
        let observer = NotificationCenter.default.addObserver(
            forName: .socketCallHistoryUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let item = notification.object as? CallHistoryItem else { return }
            self.history.removeAll { $0.callId == item.callId }
            self.history.append(item)
            self.history = self.sorted(self.history)
            self.applyFilter()
            self.updateEmptyState()
        }
        observers.append(observer)
    }

    private func applyFilter() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredHistory = query.isEmpty
            ? history
            : history.filter { $0.otherParticipant.displayName.lowercased().contains(query) }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        guard history.isEmpty else {
            stateContainer.isHidden = true
            tableView.isHidden = false
            return
        }
        showState(
            title: "No calls yet",
            message: "Your voice call history will appear here",
            retry: false
        )
    }

    private func showState(title: String, message: String, retry: Bool) {
        stateTitleLabel.text = title
        stateMessageLabel.text = message
        stateMessageLabel.isHidden = message.isEmpty
        retryButton.isHidden = !retry
        stateContainer.isHidden = false
        tableView.isHidden = history.isEmpty
    }

    private func sorted(_ records: [CallHistoryItem]) -> [CallHistoryItem] {
        records.sorted { callDate($0.initiatedAt) > callDate($1.initiatedAt) }
    }

    private func callDate(_ value: String) -> Date {
        if let date = Self.fractionalISOFormatter.date(from: value) { return date }
        return Self.isoFormatter.date(from: value) ?? .distantPast
    }

    private func detailText(for item: CallHistoryItem) -> String {
        let direction = item.direction == .incoming ? "Incoming" : "Outgoing"
        switch item.status {
        case .completed:
            return "\(direction) - \(formatDuration(item.durationSeconds))"
        case .missed:
            return item.direction == .incoming ? "Missed" : "Outgoing - No answer"
        case .rejected:
            return item.direction == .incoming ? "Incoming - Rejected" : "Rejected"
        case .cancelled:
            return item.direction == .incoming ? "Incoming - Cancelled" : "Cancelled"
        case .failed:
            return "\(direction) - Failed"
        case .answered:
            return "\(direction) - In call"
        case .ringing:
            return "\(direction) - Ringing"
        }
    }

    private func timestampText(for item: CallHistoryItem) -> String {
        let date = callDate(item.initiatedAt)
        guard date != .distantPast else { return "" }
        let calendar = Calendar.current
        let time = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Today, \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday, \(time)" }
        return Self.dayFormatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainder = safeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func startCall(from item: CallHistoryItem) {
        guard !isStartingCall else { return }
        isStartingCall = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isStartingCall = false }
            do {
                let chat = try await self.chatService.getChat(id: item.chatId)
                let user = SessionManager.shared.authenticatedUser ?? self.currentUser
                VoiceCallService.shared.startOutgoingVoiceCall(
                    chat: chat,
                    currentUser: user,
                    presenter: self
                )
            } catch {
                self.showAlert(title: "Could not start call", message: "Please try again.")
            }
        }
    }

    private func makeIcon(_ symbol: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = color
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.widthAnchor.constraint(equalToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return button
    }

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    @objc private func refreshHistory() {
        loadHistory(showLoading: false)
    }

    @objc private func retryHistory() {
        loadHistory(showLoading: true)
    }

    @objc private func startNewCall() {
        tabBarController?.selectedIndex = 1
    }

    @objc private func searchCalls() {
        let alert = UIAlertController(title: "Search calls", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.placeholder = "Participant name"
            field.text = self?.searchQuery
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self, weak alert] _ in
            self?.searchQuery = alert?.textFields?.first?.text ?? ""
            self?.applyFilter()
        })
        if !searchQuery.isEmpty {
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
                self?.searchQuery = ""
                self?.applyFilter()
            })
        }
        present(alert, animated: true)
    }
}
extension CallsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredHistory.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CallHistoryCell.reuseIdentifier,
                for: indexPath
            ) as? CallHistoryCell,
            filteredHistory.indices.contains(indexPath.row)
        else {
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }

        let item = filteredHistory[indexPath.row]
        cell.configure(
            item: item,
            detail: detailText(for: item),
            timestamp: timestampText(for: item)
        )
        cell.onCall = { [weak self] in
            self?.startCall(from: item)
        }
        return cell
    }
}
