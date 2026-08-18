//
//  TestStore.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
@testable import RealmStorage

enum TestStore {

    /// An open, isolated in-memory store.
    ///
    /// Each call gets a fresh identifier so tests can run in parallel without sharing
    /// state. The returned store must be **retained** for as long as the data matters:
    /// Realm destroys an in-memory database once its last reference is released.
    static func make(schemaVersion: UInt64 = 1) async throws -> RealmStore {
        let store = RealmStore(
            configuration: .inMemory(
                identifier: UUID().uuidString,
                schemaVersion: schemaVersion,
                objectTypes: TestModels.all
            )
        )

        try await store.open()
        return store
    }

    /// An open in-memory store seeded with `users`.
    static func seeded(_ users: sending [User]) async throws -> RealmStore {
        let store = try await make()
        try await store.save(users)
        return store
    }

    /// A directory that is removed when `body` returns.
    static func withTemporaryDirectory<T>(
        isolation: isolated (any Actor)? = #isolation,
        _ body: (URL) async throws -> sending T
    ) async throws -> sending T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RealmStorageTests-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        return try await body(directory)
    }

    /// Users named A…, with ages 20, 30, 40, …
    static func sampleUsers(count: Int = 3) -> [User] {
        (0..<count).map { index in
            User(
                id: "user-\(index)",
                firstName: ["Robert", "Steve", "Tony", "Bruce", "Carol"][index % 5],
                lastName: "Last\(index)",
                age: 20 + index * 10,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index) * 1_000),
                updatedAt: index.isMultiple(of: 2) ? nil : Date(timeIntervalSince1970: 500),
                isActive: index.isMultiple(of: 2)
            )
        }
    }
}
