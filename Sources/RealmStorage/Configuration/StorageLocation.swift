//
//  StorageLocation.swift
//  RealmStorage
//

import Foundation

/// Where the Realm file lives on disk.
///
/// v1 hard-coded `.documentDirectory`. That directory is included in iCloud/iTunes
/// backups while a `ThisDeviceOnly` Keychain key is not — restore onto a new device and
/// you get an encrypted file with no key to open it. ``applicationSupport`` plus
/// ``excludedFromBackup`` is the safer default for new databases.
///
/// - Important: ``documents`` remains available and is what existing v1 databases use.
///   Changing an existing app to ``applicationSupport`` orphans that data unless you
///   move the file yourself; see `MIGRATION.md`.
public enum StorageLocation: Sendable, Equatable {

    /// `~/Documents` — where v1 always put the database.
    case documents

    /// `~/Library/Application Support` — recommended for new databases.
    case applicationSupport

    /// A caller-supplied directory. The file is named from
    /// ``StorageConfiguration/fileName``, and the plaintext-to-encrypted migration
    /// applies.
    case directory(URL)

    /// A specific file, used exactly as given.
    ///
    /// Unlike the directory cases, this bypasses both the naming convention (including
    /// the `_encrypted` suffix) and the automatic plaintext-to-encrypted migration. Use
    /// it to open a database whose path you already know — a restored backup, a seed
    /// database shipped in your bundle, or a file another tool produced.
    case file(URL)

    /// An in-memory database with the given identifier.
    ///
    /// - Note: Realm does not support combining an in-memory identifier with an
    ///   encryption key, so ``StorageConfiguration/encryption`` is ignored here.
    /// - Note: An in-memory Realm is destroyed once its last reference is released,
    ///   so the owning ``RealmStore`` must stay alive for as long as the data matters.
    case inMemory(identifier: String)

    /// The exact file to open, when the location names one.
    var explicitFileURL: URL? {
        guard case .file(let url) = self else { return nil }
        return url
    }

    /// Resolves the containing directory, creating it when necessary.
    ///
    /// Returns `nil` for ``inMemory(identifier:)``, which has no directory.
    func resolveDirectory(using fileManager: FileManager = .default) throws -> URL? {
        let searchPath: FileManager.SearchPathDirectory

        switch self {
        case .inMemory:
            return nil
        case .file(let url):
            let directory = url.deletingLastPathComponent()
            try createDirectoryIfNeeded(at: directory, using: fileManager)
            return directory
        case .directory(let url):
            try createDirectoryIfNeeded(at: url, using: fileManager)
            return url
        case .documents:
            searchPath = .documentDirectory
        case .applicationSupport:
            searchPath = .applicationSupportDirectory
        }

        guard let url = fileManager.urls(for: searchPath, in: .userDomainMask).first else {
            throw StorageError.storageDirectoryUnavailable
        }

        // Application Support is not guaranteed to exist; Documents is.
        try createDirectoryIfNeeded(at: url, using: fileManager)

        return url
    }

    private func createDirectoryIfNeeded(at url: URL, using fileManager: FileManager) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw StorageError.storageDirectoryUnavailable
        }
    }
}
