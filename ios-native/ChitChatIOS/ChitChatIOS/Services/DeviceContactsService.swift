import Contacts
import CryptoKit
import Foundation

enum DeviceContactsAuthorizationState: Equatable {
    case undetermined
    case granted
    case denied
    case restricted
}

struct DeviceContactsSnapshot: Equatable {
    let entries: [ImportDeviceContactEntry]
    let fingerprint: String
    let addressBookContactCount: Int
    let normalizedPhoneCount: Int
}

enum DeviceContactsServiceError: LocalizedError {
    case permissionRequired

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Contacts permission is required to match device contacts."
        }
    }
}

final class DeviceContactsService {
    private static let importBatchSize = 500
    private static let maximumPhonesPerContact = 10
    private static let fingerprintKeyPrefix = "contacts.device-sync-fingerprint.v1"

    private let contactStore: CNContactStore
    private let queue: DispatchQueue
    private let defaults: UserDefaults

    init(
        contactStore: CNContactStore = CNContactStore(),
        queue: DispatchQueue = DispatchQueue(
            label: "com.chitchat.ios.device-contacts",
            qos: .userInitiated
        ),
        defaults: UserDefaults = .standard
    ) {
        self.contactStore = contactStore
        self.queue = queue
        self.defaults = defaults
    }

    func authorizationState() -> DeviceContactsAuthorizationState {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized {
            return .granted
        }
        if #available(iOS 18.0, *), status == .limited {
            return .granted
        }

        switch status {
        case .notDetermined:
            return .undetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .granted
        @unknown default:
            return .restricted
        }
    }

    func requestAuthorization() async -> DeviceContactsAuthorizationState {
        guard authorizationState() == .undetermined else {
            return authorizationState()
        }

        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            contactStore.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        return authorizationState()
    }

    func readSnapshot(defaultPhone: String?) async throws -> DeviceContactsSnapshot {
        guard authorizationState() == .granted else {
            throw DeviceContactsServiceError.permissionRequired
        }

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<DeviceContactsSnapshot, Error>) in
            queue.async { [contactStore] in
                do {
                    continuation.resume(
                        returning: try Self.makeSnapshot(
                            contactStore: contactStore,
                            defaultPhone: defaultPhone
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func lastSuccessfulFingerprint(for userID: String) -> String? {
        defaults.string(forKey: Self.fingerprintKey(for: userID))
    }

    func rememberSuccessfulFingerprint(_ fingerprint: String, for userID: String) {
        defaults.set(fingerprint, forKey: Self.fingerprintKey(for: userID))
    }

    func clearFingerprint(for userID: String) {
        defaults.removeObject(forKey: Self.fingerprintKey(for: userID))
    }

    func importBatches(for entries: [ImportDeviceContactEntry]) -> [[ImportDeviceContactEntry]] {
        stride(from: 0, to: entries.count, by: Self.importBatchSize).map { offset in
            Array(entries[offset..<min(offset + Self.importBatchSize, entries.count)])
        }
    }

    static func normalizePhoneNumber(_ value: String, defaultPhone: String?) -> String? {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        var formatted = raw.filter { $0.isNumber || $0 == "+" }
        if let firstPlus = formatted.firstIndex(of: "+") {
            let suffix = String(
                formatted[formatted.index(after: firstPlus)...].filter { $0 != "+" }
            )
            formatted = String(formatted[...firstPlus]) + suffix
        }

        if formatted.hasPrefix("00") {
            let international = "+" + String(formatted.dropFirst(2))
            return isValidE164(international) ? international : nil
        }
        if formatted.hasPrefix("+") {
            return isValidE164(formatted) ? formatted : nil
        }

        let digits = String(formatted.filter(\.isNumber))
        guard defaultPhone?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+91") == true else {
            return nil
        }
        if digits.range(of: "^[6-9][0-9]{9}$", options: .regularExpression) != nil {
            return "+91" + digits
        }
        if digits.range(of: "^0[6-9][0-9]{9}$", options: .regularExpression) != nil {
            return "+91" + String(digits.dropFirst())
        }
        if digits.range(of: "^91[6-9][0-9]{9}$", options: .regularExpression) != nil {
            return "+" + digits
        }
        return nil
    }

    private static func makeSnapshot(
        contactStore: CNContactStore,
        defaultPhone: String?
    ) throws -> DeviceContactsSnapshot {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true
        request.sortOrder = .userDefault

        let normalizedSelfPhone = defaultPhone.flatMap {
            normalizePhoneNumber($0, defaultPhone: defaultPhone)
        }
        var seenPhones = Set<String>()
        var entries: [ImportDeviceContactEntry] = []
        var addressBookContactCount = 0

        try contactStore.enumerateContacts(with: request) { contact, _ in
            addressBookContactCount += 1
            var entryPhones: [String] = []

            for labeledNumber in contact.phoneNumbers {
                guard entryPhones.count < maximumPhonesPerContact,
                      let normalized = normalizePhoneNumber(
                        labeledNumber.value.stringValue,
                        defaultPhone: defaultPhone
                      ),
                      normalized != normalizedSelfPhone,
                      seenPhones.insert(normalized).inserted else {
                    continue
                }
                entryPhones.append(normalized)
            }

            guard !entryPhones.isEmpty else { return }
            entries.append(
                ImportDeviceContactEntry(
                    name: displayName(for: contact),
                    phones: entryPhones
                )
            )
        }

        let fingerprintInput = seenPhones.sorted().joined(separator: "\n")
        let digest = SHA256.hash(data: Data(fingerprintInput.utf8))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        return DeviceContactsSnapshot(
            entries: entries,
            fingerprint: fingerprint,
            addressBookContactCount: addressBookContactCount,
            normalizedPhoneCount: seenPhones.count
        )
    }

    private static func displayName(for contact: CNContact) -> String {
        let name = [contact.givenName, contact.middleName, contact.familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String((name.isEmpty ? "Contact" : name).prefix(80))
    }

    private static func isValidE164(_ value: String) -> Bool {
        value.range(of: "^\\+[1-9][0-9]{7,14}$", options: .regularExpression) != nil
    }

    private static func fingerprintKey(for userID: String) -> String {
        "\(fingerprintKeyPrefix).\(userID)"
    }
}
