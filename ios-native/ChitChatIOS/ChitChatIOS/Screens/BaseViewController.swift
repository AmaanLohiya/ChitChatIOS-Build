import UIKit

class BaseViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.authBackground
    }

    func showAlert(title: String = "ChitChat", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

final class SplashViewController: BaseViewController {
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.background

        let icon = UIImageView(image: UIImage(systemName: "message.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ChitChatColors.accent
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "ChitChat"
        title.font = ChitChatTypography.largeTitle
        title.textColor = ChitChatColors.textPrimary
        title.textAlignment = .center

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = ChitChatColors.accent
        spinner.startAnimating()

        view.addSubview(icon)
        view.addSubview(title)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -42),
            icon.widthAnchor.constraint(equalToConstant: 62),
            icon.heightAnchor.constraint(equalToConstant: 62),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 18),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            spinner.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 22),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

