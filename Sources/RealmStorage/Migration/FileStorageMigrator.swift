//
//  FileStorageMigrator.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Moves an existing plaintext database to an encrypted one, and cleans up afterwards.
///
/// Realm writes sidecar files next to the database (`.lock`, `.note`, `.management`).
/// v1's cleanup missed them in some paths and its reset routine deleted only the main
/// file, leaving a half-removed database behind. ``realmFileURLs(for:)`` is the single
/// place that knows the full set.
struct FileStorageMigrator {

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Every file Realm may create for the database at `url`.
    static func realmFileURLs(for url: URL) -> [URL] {
        [
            url,
            url.appendingPathExtension("lock"),
            url.appendingPathExtension("note"),
            url.appendingPathExtension("management")
        ]
    }

    /// How to open the existing plaintext database so it can be copied.
    struct SourceSchema {
        let schemaVersion: UInt64
        let objectTypes: [Object.Type]?
        let migrate: (@Sendable (Migration, UInt64) -> Void)?
    }

    /// Copies `plaintextURL` to `encryptedURL` under `key`, then removes the original.
    ///
    /// No-op when the plaintext file is absent or the encrypted one already exists.
    func migrateToEncrypted(
        from plaintextURL: URL,
        to encryptedURL: URL,
        key: Data,
        source: SourceSchema
    ) throws {
        let plaintextExists = fileManager.fileExists(atPath: plaintextURL.path)
        let encryptedExists = fileManager.fileExists(atPath: encryptedURL.path)

        guard plaintextExists, !encryptedExists else { return }

        do {
            var configuration = Realm.Configuration(
                fileURL: plaintextURL,
                schemaVersion: source.schemaVersion
            )
            configuration.objectTypes = source.objectTypes

            if let migrate = source.migrate {
                configuration.migrationBlock = { migration, oldVersion in
                    migrate(migration, oldVersion)
                }
            }

            let plaintextRealm = try Realm(configuration: configuration)
            try plaintextRealm.writeCopy(toFile: encryptedURL, encryptionKey: key)
        } catch {
            throw StorageError.fileMigrationFailed(underlying: error)
        }

        try removeDatabase(at: plaintextURL)
    }

    /// Removes the database at `url` along with every sidecar file.
    func removeDatabase(at url: URL) throws {
        for fileURL in Self.realmFileURLs(for: url) where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Applies `protection` to the database files themselves.
    ///
    /// v1 applied this to the *containing directory*, which with the default location
    /// meant every file in Documents.
    func applyFileProtection(_ protection: FileProtectionType, to url: URL) throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        for fileURL in Self.realmFileURLs(for: url) where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: fileURL.path)
        }
        #endif
    }

    /// Marks the database files as excluded from iCloud/iTunes backups.
    func excludeFromBackup(_ url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true

        for fileURL in Self.realmFileURLs(for: url) where fileManager.fileExists(atPath: fileURL.path) {
            var mutableURL = fileURL
            try mutableURL.setResourceValues(resourceValues)
        }
    }
}
