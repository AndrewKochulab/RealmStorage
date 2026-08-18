//
//  LimitTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// Realm has no native `LIMIT`, so `limited(to:)` is applied by `QueryPlan`. That makes
/// it easy for a call site to route around it and silently ignore the cap — which is
/// harmless for a read and destructive for a delete. These pin every entry point.
@Suite("Limits")
struct LimitTests {

    private func seeded() async throws -> RealmStore {
        try await TestStore.seeded(TestStore.sampleUsers(count: 5))
    }

    private var limited: DatabaseQuery<User> {
        DatabaseQuery<User>().sorted(by: \.age).limited(to: 2)
    }

    @Test("objects respects the limit")
    func objectsRespectsLimit() async throws {
        let store = try await seeded()

        let users = try await store.objects(User.self, matching: limited)

        #expect(users.count == 2)
        #expect(users.map(\.age) == [20, 30])
    }

    @Test("count respects the limit")
    func countRespectsLimit() async throws {
        let store = try await seeded()

        #expect(try await store.count(User.self, matching: limited) == 2)
        #expect(try await store.count(User.self) == 5)
    }

    @Test("transform respects the limit")
    func transformRespectsLimit() async throws {
        let store = try await seeded()

        let ages = try await store.objects(User.self, matching: limited) { $0.age }

        #expect(ages == [20, 30])
    }

    @Test("last returns the last object within the limit, not the last match")
    func lastRespectsLimit() async throws {
        let store = try await seeded()

        #expect(try await store.last(User.self, matching: limited)?.age == 30)
        #expect(try await store.first(User.self, matching: limited)?.age == 20)
    }

    /// The one that actually loses data if it regresses.
    @Test("delete removes at most the limit, not every match")
    func deleteRespectsLimit() async throws {
        let store = try await seeded()

        let deleted = try await store.delete(User.self, matching: limited)

        #expect(deleted == 2)
        #expect(try await store.count(User.self) == 3)
    }

    @Test("update touches at most the limit")
    func updateRespectsLimit() async throws {
        let store = try await seeded()

        let updated = try await store.update(User.self, matching: limited) {
            $0.firstName = "Renamed"
        }

        #expect(updated == 2)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.firstName == "Renamed" }) == 2)
    }

    @Test("a limit of zero selects nothing")
    func zeroLimit() async throws {
        let store = try await seeded()
        let none = DatabaseQuery<User>().limited(to: 0)

        #expect(try await store.count(User.self, matching: none) == 0)
        #expect(try await store.objects(User.self, matching: none).isEmpty)
        #expect(try await store.first(User.self, matching: none) == nil)
        #expect(try await store.last(User.self, matching: none) == nil)
        #expect(try await store.contains(User.self, matching: none) == false)
        #expect(try await store.delete(User.self, matching: none) == 0)
        #expect(try await store.count(User.self) == 5)
    }

    @Test("a negative limit is clamped to zero rather than trapping")
    func negativeLimit() async throws {
        let store = try await seeded()

        #expect(DatabaseQuery<User>().limited(to: -5).limit == 0)
        #expect(try await store.count(User.self, matching: DatabaseQuery<User>().limited(to: -5)) == 0)
    }

    @Test("a limit larger than the result set is harmless")
    func oversizedLimit() async throws {
        let store = try await seeded()
        let query = DatabaseQuery<User>().limited(to: 100)

        #expect(try await store.count(User.self, matching: query) == 5)
        #expect(try await store.objects(User.self, matching: query).count == 5)
    }

    @Test("contains respects the limit")
    func containsRespectsLimit() async throws {
        let store = try await seeded()

        #expect(try await store.contains(User.self, matching: limited))
    }
}
