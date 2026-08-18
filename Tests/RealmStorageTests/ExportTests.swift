//
//  ExportTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Export and maintenance")
struct ExportTests {

    @Test("writeCopy produces a readable copy")
    func writeCopy() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))
            let destination = directory.appendingPathComponent("backup.realm")

            try await store.writeCopy(to: destination)

            #expect(FileManager.default.fileExists(atPath: destination.path))

            let restored = RealmStore(
                configuration: StorageConfiguration(
                    location: .file(destination),
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            )
            try await restored.open()

            #expect(try await restored.count(User.self) == 3)
        }
    }

    @Test("writeCopy can encrypt the copy")
    func writeCopyEncrypted() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = try await TestStore.seeded(TestStore.sampleUsers(count: 2))
            let destination = directory.appendingPathComponent("secure.realm")
            let key = try EncryptionKeyProvider.generateKey()

            try await store.writeCopy(to: destination, encryptionKey: key)

            let restored = RealmStore(
                configuration: StorageConfiguration(
                    location: .file(destination),
                    encryption: .key(key),
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            )
            try await restored.open()

            #expect(try await restored.count(User.self) == 2)
        }
    }

    @Test("writeCopy rejects a key of the wrong length")
    func writeCopyRejectsShortKey() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = try await TestStore.make()

            await #expect(throws: StorageError.self) {
                try await store.writeCopy(
                    to: directory.appendingPathComponent("bad.realm"),
                    encryptionKey: Data(repeating: 0, count: 32)
                )
            }
        }
    }

    @Test("fileSize is nil for an in-memory database")
    func fileSizeInMemory() async throws {
        let store = try await TestStore.make()

        #expect(try await store.fileSize() == nil)
    }

    @Test("fileSize reports bytes for a file-backed database")
    func fileSizeOnDisk() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = RealmStore(
                configuration: StorageConfiguration(
                    location: .directory(directory),
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            )
            try await store.open()
            try await store.save(TestStore.sampleUsers(count: 3))

            let size = try await store.fileSize()

            #expect((size ?? 0) > 0)
        }
    }
}
