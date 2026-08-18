//
//  RealmStore+Export.swift
//  RealmStorage
//

import Foundation
import RealmSwift

public extension RealmStore {

    /// Writes a compacted copy of the database to `fileURL`.
    ///
    /// Useful for backups, for shipping a seed database, and for handing a support bundle
    /// to a developer. The copy is compacted, so it is usually smaller than the live file.
    ///
    /// - Parameters:
    ///   - fileURL: destination. Must not already exist.
    ///   - encryptionKey: encrypt the copy with this key, or `nil` for a plaintext copy.
    ///     Must be exactly 64 bytes when provided. Note that passing `nil` writes an
    ///     **unencrypted** copy even when the source is encrypted — which is the point
    ///     when exporting, but worth being deliberate about.
    func writeCopy(to fileURL: URL, encryptionKey: Data? = nil) throws {
        if let encryptionKey, encryptionKey.count != EncryptionKeyProvider.requiredKeyLength {
            throw StorageError.encryptionKeyInvalidLength(
                expected: EncryptionKeyProvider.requiredKeyLength,
                actual: encryptionKey.count
            )
        }

        try requireRealm().writeCopy(toFile: fileURL, encryptionKey: encryptionKey)
    }

    /// The database file's size on disk, in bytes, or `nil` for an in-memory database.
    ///
    /// Realm files only grow; pair this with
    /// ``StorageConfiguration/shouldCompactOnLaunch`` to decide when compaction is worth
    /// it.
    func fileSize() throws -> Int? {
        guard let fileURL = try requireRealm().configuration.fileURL else { return nil }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.intValue
    }
}
