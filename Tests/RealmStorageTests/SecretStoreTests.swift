//
//  SecretStoreTests.swift
//  RealmStorageTests
//

import Foundation
import Security
import Testing
@testable import RealmStorage

@Suite("Secret storage")
struct SecretStoreTests {

    // MARK: - In-memory double

    @Test("the in-memory store round-trips")
    func inMemoryRoundTrip() throws {
        let store = InMemorySecretStore()
        let value = Data("hello".utf8)

        try store.set(value, forKey: "key")

        #expect(try store.data(forKey: "key") == value)
    }

    @Test("reading an absent key returns nil rather than throwing")
    func inMemoryMissingKey() throws {
        let store = InMemorySecretStore()

        #expect(try store.data(forKey: "absent") == nil)
    }

    @Test("setting twice overwrites")
    func inMemoryOverwrite() throws {
        let store = InMemorySecretStore()

        try store.set(Data("first".utf8), forKey: "key")
        try store.set(Data("second".utf8), forKey: "key")

        #expect(try store.data(forKey: "key") == Data("second".utf8))
    }

    @Test("removing a key clears it, and removing twice is not an error")
    func inMemoryRemove() throws {
        let store = InMemorySecretStore()
        try store.set(Data("x".utf8), forKey: "key")

        try store.removeData(forKey: "key")
        try store.removeData(forKey: "key")

        #expect(try store.data(forKey: "key") == nil)
    }

    // MARK: - Keychain accessibility

    /// v1 inherited KeychainSwift's `whenUnlocked` default. An app woken in the background
    /// on a locked device then cannot read the encryption key, the database fails to open,
    /// and v1's blanket `catch` deleted it. The default must survive a locked device.
    @Test("the default accessibility allows background access after first unlock")
    func defaultAccessibility() {
        let store = KeychainSecretStore()

        #expect(store.accessibility == .afterFirstUnlockThisDeviceOnly)
        #expect(
            store.accessibility.rawValue == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    @Test("each accessibility case maps to its Security constant")
    func accessibilityMapping() {
        #expect(KeychainAccessibility.whenUnlocked.rawValue == kSecAttrAccessibleWhenUnlocked)
        #expect(
            KeychainAccessibility.whenUnlockedThisDeviceOnly.rawValue
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
        #expect(KeychainAccessibility.afterFirstUnlock.rawValue == kSecAttrAccessibleAfterFirstUnlock)
        #expect(
            KeychainAccessibility.afterFirstUnlockThisDeviceOnly.rawValue
                == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    @Test("the service name is configurable and defaults sensibly")
    func serviceName() {
        #expect(KeychainSecretStore().service == "io.realmstorage.encryption")
        #expect(KeychainSecretStore(service: "custom").service == "custom")
    }

    // MARK: - Real Keychain

    /// Exercises the actual `SecItem*` calls. The system Keychain is not reliably
    /// available to a bare `swift test` process on every machine or CI runner, so a
    /// failure to reach it skips rather than fails; the assertions still run wherever the
    /// Keychain is usable (notably `xcodebuild test` on a simulator).
    @Test("the real Keychain round-trips")
    func keychainRoundTrip() throws {
        let store = KeychainSecretStore(service: "io.realmstorage.tests.\(UUID().uuidString)")
        let key = "encryptionKey"
        let value = Data((0..<64).map { UInt8($0) })

        do {
            try store.set(value, forKey: key)
        } catch {
            withKnownIssue("The system Keychain is not available in this environment") {
                throw error
            }
            return
        }

        defer { try? store.removeData(forKey: key) }

        #expect(try store.data(forKey: key) == value)

        try store.set(Data(repeating: 9, count: 64), forKey: key)
        #expect(try store.data(forKey: key) == Data(repeating: 9, count: 64))

        try store.removeData(forKey: key)
        #expect(try store.data(forKey: key) == nil)
    }
}
