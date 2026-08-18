//
//  RecoveryTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// The recovery path deletes the user's database, so it gets tested rather than trusted.
/// 1.x ran this on *every* initialization error; here it must fire only when asked, and
/// only for a genuinely unopenable file.
@Suite("Corruption recovery")
struct RecoveryTests {

    /// Writes bytes that are not a Realm file at the path the store will try to open.
    private func writeGarbage(in directory: URL, fileName: String = "default") throws -> URL {
        let fileURL = directory
            .appendingPathComponent(fileName)
            .appendingPathExtension("realm")

        try Data("this is definitely not a realm file".utf8).write(to: fileURL)
        return fileURL
    }

    private func configuration(
        in directory: URL,
        policy: CorruptionPolicy
    ) -> StorageConfiguration {
        StorageConfiguration(
            location: .directory(directory),
            corruptionPolicy: policy,
            fileProtection: nil,
            excludedFromBackup: false,
            objectTypes: TestModels.all
        )
    }

    @Test("rethrow leaves a corrupt file untouched")
    func rethrowKeepsTheFile() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let fileURL = try writeGarbage(in: directory)
            let original = try Data(contentsOf: fileURL)

            let store = RealmStore(configuration: configuration(in: directory, policy: .rethrow))

            await #expect(throws: StorageError.self) {
                try await store.open()
            }

            // The database is still there, byte for byte.
            #expect(try Data(contentsOf: fileURL) == original)
        }
    }

    @Test("deleteAndRecreate replaces a corrupt file and reports that it did")
    func deleteAndRecreateRecovers() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            _ = try writeGarbage(in: directory)

            let store = RealmStore(
                configuration: configuration(in: directory, policy: .deleteAndRecreate)
            )

            // Recovery still throws: silently discarding a database would be worse than
            // telling the caller it happened.
            await #expect(throws: StorageError.self) {
                try await store.open()
            }

            // ...and the store is usable afterwards.
            try await store.save(User(id: "u1", firstName: "Fresh"))
            #expect(try await store.object(User.self, id: "u1")?.firstName == "Fresh")
        }
    }

    @Test("a custom policy decides whether to reset")
    func customPolicyIsConsulted() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            _ = try writeGarbage(in: directory)

            let store = RealmStore(
                configuration: configuration(in: directory, policy: .custom { _ in false })
            )

            await #expect(throws: StorageError.self) {
                try await store.open()
            }

            // Refusing to reset means the store never opens.
            await #expect(throws: StorageError.self) {
                _ = try await store.count(User.self)
            }
        }
    }

    @Test("deleteAndRecreate does not fire for a healthy database")
    func healthyDatabaseIsNotReset() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = RealmStore(
                configuration: configuration(in: directory, policy: .deleteAndRecreate)
            )
            try await store.open()
            try await store.save(User(id: "keep", firstName: "Keep"))
            await store.close()

            let reopened = RealmStore(
                configuration: configuration(in: directory, policy: .deleteAndRecreate)
            )
            try await reopened.open()

            #expect(try await reopened.object(User.self, id: "keep")?.firstName == "Keep")
        }
    }

    @Test("reset removes the sidecar files too, not just the database")
    func resetRemovesSidecars() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = RealmStore(configuration: configuration(in: directory, policy: .rethrow))
            try await store.open()
            try await store.save(User(id: "u1"))

            try await store.reset()

            // 1.x deleted only the main file, orphaning these.
            let fileURL = directory.appendingPathComponent("default").appendingPathExtension("realm")
            for url in FileStorageMigrator.realmFileURLs(for: fileURL) {
                #expect(!FileManager.default.fileExists(atPath: url.path))
            }
        }
    }
}

@Suite("Error messages")
struct StorageErrorTests {

    @Test("every case has a description")
    func allCasesDescribed() {
        let errors: [StorageError] = [
            .storeNotOpen,
            .openFailed(underlying: StorageError.storeNotOpen),
            .encryptionKeyGenerationFailed(status: -1),
            .encryptionKeyInvalidLength(expected: 64, actual: 32),
            .keychain(status: -34018),
            .storageDirectoryUnavailable,
            .fileMigrationFailed(underlying: StorageError.storeNotOpen),
            .databaseWasReset(underlying: StorageError.storeNotOpen),
            .objectNotFound
        ]

        for error in errors {
            let description = error.errorDescription

            #expect(description?.isEmpty == false)
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("the key-length message names both lengths")
    func keyLengthMessage() {
        let message = StorageError.encryptionKeyInvalidLength(expected: 64, actual: 32).errorDescription

        #expect(message?.contains("64") == true)
        #expect(message?.contains("32") == true)
    }
}
