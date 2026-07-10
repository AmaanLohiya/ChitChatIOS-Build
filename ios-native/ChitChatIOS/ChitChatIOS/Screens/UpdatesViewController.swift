import UIKit

final class UpdatesViewController: BaseViewController {
    private struct StoryItem {
        let name: String
        let avatarURL: String
        let time: String
        let isNew: Bool
    }

    private let currentUser: User
    private let stories = [
        StoryItem(name: "Sarah Johnson", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Sarah", time: "2 hours ago", isNew: true),
        StoryItem(name: "Emma Wilson", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Emma", time: "3 hours ago", isNew: true),
        StoryItem(name: "Lisa Anderson", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Lisa", time: "5 hours ago", isNew: true),
        StoryItem(name: "Mike Chen", avatarURL: "https://api.dicebear.com/7.x/avataaars/png?seed=Mike", time: "Yesterday", isNew: false)
    ]

    init(currentUser: User) {
        self.currentUser = currentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = ChitChatColors.background
        buildUI()
    }

    private func buildUI() {
        let header = makeHeader()
        let strip = makeStoryStrip()
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 0
        content.addArrangedSubview(makeMyStatus())
        content.addArrangedSubview(makeSectionTitle("RECENT UPDATES", top: 10))
        stories.filter(\.isNew).forEach { content.addArrangedSubview(makeStoryRow($0)) }
        content.addArrangedSubview(makeSectionTitle("VIEWED UPDATES", top: 18))
        stories.filter { !$0.isNew }.forEach { content.addArrangedSubview(makeStoryRow($0)) }

        view.addSubview(header)
        view.addSubview(strip)
        view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            strip.topAnchor.constraint(equalTo: header.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 92),
            scroll.topAnchor.constraint(equalTo: strip.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -22),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = ChitChatColors.header
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Updates"
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        let actions = UIStackView(arrangedSubviews: [
            makeIcon("magnifyingglass"),
            makeIcon("ellipsis")
        ])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.axis = .horizontal
        actions.spacing = 2
        header.addSubview(title)
        header.addSubview(actions)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -10),
            actions.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            actions.centerYAnchor.constraint(equalTo: title.centerYAnchor)
        ])
        return header
    }

    private func makeStoryStrip() -> UIView {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.backgroundColor = ChitChatColors.header
        scroll.showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 10, right: 16)

        stack.addArrangedSubview(makeStripItem(name: "Your Story", url: currentUser.avatarUrl, isNew: false, showsPlus: true))
        stories.forEach {
            stack.addArrangedSubview(makeStripItem(name: $0.name.components(separatedBy: " ").first ?? $0.name, url: $0.avatarURL, isNew: $0.isNew, showsPlus: false))
        }
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        return scroll
    }

    private func makeStripItem(name: String, url: String, isNew: Bool, showsPlus: Bool) -> UIView {
        let container = UIView()
        container.widthAnchor.constraint(equalToConstant: 64).isActive = true
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: name, urlString: url)
        avatar.layer.borderWidth = 3
        avatar.layer.borderColor = (isNew ? ChitChatColors.accent : ChitChatColors.textMuted.withAlphaComponent(0.24)).cgColor
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = name
        label.textColor = isNew || showsPlus ? ChitChatColors.textPrimary : ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 10, weight: isNew || showsPlus ? .semibold : .regular)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        container.addSubview(avatar)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: container.topAnchor),
            avatar.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 52),
            avatar.heightAnchor.constraint(equalToConstant: 52),
            label.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        if showsPlus {
            let badge = UILabel()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.text = "+"
            badge.textAlignment = .center
            badge.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            badge.textColor = .white
            badge.backgroundColor = ChitChatColors.accent
            badge.layer.cornerRadius = 10
            badge.clipsToBounds = true
            container.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 2),
                badge.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 1),
                badge.widthAnchor.constraint(equalToConstant: 20),
                badge.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        return container
    }

    private func makeMyStatus() -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 88).isActive = true
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: currentUser.name, urlString: currentUser.avatarUrl)
        let plus = UILabel()
        plus.translatesAutoresizingMaskIntoConstraints = false
        plus.text = "+"
        plus.textAlignment = .center
        plus.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        plus.textColor = .white
        plus.backgroundColor = ChitChatColors.accent
        plus.layer.cornerRadius = 12
        plus.clipsToBounds = true
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "My Status"
        title.textColor = ChitChatColors.textPrimary
        title.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "Tap to add status update"
        subtitle.textColor = ChitChatColors.textMuted
        subtitle.font = UIFont.systemFont(ofSize: 12)
        row.addSubview(avatar)
        row.addSubview(plus)
        row.addSubview(title)
        row.addSubview(subtitle)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            plus.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 2),
            plus.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 1),
            plus.widthAnchor.constraint(equalToConstant: 24),
            plus.heightAnchor.constraint(equalToConstant: 24),
            title.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3)
        ])
        return row
    }

    private func makeSectionTitle(_ text: String, top: CGFloat) -> UIView {
        let wrap = UIView()
        wrap.heightAnchor.constraint(equalToConstant: top + 22).isActive = true
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = ChitChatColors.textMuted
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -8)
        ])
        return wrap
    }

    private func makeStoryRow(_ story: StoryItem) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 76).isActive = true
        row.alpha = story.isNew ? 1 : 0.64
        let avatar = ReplicaAvatarView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.configure(name: story.name, urlString: story.avatarURL)
        avatar.layer.borderWidth = 3
        avatar.layer.borderColor = (story.isNew ? ChitChatColors.accent : ChitChatColors.textMuted.withAlphaComponent(0.24)).cgColor
        let name = UILabel()
        name.translatesAutoresizingMaskIntoConstraints = false
        name.text = story.name
        name.textColor = ChitChatColors.textPrimary
        name.font = UIFont.systemFont(ofSize: 15, weight: story.isNew ? .bold : .semibold)
        let time = UILabel()
        time.translatesAutoresizingMaskIntoConstraints = false
        time.text = story.time
        time.textColor = ChitChatColors.textMuted
        time.font = UIFont.systemFont(ofSize: 12)
        row.addSubview(avatar)
        row.addSubview(name)
        row.addSubview(time)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 24),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            name.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 8),
            time.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            time.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3)
        ])
        return row
    }

    private func makeIcon(_ symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = ChitChatColors.textMuted
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }
}
