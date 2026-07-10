import UIKit

final class CallsViewController: BaseViewController {
    private struct CallItem {
        let name: String
        let avatarURL: String
        let direction: String
        let timestamp: String
        let duration: String?
        let isMissed: Bool
        let isVideo: Bool
    }

    private let calls = [
        CallItem(name: "Sarah Johnson", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Sarah", direction: "Outgoing", timestamp: "Today, 2:30 PM", duration: "45:23", isMissed: false, isVideo: true),
        CallItem(name: "Mike Chen", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Mike", direction: "Incoming", timestamp: "Today, 11:15 AM", duration: "12:45", isMissed: false, isVideo: false),
        CallItem(name: "Emma Wilson", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Emma", direction: "Missed", timestamp: "Yesterday, 8:20 PM", duration: nil, isMissed: true, isVideo: true),
        CallItem(name: "Alex Martinez", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Alex", direction: "Outgoing", timestamp: "Yesterday, 3:45 PM", duration: "5:12", isMissed: false, isVideo: false)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
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
        let actions = UIStackView(arrangedSubviews: [makeIcon("magnifyingglass", color: ChitChatColors.textMuted), makeIcon("phone", color: ChitChatColors.accent)])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .horizontal
        actions.spacing = 4
        header.addSubview(title)
        header.addSubview(actions)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        calls.forEach { stack.addArrangedSubview(makeCallRow($0)) }

        view.addSubview(header)
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),
            actions.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            actions.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }

    private func makeCallRow(_ item: CallItem) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor(hex: "#0A1F2C")
        row.heightAnchor.constraint(equalToConstant: 80).isActive = true
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: item.name, urlString: item.avatarURL)
        let name = UILabel()
        name.translatesAutoresizingMaskIntoConstraints = false
        name.text = item.name
        name.textColor = item.isMissed ? UIColor(hex: "#F16458") : ChitChatColors.textPrimary
        name.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        let directionIcon = UIImageView(image: UIImage(systemName: item.isMissed ? "phone.down.fill" : item.direction == "Incoming" ? "phone.arrow.down.left" : "phone.arrow.up.right"))
        directionIcon.translatesAutoresizingMaskIntoConstraints = false
        directionIcon.tintColor = item.isMissed ? UIColor(hex: "#F16458") : item.direction == "Incoming" ? ChitChatColors.accent : ChitChatColors.textMuted
        let direction = UILabel()
        direction.translatesAutoresizingMaskIntoConstraints = false
        direction.text = item.duration.map { "\(item.direction) - \($0)" } ?? item.direction
        direction.textColor = ChitChatColors.textMuted
        direction.font = UIFont.systemFont(ofSize: 9.5, weight: .medium)
        let timestamp = UILabel()
        timestamp.translatesAutoresizingMaskIntoConstraints = false
        timestamp.text = item.timestamp
        timestamp.textColor = ChitChatColors.textMuted
        timestamp.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        let action = UIImageView(image: UIImage(systemName: item.isVideo ? "video" : "phone"))
        action.translatesAutoresizingMaskIntoConstraints = false
        action.tintColor = ChitChatColors.accent
        action.contentMode = .scaleAspectFit

        row.addSubview(avatar)
        row.addSubview(name)
        row.addSubview(directionIcon)
        row.addSubview(direction)
        row.addSubview(timestamp)
        row.addSubview(action)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 14),
            name.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 9),
            directionIcon.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            directionIcon.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 5),
            directionIcon.widthAnchor.constraint(equalToConstant: 18),
            directionIcon.heightAnchor.constraint(equalToConstant: 18),
            direction.leadingAnchor.constraint(equalTo: directionIcon.trailingAnchor, constant: 6),
            direction.centerYAnchor.constraint(equalTo: directionIcon.centerYAnchor),
            action.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            action.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: 34),
            action.heightAnchor.constraint(equalToConstant: 34),
            timestamp.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -8),
            timestamp.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func makeIcon(_ symbol: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = color
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.widthAnchor.constraint(equalToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return button
    }
}
