//
//  StoreWriteTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Writes")
struct StoreWriteTests {

    @Test("save inserts a new object")
    func saveInserts() async throws {
        let store = try await TestStore.make()

        try await store.save(User(id: "u1", firstName: "Steve"))

        #expect(try await store.count(User.self) == 1)
    }

    @Test("save of an array inserts all of them")
    func saveArray() async throws {
        let store = try await TestStore.make()

        try await store.save(TestStore.sampleUsers(count: 4))

        #expect(try await store.count(User.self) == 4)
    }

    @Test("save with .modified merges into an existing object")
    func saveModifiedMerges() async throws {
        let store = try await TestStore.make()
        try await store.save(User(id: "u1", firstName: "Steve", lastName: "Rogers", age: 30))

        try await store.save(User(id: "u1", firstName: "Tony", lastName: "Stark", age: 40))

        let user = try await store.object(User.self, id: "u1")
        #expect(try await store.count(User.self) == 1)
        #expect(user?.firstName == "Tony")
        #expect(user?.age == 40)
    }

    /// v1 took `update: Bool` and mapped it to `update ? .modified : .all` — but `.all`
    /// is itself an upsert, and the more destructive one, so `update: false` silently
    /// overwrote instead of erroring. Naming the policy removes the ambiguity.
    @Test("the update policy is Realm's own enum, not an inverted Bool")
    func updatePolicyIsExplicit() async throws {
        let store = try await TestStore.make()
        try await store.save(User(id: "u1", firstName: "Steve", lastName: "Rogers"))

        try await store.save(User(id: "u1", firstName: "Tony"), update: .all)

        let user = try await store.object(User.self, id: "u1")
        #expect(user?.firstName == "Tony")
        #expect(user?.lastName == "")
    }

    @Test("save(building:) constructs the object inside the transaction")
    func saveBuilding() async throws {
        let store = try await TestStore.make()
        try await store.save(Event(id: "e1", name: "Avengers Game"))

        try await store.save { realm in
            let user = User(id: "u1", firstName: "Nick")

            if let event = realm.object(ofType: Event.self, forPrimaryKey: "e1") {
                user.events.append(event)
            }

            return user
        }

        let user = try await store.object(User.self, id: "u1")
        #expect(user?.events.count == 1)
    }

    @Test("update(id:) mutates an existing object")
    func updateByID() async throws {
        let store = try await TestStore.make()
        try await store.save(User(id: "u1", firstName: "Steve", lastName: "Rogers"))

        try await store.update(User.self, id: "u1") { user in
            user.firstName = "Tony"
            user.lastName = "Stark"
        }

        let user = try await store.object(User.self, id: "u1")
        #expect(user?.firstName == "Tony")
        #expect(user?.lastName == "Stark")
    }

    @Test("update(id:) throws for an unknown key")
    func updateUnknownID() async throws {
        let store = try await TestStore.make()

        await #expect(throws: StorageError.self) {
            try await store.update(User.self, id: "nope") { $0.firstName = "X" }
        }
    }

    @Test("update(matching:) mutates every match and reports the count")
    func updateMatching() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let updated = try await store.update(
            User.self,
            matching: DatabaseQuery { $0.age >= 40 }
        ) { $0.isActive = false }

        #expect(updated == 3)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.isActive == false }) == 4)
    }

    @Test("delete(id:) reports whether anything was removed")
    func deleteByID() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let deleted = try await store.delete(User.self, id: "user-1")
        let missing = try await store.delete(User.self, id: "nope")

        #expect(deleted)
        #expect(!missing)
        #expect(try await store.count(User.self) == 2)
    }

    @Test("delete(matching:) removes every match")
    func deleteMatching() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let deleted = try await store.delete(User.self, matching: DatabaseQuery { $0.age >= 40 })

        #expect(deleted == 3)
        #expect(try await store.count(User.self) == 2)
    }

    @Test("deleteAll(_:) empties one type only")
    func deleteAllOfType() async throws {
        let store = try await TestStore.make()
        try await store.save(TestStore.sampleUsers(count: 3))
        try await store.save(Event(id: "e1", name: "Keep me"))

        try await store.deleteAll(User.self)

        #expect(try await store.count(User.self) == 0)
        #expect(try await store.count(Event.self) == 1)
    }

    @Test("deleteAll() empties the database")
    func deleteAllEverything() async throws {
        let store = try await TestStore.make()
        try await store.save(TestStore.sampleUsers(count: 3))
        try await store.save(Event(id: "e1", name: "Gone"))

        try await store.deleteAll()

        #expect(try await store.count(User.self) == 0)
        #expect(try await store.count(Event.self) == 0)
    }

    @Test("write commits several changes as one transaction")
    func writeTransaction() async throws {
        let store = try await TestStore.make()

        try await store.write { realm in
            realm.add(User(id: "u1", firstName: "Steve"))
            realm.add(Event(id: "e1", name: "Avengers Game"))
        }

        #expect(try await store.count(User.self) == 1)
        #expect(try await store.count(Event.self) == 1)
    }

    @Test("a throwing write rolls back entirely")
    func writeRollsBack() async throws {
        let store = try await TestStore.make()
        try await store.save(User(id: "existing", firstName: "Keep"))

        struct Boom: Error {}

        await #expect(throws: Boom.self) {
            try await store.write { realm in
                realm.add(User(id: "u1", firstName: "Discard"))
                throw Boom()
            }
        }

        #expect(try await store.count(User.self) == 1)
        #expect(try await store.object(User.self, id: "u1") == nil)
    }

    @Test("write returns a value from inside the transaction")
    func writeReturnsValue() async throws {
        let store = try await TestStore.make()

        let count = try await store.write { realm -> Int in
            realm.add(User(id: "u1"))
            realm.add(User(id: "u2"))
            return realm.objects(User.self).count
        }

        #expect(count == 2)
    }

    @Test("withRealm exposes the underlying Realm inside the actor")
    func withRealmEscapeHatch() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let count = try await store.withRealm { realm in
            realm.objects(User.self).count
        }

        #expect(count == 3)
    }

    @Test("writing before open() throws storeNotOpen")
    func writingBeforeOpen() async throws {
        let store = RealmStore(
            configuration: .inMemory(identifier: UUID().uuidString, objectTypes: TestModels.all)
        )

        await #expect(throws: StorageError.self) {
            try await store.save(User(id: "u1"))
        }
    }
}
