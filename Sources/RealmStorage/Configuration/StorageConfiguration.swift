//
//  StorageConfiguration.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Everything needed to open a database.
///
/// This is a `Sendable` value type. `Realm.Configuration` carries non-`Sendable`
/// closures, so it is built from this *inside* the store's actor rather than stored
/// and passed around — and, unlike v1, the process-global
/// `Realm.Configuration.defaultConfiguration` is never mutated. That global was what
/// made v1's tests order-dependent and a second database impossible.
public struct StorageConfiguration: Sendable {

    /// How the database file is protected at rest.
    public enum Encryption: Sendable {

        /// No encryption.
        case none

        /// Encrypt with a 64-byte key held in `store` under `account`.
        ///
        /// The key is generated on first use and reused thereafter.
        case keychain(store: any SecretStore, account: String = "encryptionKey")

        /// Encrypt with a key the caller supplies. Must be exactly 64 bytes.
        case key(Data)
    }

    // MARK: - Properties

    /// Where the file lives.
    public var location: StorageLocation

    /// The file name, without the `.realm` extension.
    public var fileName: String

    /// The schema version. Increment whenever your models change.
    public var schemaVersion: UInt64

    /// How the file is encrypted.
    public var encryption: Encryption

    /// What to do when the database cannot be opened. Defaults to ``CorruptionPolicy/rethrow``.
    public var corruptionPolicy: CorruptionPolicy

    /// Data-protection class applied to the database files.
    ///
    /// v1 set `.none` on the *containing directory*, which with the default location
    /// meant the whole Documents folder, and defeated data protection on a database it
    /// had gone to the trouble of encrypting. This applies to the Realm files only, and
    /// `.completeUntilFirstUserAuthentication` keeps background launches working without
    /// giving up protection entirely.
    ///
    /// Set to `nil` to leave the system default in place.
    public var fileProtection: FileProtectionType?

    /// Whether to exclude the database from iCloud/iTunes backups.
    ///
    /// Recommended when the encryption key is `ThisDeviceOnly`: a restored device would
    /// otherwise hold an encrypted file whose key did not come along.
    public var excludedFromBackup: Bool

    /// The model types belonging to this database.
    ///
    /// `nil` means every `Object` subclass in the process, which is Realm's default and
    /// is usually wrong once an app has more than one database.
    public var objectTypes: [Object.Type]?

    /// Called when the on-disk schema version is older than ``schemaVersion``.
    public var migrate: (@Sendable (Migration, UInt64) -> Void)?

    /// Whether to open the file read-only.
    public var isReadOnly: Bool

    /// Delete and recreate the database when the schema does not match, instead of
    /// migrating it.
    ///
    /// Convenient during development; **destroys user data** in production. Left off by
    /// default, and deliberately separate from ``corruptionPolicy``, which governs
    /// failures rather than schema drift.
    public var deleteRealmIfMigrationNeeded: Bool

    /// Whether to compact the database when opening it.
    ///
    /// Called with the file's total and used byte counts; return `true` to compact.
    /// Realm files only grow, so a long-lived database with heavy churn can hold a lot of
    /// dead space:
    ///
    /// ```swift
    /// configuration.shouldCompactOnLaunch = { total, used in
    ///     total > 100 * 1024 * 1024 && Double(used) / Double(total) < 0.5
    /// }
    /// ```
    public var shouldCompactOnLaunch: (@Sendable (Int, Int) -> Bool)?

    // MARK: - Initialization

    public init(
        location: StorageLocation = .applicationSupport,
        fileName: String = "default",
        schemaVersion: UInt64 = 1,
        encryption: Encryption = .none,
        corruptionPolicy: CorruptionPolicy = .rethrow,
        fileProtection: FileProtectionType? = .completeUntilFirstUserAuthentication,
        excludedFromBackup: Bool = true,
        objectTypes: [Object.Type]? = nil,
        isReadOnly: Bool = false,
        deleteRealmIfMigrationNeeded: Bool = false,
        shouldCompactOnLaunch: (@Sendable (Int, Int) -> Bool)? = nil,
        migrate: (@Sendable (Migration, UInt64) -> Void)? = nil
    ) {
        self.location = location
        self.fileName = fileName
        self.schemaVersion = schemaVersion
        self.encryption = encryption
        self.corruptionPolicy = corruptionPolicy
        self.fileProtection = fileProtection
        self.excludedFromBackup = excludedFromBackup
        self.objectTypes = objectTypes
        self.isReadOnly = isReadOnly
        self.deleteRealmIfMigrationNeeded = deleteRealmIfMigrationNeeded
        self.shouldCompactOnLaunch = shouldCompactOnLaunch
        self.migrate = migrate
    }

    // MARK: - Convenience

    /// An in-memory database, for tests and previews.
    ///
    /// - Note: The returned configuration is never encrypted — Realm does not allow an
    ///   in-memory identifier and an encryption key together.
    public static func inMemory(
        identifier: String = UUID().uuidString,
        schemaVersion: UInt64 = 1,
        objectTypes: [Object.Type]? = nil
    ) -> StorageConfiguration {
        StorageConfiguration(
            location: .inMemory(identifier: identifier),
            schemaVersion: schemaVersion,
            encryption: .none,
            fileProtection: nil,
            excludedFromBackup: false,
            objectTypes: objectTypes
        )
    }
}
