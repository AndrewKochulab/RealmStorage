//
//  SecretStore.swift
//  RealmStorage
//

import Foundation

/// Persistent storage for a small secret — in practice, the Realm encryption key.
///
/// Extracting this behind a protocol is what makes the encryption path testable:
/// the real Keychain is awkward under `swift test`, so tests inject an in-memory
/// double instead of reaching for the system Keychain.
public protocol SecretStore: Sendable {

    /// Returns the stored data, or `nil` when no item exists for `key`.
    func data(forKey key: String) throws -> Data?

    /// Stores `data`, replacing any existing item for `key`.
    func set(_ data: Data, forKey key: String) throws

    /// Removes the item for `key`. Succeeds when no item exists.
    func removeData(forKey key: String) throws
}

/// An in-memory `SecretStore`, for tests and previews. Nothing is persisted.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {

    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func data(forKey key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func set(_ data: Data, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = data
    }

    public func removeData(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
