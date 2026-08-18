//
//  ModelTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Models and results")
struct ModelTests {

    // MARK: - CompoundID

    @Test("CompoundID joins parts with the default separator")
    func compoundIDDefaults() {
        #expect(CompoundID.make("user", "event") == "user_event")
    }

    @Test("CompoundID accepts a custom separator")
    func compoundIDCustomSeparator() {
        #expect(CompoundID.make("a", "b", "c", separator: "-") == "a-b-c")
    }

    @Test("CompoundID accepts an array")
    func compoundIDArray() {
        #expect(CompoundID.make(["a", "b"], separator: ":") == "a:b")
    }

    @Test("a compound key works as a real primary key")
    func compoundIDAsPrimaryKey() async throws {
        let store = try await TestStore.make()
        let id = CompoundID.make("user-1", "event-1")

        try await store.save(User(id: id, firstName: "Member"))

        #expect(try await store.object(User.self, id: id)?.firstName == "Member")
    }

    // MARK: - Sort

    @Test("Sort derives Realm's key path from a Swift key path")
    func sortKeyPath() {
        #expect(Sort(\User.firstName).keyPath == "firstName")
        #expect(Sort(\User.age, ascending: false).ascending == false)
    }

    @Test("Sort accepts a string key path for traversals")
    func sortStringKeyPath() {
        let sort = Sort<Event>(keyPath: "author.name", ascending: false)

        #expect(sort.keyPath == "author.name")
        #expect(!sort.ascending)
    }

    /// Foundation ships its own `SortDescriptor`, so the bare name is ambiguous — the
    /// same class of bug as the 1.x fix in 240c7c0. `Sort` owns the concept instead of
    /// retroactively conforming Realm's type.
    @Test("Sort bridges to RealmSwift's SortDescriptor unambiguously")
    func sortBridges() {
        let descriptor: RealmSwift.SortDescriptor = Sort(\User.age, ascending: false).realmSortDescriptor

        #expect(descriptor.keyPath == "age")
        #expect(!descriptor.ascending)
    }

    // MARK: - StorageResults

    @Test("StorageResults is a lazy collection, not an eager array")
    func resultsAreLazy() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 4))

        let results = try await store.all(User.self)

        #expect(results.count == 4)
        #expect(results.array().count == 4)
        #expect(!results.isEmpty)
    }

    @Test("StorageResults respects a query limit")
    func resultsRespectLimit() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let results = try await store.objects(
            User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age).limited(to: 2)
        )

        #expect(results.count == 2)
        #expect(Array(results.map(\.age)) == [20, 30])
    }

    @Test("StorageResults supports collection algorithms")
    func resultsAreACollection() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let results = try await store.objects(
            User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age)
        )

        #expect(results.map(\.age) == [20, 30, 40])
        #expect(results.first?.age == 20)
        #expect(results.contains { $0.age == 30 })
    }

    // MARK: - Frozen

    @Test("Frozen reads through to the underlying object")
    func frozenDynamicMemberLookup() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let user = try await store.object(User.self, id: "user-1")

        #expect(user?.firstName == "Steve")
        #expect(user?.age == 30)
        #expect(user?.object.id == "user-1")
    }

    @Test("Frozen wraps an immutable object")
    func frozenIsFrozen() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 1))

        let user = try await store.object(User.self, id: "user-0")

        #expect(user?.object.isFrozen == true)
    }

    @Test("thawed() recovers a live object")
    @MainActor
    func frozenThaws() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 1))

        let user = try await store.object(User.self, id: "user-0")
        let live = user?.thawed()

        #expect(live?.isFrozen == false)
        #expect(live?.id == "user-0")
    }
}

@Suite("Batch lookup")
struct BatchLookupTests {

    @Test("objects(ids:) fetches several by primary key")
    func objectsByIDs() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let found = try await store.objects(User.self, ids: ["user-0", "user-3"])

        #expect(Set(found.map(\.id)) == ["user-0", "user-3"])
    }

    @Test("objects(ids:) skips keys that do not exist")
    func objectsByIDsSkipsMissing() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let found = try await store.objects(User.self, ids: ["user-0", "nope"])

        #expect(found.count == 1)
    }

    @Test("objects(ids:) works with UUID keys")
    func objectsByUUIDs() async throws {
        let store = try await TestStore.make()
        let first = UUID()
        let second = UUID()
        try await store.save([Device(id: first, label: "A"), Device(id: second, label: "B")])

        let found = try await store.objects(Device.self, ids: [first])

        #expect(found.count == 1)
        #expect(found[0].label == "A")
    }

    @Test("objects(ids:) with no ids returns nothing")
    func objectsByNoIDs() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        #expect(try await store.objects(User.self, ids: [String]()).isEmpty)
    }
}
