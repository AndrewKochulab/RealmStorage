//
//  KeychainSecretStore.swift
//  RealmStorage
//

import Foundation
import Security

/// When a Keychain item can be read.
///
/// A `Sendable` enum rather than a raw `CFString`, because `CFString` is a
/// non-`Sendable` class and cannot be stored in a `Sendable` type — and because the
/// four cases below are the only values that make sense for a database key.
public enum KeychainAccessibility: Sendable {

    /// Readable only while the device is unlocked.
    ///
    /// Avoid for a database key: an app woken in the background on a locked device
    /// cannot read it, so the database fails to open.
    case whenUnlocked

    /// As ``whenUnlocked``, but never included in a backup.
    case whenUnlockedThisDeviceOnly

    /// Readable after the first unlock following a boot, including in the background.
    case afterFirstUnlock

    /// As ``afterFirstUnlock``, but never included in a backup. **Default.**
    case afterFirstUnlockThisDeviceOnly

    var rawValue: CFString {
        switch self {
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

/// A `SecretStore` backed directly by the system Keychain.
///
/// This replaces v1's `KeychainSwift` dependency and its `Keychain`/`Keychain+Data`
/// helpers, which dispatched on `T.self == …` and force-cast with `as!`. Talking to
/// `SecItem*` directly is both smaller and the only way to control accessibility.
///
/// ## Accessibility
///
/// The default is ``KeychainAccessibility/afterFirstUnlockThisDeviceOnly``, **not**
/// `whenUnlocked` (what v1 inherited from KeychainSwift). With
/// `whenUnlocked`, an app woken in the background on a locked device cannot read the
/// encryption key, so opening the database fails — and in v1 that failure reached a
/// blanket `catch` that deleted the database. `afterFirstUnlock` closes that path.
///
/// `ThisDeviceOnly` means the key is not carried into an iCloud/iTunes backup. Pair it
/// with ``StorageLocation/excludedFromBackup`` so a restored device does not end up with
/// an encrypted file it has no key for.
public struct KeychainSecretStore: SecretStore {

    /// `kSecAttrService` for every item this store manages.
    public let service: String

    /// `kSecAttrAccessGroup`, for sharing a key across an app group.
    public let accessGroup: String?

    /// `kSecAttrAccessible`. See the type's discussion before changing this.
    public let accessibility: KeychainAccessibility

    public init(
        service: String = "io.realmstorage.encryption",
        accessGroup: String? = nil,
        accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    // MARK: - SecretStore

    public func data(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw StorageError.keychain(status: status)
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)

        // Update in place when the item already exists; SecItemAdd would return
        // errSecDuplicateItem and lose the new value.
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.rawValue
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw StorageError.keychain(status: updateStatus)
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = accessibility

        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw StorageError.keychain(status: addStatus)
        }
    }

    public func removeData(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)

        // Deleting something that was never there is not an error.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychain(status: status)
        }
    }

    // MARK: - Helpers

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        #if os(macOS)
        // Use the modern data-protection keychain on macOS so behaviour matches iOS.
        query[kSecUseDataProtectionKeychain as String] = true
        #endif

        return query
    }
}
