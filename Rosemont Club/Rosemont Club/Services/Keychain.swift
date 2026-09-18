import Foundation
import LocalAuthentication
import Security

enum KeychainError: LocalizedError {
    case userCancelled
    case authenticationFailed
    case biometryUnavailable
    case unexpected(OSStatus)

    var errorDescription: String? {
        switch self {
        case .userCancelled: "Unlock was cancelled."
        case .authenticationFailed: "We could not verify it was you. Sign in with your password instead."
        case .biometryUnavailable: "Face ID or Touch ID is not available on this device. Set a device passcode and enroll to use it."
        case .unexpected(let status): "Secure storage error (\(status))."
        }
    }
}

/// Small wrapper over the iOS Keychain. Items marked `biometric` are protected by a
/// `.biometryCurrentSet` access control, so reading them prompts for Face ID / Touch ID
/// and the item becomes unreadable if the enrolled biometrics change.
enum Keychain {
    static let service = Bundle.main.bundleIdentifier ?? "com.herbertindustries.Rosemont-Club"

    static func save(_ data: Data, account: String, biometric: Bool) throws {
        delete(account: account)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        if biometric {
            var error: Unmanaged<CFError>?
            guard let control = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                .biometryCurrentSet,
                &error
            ) else { throw KeychainError.biometryUnavailable }
            query[kSecAttrAccessControl as String] = control
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecNotAvailable || status == errSecParam { throw KeychainError.biometryUnavailable }
            throw KeychainError.unexpected(status)
        }
    }

    /// Reads an item. For biometric items the system shows the Face ID / Touch ID prompt
    /// using `prompt` as the reason.
    static func load(account: String, prompt: String? = nil) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let prompt {
            let context = LAContext()
            context.localizedReason = prompt
            context.localizedCancelTitle = "Use password"
            query[kSecUseAuthenticationContext as String] = context
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        case errSecUserCanceled: throw KeychainError.userCancelled
        case errSecAuthFailed, errSecInteractionNotAllowed: throw KeychainError.authenticationFailed
        default: throw KeychainError.unexpected(status)
        }
    }

    private static var silentContext: LAContext {
        let c = LAContext()
        c.interactionNotAllowed = true
        return c
    }

    /// Checks presence without triggering an authentication prompt (attributes only).
    static func exists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationContext as String: silentContext,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Device biometric capability, used for labels and to decide whether to offer the toggle.
enum Biometrics {
    enum Kind { case none, touchID, faceID, opticID }

    static var kind: Kind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    static var available: Bool { kind != .none }

    static var name: String {
        switch kind {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .none: "Biometrics"
        }
    }

    static var symbol: String {
        switch kind {
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "faceid"
        }
    }
}
