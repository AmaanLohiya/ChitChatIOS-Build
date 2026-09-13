import UIKit
import CoreLocation
import MapKit

final class LocationMessageCardView: UIView {
    private let pin = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let hintLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        pin.tintColor = ChitChatColors.accent
        pin.contentMode = .scaleAspectFit
        pin.backgroundColor = ChitChatColors.surface
        pin.layer.cornerRadius = 14
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = ChitChatColors.textPrimary
        titleLabel.numberOfLines = 2
        addressLabel.font = .systemFont(ofSize: 13)
        addressLabel.textColor = ChitChatColors.textMuted
        addressLabel.numberOfLines = 3
        hintLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        hintLabel.textColor = ChitChatColors.accent
        hintLabel.text = "Open in Maps"
        let stack = UIStackView(arrangedSubviews: [pin, titleLabel, addressLabel, hintLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            pin.heightAnchor.constraint(equalToConstant: 90)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(_ location: MessageLocation?, preview: Bool = false) {
        let valid = location?.isValid == true
        titleLabel.text = valid ? location?.displayTitle : "Unsupported location"
        addressLabel.text = valid ? location?.displayAddress : "Location data is unavailable."
        hintLabel.isHidden = !valid || preview
    }

    static func openMaps(_ location: MessageLocation?) -> Bool {
        guard let location, location.isValid else { return false }
        let coordinate = CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = location.displayTitle
        return item.openInMaps(launchOptions: nil)
    }
}

final class LocationMessageViewController: UIViewController, CLLocationManagerDelegate {
    var onSend: ((MessageLocation) -> Void)?
    private let manager = CLLocationManager()
    private let card = LocationMessageCardView()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let retryButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var timeout: Timer?
    private var candidate: MessageLocation?
    private var acquiring = false
    private var active = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChitChatColors.background
        title = "Share this location?"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel))
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = ChitChatColors.textMuted
        statusLabel.font = .systemFont(ofSize: 14)
        spinner.color = ChitChatColors.accent
        retryButton.setTitle("Try again", for: .normal)
        retryButton.addTarget(self, action: #selector(acquire), for: .touchUpInside)
        settingsButton.setTitle("Open Settings", for: .normal)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        sendButton.setTitle("Send location", for: .normal)
        sendButton.backgroundColor = ChitChatColors.accent
        sendButton.setTitleColor(ChitChatColors.textOnAccent, for: .normal)
        sendButton.layer.cornerRadius = 18
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [statusLabel, spinner, card, retryButton, settingsButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        view.addSubview(sendButton)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            sendButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            sendButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            sendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            sendButton.heightAnchor.constraint(equalToConstant: 48),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        NotificationCenter.default.addObserver(self, selector: #selector(cancel), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        active = true
        acquire()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        active = false
        stop()
        candidate = nil
        manager.delegate = nil
    }

    deinit {
        timeout?.invalidate()
        manager.stopUpdatingLocation()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func acquire() {
        guard active, !acquiring else { return }
        manager.delegate = self
        candidate = nil
        card.isHidden = true
        sendButton.isEnabled = false
        sendButton.alpha = 0.4
        retryButton.isHidden = true
        settingsButton.isHidden = true
        acquiring = true
        spinner.startAnimating()
        statusLabel.text = "Finding current location..."
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            requestFix()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard active, acquiring else { return }
        requestFix()
    }

    private func requestFix() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            guard timeout == nil else { return }
            timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
                self?.fail("Location timed out. Please try again outdoors.")
            }
            manager.requestLocation()
        case .denied, .restricted:
            fail("Allow location access in Settings. If Location Services are off, turn them on and try again.", settings: true)
        case .notDetermined:
            break
        @unknown default:
            fail("Location access is unavailable.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard active, acquiring, let fix = locations.last,
              fix.horizontalAccuracy >= 0, abs(fix.timestamp.timeIntervalSinceNow) < 60 else { return }
        let value = MessageLocation(lat: fix.coordinate.latitude, lng: fix.coordinate.longitude)
        guard value.isValid else { fail("Unable to get your location. Please try again."); return }
        stop()
        candidate = value
        card.configure(value, preview: true)
        card.isHidden = false
        statusLabel.text = "Only this point will be shared. Your movement is not tracked."
        sendButton.isEnabled = true
        sendButton.alpha = 1
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard active, acquiring else { return }
        fail("Unable to get your location. Check Location Services and try again.", settings: true)
    }

    private func stop() {
        manager.stopUpdatingLocation()
        timeout?.invalidate()
        timeout = nil
        acquiring = false
        spinner.stopAnimating()
    }

    private func fail(_ message: String, settings: Bool = false) {
        stop()
        statusLabel.text = message
        retryButton.isHidden = false
        settingsButton.isHidden = !settings
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func cancel() {
        stop()
        candidate = nil
        dismiss(animated: true)
    }

    @objc private func send() {
        guard active, let value = candidate, value.isValid else { return }
        let callback = onSend
        candidate = nil
        onSend = nil
        sendButton.isEnabled = false
        stop()
        dismiss(animated: true) { callback?(value) }
    }
}
