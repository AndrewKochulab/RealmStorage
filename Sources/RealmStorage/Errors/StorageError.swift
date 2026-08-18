//
//  StorageError.swift
//  RealmStorage
//

import Foundation

/// Every error surfaced by RealmStorage.
///
/// v1 used several stringly-typed `LocalizedError` enums whose raw values doubled
/// as user-facing text. This replaces them with one exhaustive, matchable type so
/// callers can react to a specific failure instead of comparing strings.
public enum StorageError: Error, Sendable {

    // MARK: - Lifecycle

    /// `RealmStore.open()` has not been called, or it failed.
    case storeNotOpen

    /// Opening the underlying Realm failed.
    case openFailed(underlying: any Error)

    // MARK: - Encryption

    /// The system CSPRNG could not produce a 64-byte key.
    ///
    /// Realm requires an encryption key of exactly 64 bytes. v1 silently fell back
    /// to 32 bytes here, which produced a key Realm rejects at open time.
    case encryptionKeyGenerationFailed(status: OSStatus)

    /// A key was found but is not the 64 bytes Realm requires.
    case encryptionKeyInvalidLength(expected: Int, actual: Int)

    // MARK: - Keychain

    /// A `SecItem*` call failed. `status` is the raw `OSStatus`.
    case keychain(status: OSStatus)

    // MARK: - Storage

    /// The storage directory could not be resolved or created.
    case storageDirectoryUnavailable

    /// Migrating the on-disk file from unencrypted to encrypted failed.
    case fileMigrationFailed(underlying: any Error)

    /// The database was detected as unrecoverable and `CorruptionPolicy` allowed deletion.
    case databaseWasReset(underlying: any Error)

    // MARK: - Access

    /// A primary-key lookup found no object.
    case objectNotFound
}

extension StorageError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .storeNotOpen:
            return "The store is not open. Call `open()` before using it."
        case .openFailed(let underlying):
            return "Opening the database failed: \(underlying.localizedDescription)"
        case .encryptionKeyGenerationFailed(let status):
            return "Generating a 64-byte database encryption key failed (OSStatus \(status))."
        case .encryptionKeyInvalidLength(let expected, let actual):
            return "The database encryption key is \(actual) bytes; Realm requires exactly \(expected)."
        case .keychain(let status):
            return "A Keychain operation failed (OSStatus \(status))."
        case .storageDirectoryUnavailable:
            return "The database storage directory could not be resolved."
        case .fileMigrationFailed(let underlying):
            return "Migrating the database file failed: \(underlying.localizedDescription)"
        case .databaseWasReset(let underlying):
            return "The database was unrecoverable and has been reset: \(underlying.localizedDescription)"
        case .objectNotFound:
            return "No object matches that primary key."
        }
    }
}
