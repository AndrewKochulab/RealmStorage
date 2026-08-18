//
//  EncryptionTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// Encryption needs a real file — Realm rejects an in-memory identifier combined with an
/// encryption key — so these use a per-test temporary directory and an in-memory
/// `SecretStore` double rather than the system Keychain.
@Suite("Encryption")
struct EncryptionTests {

    private func configuration(
        in directory: URL,
        secrets: any SecretStore
    ) -> StorageConfiguration {
        StorageConfiguration(
            location: .directory(directory),
            schemaVersion: 1,
            encryption: .keychain(store: secrets),
            fileProtection: nil,
            excludedFromBackup: false,
            objectTypes: TestModels.all
        )
    }

    @Test("generated keys are 64 bytes, as Realm requires")
    func generatedKeyLength() throws {
        let key = try EncryptionKeyProvider.generateKey()

        #expect(key.count == 64)
        #expect(key.count == EncryptionKeyProvider.requiredKeyLength)
    }

    @Test("the same key is reused across calls")
    func keyIsStable() throws {
        let provider = EncryptionKeyProvider(store: InMemorySecretStore(), account: "test")

        let first = try provider.key()
        let second = try provider.key()

        #expect(first == second)
    }

    /// v1 fell back to a 32-byte key when 64-byte generation failed. Realm requires
    /// exactly 64, so that key failed at open time — and the failure reached a blanket
    /// `catch` that deleted the database. A wrong-length key must throw.
    @Test("a stored key of the wrong length throws rather than being used")
    func wrongLengthKeyThrows() throws {
        let secrets = InMemorySecretStore()
        try secrets.set(Data(repeating: 0, count: 32), forKey: "test")

        let provider = EncryptionKeyProvider(store: secrets, account: "test")

        #expect(throws: StorageError.self) {
            _ = try provider.key()
        }
    }

    @Test("a caller-supplied key of the wrong length is rejected at open")
    func explicitWrongLengthKeyRejected() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let store = RealmStore(
                configuration: StorageConfiguration(
                    location: .directory(directory),
                    encryption: .key(Data(repeating: 1, count: 32)),
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            )

            await #expect(throws: StorageError.self) {
                try await store.open()
            }
        }
    }

    @Test("data written to an encrypted store reads back")
    func encryptedRoundTrip() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let secrets = InMemorySecretStore()

            let store = RealmStore(configuration: configuration(in: directory, secrets: secrets))
            try await store.open()
            try await store.save(User(id: "u1", firstName: "Steve"))
            await store.close()

            let reopened = RealmStore(configuration: configuration(in: directory, secrets: secrets))
            try await reopened.open()

            #expect(try await reopened.object(User.self, id: "u1")?.firstName == "Steve")
        }
    }

    @Test("the file on disk does not contain plaintext values")
    func fileIsActuallyEncrypted() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let secrets = InMemorySecretStore()
            let secretValue = "SuperSecretUniqueName12345"

            let store = RealmStore(configuration: configuration(in: directory, secrets: secrets))
            try await store.open()
            try await store.save(User(id: "u1", firstName: secretValue))
            await store.close()

            let fileURL = directory
                .appendingPathComponent("default_encrypted")
                .appendingPathExtension("realm")
            let bytes = try Data(contentsOf: fileURL)

            #expect(bytes.range(of: Data(secretValue.utf8)) == nil)
        }
    }

    @Test("the wrong key cannot open an encrypted database")
    func wrongKeyFails() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let secrets = InMemorySecretStore()

            let store = RealmStore(configuration: configuration(in: directory, secrets: secrets))
            try await store.open()
            try await store.save(User(id: "u1"))
            await store.close()

            // A different secret store means a freshly generated, different key.
            let otherStore = RealmStore(
                configuration: configuration(in: directory, secrets: InMemorySecretStore())
            )

            await #expect(throws: (any Error).self) {
                try await otherStore.open()
            }
        }
    }

    @Test("an existing plaintext database is migrated into the encrypted file")
    func plaintextIsMigrated() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            // Start unencrypted, exactly as a v1 app would have.
            let plaintext = RealmStore(
                configuration: StorageConfiguration(
                    location: .directory(directory),
                    encryption: .none,
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            )
            try await plaintext.open()
            try await plaintext.save(User(id: "legacy", firstName: "Legacy"))
            await plaintext.close()

            let plaintextURL = directory.appendingPathComponent("default").appendingPathExtension("realm")
            #expect(FileManager.default.fileExists(atPath: plaintextURL.path))

            // Turning encryption on carries the data across and removes the old file.
            let encrypted = RealmStore(
                configuration: configuration(in: directory, secrets: InMemorySecretStore())
            )
            try await encrypted.open()

            #expect(try await encrypted.object(User.self, id: "legacy")?.firstName == "Legacy")
            #expect(!FileManager.default.fileExists(atPath: plaintextURL.path))
        }
    }
}
