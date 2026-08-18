//
//  StoreReadTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Reads")
struct StoreReadTests {

    @Test("all() returns every object")
    func allReturnsEverything() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let users = try await store.all(User.self)

        #expect(users.count == 3)
    }

    @Test("an empty store reads back empty")
    func emptyStore() async throws {
        let store = try await TestStore.make()

        let users = try await store.all(User.self)

        #expect(users.isEmpty)
        #expect(users.count == 0)
    }

    @Test("object(id:) finds by primary key")
    func objectByID() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let found = try await store.object(User.self, id: "user-1")

        #expect(found?.firstName == "Steve")
    }

    @Test("object(id:) returns nil for an unknown key")
    func objectByUnknownID() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let found = try await store.object(User.self, id: "nope")

        #expect(found == nil)
    }

    @Test("UUID primary keys work")
    func uuidPrimaryKey() async throws {
        let store = try await TestStore.make()
        let id = UUID()
        try await store.save(Device(id: id, label: "iPhone"))

        let found = try await store.object(Device.self, id: id)

        #expect(found?.label == "iPhone")
    }

    @Test("first and last respect sort order")
    func firstAndLast() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))
        let query = DatabaseQuery<User>().sorted(by: \.age)

        let first = try await store.first(User.self, matching: query)
        let last = try await store.last(User.self, matching: query)

        #expect(first?.age == 20)
        #expect(last?.age == 40)
    }

    @Test("count is computed without materialising results")
    func count() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let total = try await store.count(User.self)
        let adults = try await store.count(User.self, matching: DatabaseQuery { $0.age >= 40 })

        #expect(total == 5)
        #expect(adults == 3)
    }

    @Test("contains reports whether anything matches")
    func contains() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let hasYoung = try await store.contains(User.self, matching: DatabaseQuery { $0.age < 25 })
        let hasAncient = try await store.contains(User.self, matching: DatabaseQuery { $0.age > 200 })

        #expect(hasYoung)
        #expect(!hasAncient)
    }

    @Test("transform maps objects to Sendable values inside the actor")
    func transform() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))
        let query = DatabaseQuery<User>().sorted(by: \.age)

        let names = try await store.objects(User.self, matching: query) { $0.firstName }

        #expect(names == ["Robert", "Steve", "Tony"])
    }

    @Test("results returned from the store are frozen")
    func resultsAreFrozen() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 1))

        let users = try await store.all(User.self)

        #expect(users[0].isFrozen)
    }

    @Test("reading before open() throws storeNotOpen")
    func readingBeforeOpen() async throws {
        let store = RealmStore(
            configuration: .inMemory(identifier: UUID().uuidString, objectTypes: TestModels.all)
        )

        await #expect(throws: StorageError.self) {
            _ = try await store.all(User.self)
        }
    }
}
