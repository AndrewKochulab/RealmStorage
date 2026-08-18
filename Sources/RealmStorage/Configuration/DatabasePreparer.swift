//
//  DatabasePreparer.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Turns a ``StorageConfiguration`` into a `Realm.Configuration`, doing everything that
/// has to happen before a database can be opened: resolving the directory, provisioning
/// the encryption key, and carrying an existing plaintext file into the encrypted one.
///
/// This is shared rather than duplicated because ``RealmStore`` and ``MainRealmStore``
/// must agree exactly on where the file is and how it is protected. It also means
/// `MainRealmStore` no longer has to open a second Realm through a backing store just to
/// learn the configuration.
///
/// Nothing here touches `Realm.Configuration.defaultConfiguration`. 1.x mutated that
/// process-wide global, which made test order matter and a second database impossible.
struct DatabasePreparer {

    /// The result of preparing a database: what to open, and where it landed.
    struct Prepared {
        let realmConfiguration: Realm.Configuration

        /// The database file, or `nil` for an in-memory database.
        let fileURL: URL?
    }

    let configuration: StorageConfiguration
    let fileMigrator: FileStorageMigrator

    init(configuration: StorageConfiguration, fileMigrator: FileStorageMigrator = .init()) {
        self.configuration = configuration
        self.fileMigrator = fileMigrator
    }

    /// Prepares the database and returns the configuration to open it with.
    func prepare() throws -> Prepared {
        var realmConfiguration = Realm.Configuration()

        realmConfiguration.schemaVersion = configuration.schemaVersion
        realmConfiguration.objectTypes = configuration.objectTypes
        realmConfiguration.readOnly = configuration.isReadOnly
        realmConfiguration.deleteRealmIfMigrationNeeded = configuration.deleteRealmIfMigrationNeeded

        if let shouldCompactOnLaunch = configuration.shouldCompactOnLaunch {
            realmConfiguration.shouldCompactOnLaunch = shouldCompactOnLaunch
        }

        if let migrate = configuration.migrate {
            realmConfiguration.migrationBlock = { migration, oldSchemaVersion in
                migrate(migration, oldSchemaVersion)
            }
        }

        // In-memory: there is no file, and Realm rejects an encryption key alongside an
        // in-memory identifier.
        if case .inMemory(let identifier) = configuration.location {
            realmConfiguration.inMemoryIdentifier = identifier

            return Prepared(realmConfiguration: realmConfiguration, fileURL: nil)
        }

        guard let directory = try configuration.location.resolveDirectory() else {
            throw StorageError.storageDirectoryUnavailable
        }

        let encryptionKey = try resolveEncryptionKey()
        let fileURL: URL

        if let explicitFileURL = configuration.location.explicitFileURL {
            // The caller named the file, so neither the `_encrypted` naming convention
            // nor the plaintext-to-encrypted migration applies.
            fileURL = explicitFileURL
        } else if let encryptionKey {
            fileURL = encryptedFileURL(in: directory)

            try fileMigrator.migrateToEncrypted(
                from: plaintextFileURL(in: directory),
                to: fileURL,
                key: encryptionKey,
                source: .init(
                    schemaVersion: configuration.schemaVersion,
                    objectTypes: configuration.objectTypes,
                    migrate: configuration.migrate
                )
            )
        } else {
            fileURL = plaintextFileURL(in: directory)
        }

        realmConfiguration.fileURL = fileURL
        realmConfiguration.encryptionKey = encryptionKey

        return Prepared(realmConfiguration: realmConfiguration, fileURL: fileURL)
    }

    /// Applies data protection and backup exclusion to the database files.
    ///
    /// Runs after opening, because the files do not all exist until Realm creates them.
    func applyFileAttributes(to fileURL: URL?) throws {
        guard let fileURL else { return }

        if let fileProtection = configuration.fileProtection {
            try fileMigrator.applyFileProtection(fileProtection, to: fileURL)
        }

        if configuration.excludedFromBackup {
            try fileMigrator.excludeFromBackup(fileURL)
        }
    }

    // MARK: - Helpers

    private func resolveEncryptionKey() throws -> Data? {
        switch configuration.encryption {
        case .none:
            return nil

        case .key(let key):
            guard key.count == EncryptionKeyProvider.requiredKeyLength else {
                throw StorageError.encryptionKeyInvalidLength(
                    expected: EncryptionKeyProvider.requiredKeyLength,
                    actual: key.count
                )
            }

            return key

        case .keychain(let store, let account):
            return try EncryptionKeyProvider(store: store, account: account).key()
        }
    }

    private func plaintextFileURL(in directory: URL) -> URL {
        directory
            .appendingPathComponent(configuration.fileName)
            .appendingPathExtension("realm")
    }

    private func encryptedFileURL(in directory: URL) -> URL {
        directory
            .appendingPathComponent("\(configuration.fileName)_encrypted")
            .appendingPathExtension("realm")
    }
}
