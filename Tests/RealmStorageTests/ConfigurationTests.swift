//
//  ConfigurationTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Configuration")
struct ConfigurationTests {

    // MARK: - Defaults

    /// v1 applied `FileProtectionType.none` to the Realm's *containing* directory —
    /// with its default location, the whole Documents folder — defeating data protection
    /// on a database it also encrypted.
    @Test("data protection is on by default, not disabled")
    func fileProtectionDefault() {
        let configuration = StorageConfiguration()

        #expect(configuration.fileProtection == .completeUntilFirstUserAuthentication)
        #expect(configuration.fileProtection != FileProtectionType.none)
    }

    @Test("new databases default to Application Support and are excluded from backup")
    func locationDefaults() {
        let configuration = StorageConfiguration()

        #expect(configuration.location == .applicationSupport)
        #expect(configuration.excludedFromBackup)
    }

    /// v1 deleted the database on any initialization failure. The default must not.
    @Test("the default corruption policy does not delete anything")
    func corruptionPolicyDefault() {
        let configuration = StorageConfiguration()

        #expect(!configuration.corruptionPolicy.shouldReset(after: StorageError.storeNotOpen))
    }

    @Test("in-memory configurations are never encrypted")
    func inMemoryIsUnencrypted() {
        let configuration = StorageConfiguration.inMemory()

        if case .none = configuration.encryption {
            // expected
        } else {
            Issue.record("In-memory configurations must not carry an encryption key")
        }
    }

    // MARK: - Corruption policy

    @Test("rethrow never resets")
    func rethrowNeverResets() {
        #expect(!CorruptionPolicy.rethrow.shouldReset(after: StorageError.objectNotFound))
    }

    @Test("deleteAndRecreate ignores recoverable errors")
    func deleteAndRecreateIsNarrow() {
        // A transient failure must not be mistaken for corruption — the consequence is
        // destroying user data.
        let transient = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))

        #expect(!CorruptionPolicy.deleteAndRecreate.shouldReset(after: transient))
        #expect(!CorruptionPolicy.deleteAndRecreate.shouldReset(after: StorageError.storeNotOpen))
    }

    @Test("a custom policy decides for itself")
    func customPolicy() {
        let always = CorruptionPolicy.custom { _ in true }
        let never = CorruptionPolicy.custom { _ in false }

        #expect(always.shouldReset(after: StorageError.objectNotFound))
        #expect(!never.shouldReset(after: StorageError.objectNotFound))
    }

    // MARK: - Locations

    @Test("a custom directory is created if missing")
    func customDirectoryIsCreated() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("RealmStorageTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }

        let resolved = try StorageLocation.directory(base).resolveDirectory()

        #expect(resolved == base)
        #expect(FileManager.default.fileExists(atPath: base.path))
    }

    @Test("in-memory has no directory")
    func inMemoryHasNoDirectory() throws {
        #expect(try StorageLocation.inMemory(identifier: "x").resolveDirectory() == nil)
    }

    @Test("standard locations resolve")
    func standardLocationsResolve() throws {
        #expect(try StorageLocation.documents.resolveDirectory() != nil)
        #expect(try StorageLocation.applicationSupport.resolveDirectory() != nil)
    }

    // MARK: - Lifecycle

    @Test("open() is idempotent")
    func openIsIdempotent() async throws {
        let store = try await TestStore.make()
        try await store.save(User(id: "u1"))

        try await store.open()

        #expect(try await store.count(User.self) == 1)
    }

    @Test("close() then a read throws storeNotOpen")
    func closeThenRead() async throws {
        let store = try await TestStore.make()
        await store.close()

        await #expect(throws: StorageError.self) {
            _ = try await store.count(User.self)
        }
    }

    @Test("the store exposes its configuration without awaiting")
    func configurationIsNonisolated() async throws {
        let store = try await TestStore.make(schemaVersion: 7)

        #expect(store.configuration.schemaVersion == 7)
    }
}
