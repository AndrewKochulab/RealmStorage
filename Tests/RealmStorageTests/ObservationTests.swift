//
//  ObservationTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// Change notifications are most of why Realm is worth using for UI. Going async/await
/// only would have dropped them if `changes(of:)` did not exist, so this suite pins the
/// behaviour down.
@Suite("Observation")
struct ObservationTests {

    @Test("the stream delivers an initial snapshot")
    func initialDelivery() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(of: User.self).makeAsyncIterator()
        let change = try await iterator.next()

        guard case .initial(let results)? = change else {
            Issue.record("Expected an initial change, got \(String(describing: change))")
            return
        }

        #expect(results.count == 3)
    }

    @Test("an insertion produces an update with its index")
    func insertionProducesUpdate() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 2))

        var iterator = await store.changes(
            of: User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age)
        ).makeAsyncIterator()

        _ = try await iterator.next()   // initial

        try await store.save(User(id: "new", firstName: "New", age: 99))

        guard case .update(let results, _, let insertions, _)? = try await iterator.next() else {
            Issue.record("Expected an update change")
            return
        }

        #expect(results.count == 3)
        #expect(insertions == [2])
    }

    @Test("a deletion produces an update with its index")
    func deletionProducesUpdate() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(
            of: User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age)
        ).makeAsyncIterator()

        _ = try await iterator.next()

        try await store.delete(User.self, id: "user-0")

        guard case .update(let results, let deletions, _, _)? = try await iterator.next() else {
            Issue.record("Expected an update change")
            return
        }

        #expect(results.count == 2)
        #expect(deletions == [0])
    }

    @Test("a modification produces an update with its index")
    func modificationProducesUpdate() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(
            of: User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age)
        ).makeAsyncIterator()

        _ = try await iterator.next()

        try await store.update(User.self, id: "user-1") { $0.firstName = "Renamed" }

        guard case .update(_, _, _, let modifications)? = try await iterator.next() else {
            Issue.record("Expected an update change")
            return
        }

        #expect(modifications == [1])
    }

    @Test("the stream only reports changes matching its query")
    func streamRespectsQuery() async throws {
        let store = try await TestStore.make()

        var iterator = await store.changes(
            of: User.self,
            matching: DatabaseQuery { $0.isActive == true }
        ).makeAsyncIterator()

        _ = try await iterator.next()

        try await store.save(User(id: "inactive", isActive: false))
        try await store.save(User(id: "active", isActive: true))

        guard case .update(let results, _, _, _)? = try await iterator.next() else {
            Issue.record("Expected an update change")
            return
        }

        #expect(results.count == 1)
        #expect(results[0].id == "active")
    }

    @Test("change payloads are frozen")
    func payloadsAreFrozen() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 1))

        var iterator = await store.changes(of: User.self).makeAsyncIterator()
        let change = try await iterator.next()

        #expect(change?.results[0].isFrozen == true)
    }

    @Test("observing a closed store finishes the stream with an error")
    func observingClosedStore() async throws {
        let store = RealmStore(
            configuration: .inMemory(identifier: UUID().uuidString, objectTypes: TestModels.all)
        )

        var iterator = await store.changes(of: User.self).makeAsyncIterator()

        await #expect(throws: StorageError.self) {
            _ = try await iterator.next()
        }
    }
}

/// Single-object observation, the companion to the collection stream.
@Suite("Object observation")
struct ObjectObservationTests {

    @Test("the stream delivers the object immediately")
    func initialDelivery() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(of: User.self, id: "user-1").makeAsyncIterator()

        guard case .initial(let user)? = try await iterator.next() else {
            Issue.record("Expected an initial change")
            return
        }

        #expect(user.firstName == "Steve")
    }

    @Test("a modification reports which properties changed")
    func modificationReportsProperties() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(of: User.self, id: "user-1").makeAsyncIterator()
        _ = try await iterator.next()

        try await store.update(User.self, id: "user-1") { $0.firstName = "Renamed" }

        guard case .change(let user, let properties)? = try await iterator.next() else {
            Issue.record("Expected a change")
            return
        }

        #expect(user.firstName == "Renamed")
        #expect(properties.contains("firstName"))
    }

    @Test("deletion is reported and finishes the stream")
    func deletionFinishesStream() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(of: User.self, id: "user-1").makeAsyncIterator()
        _ = try await iterator.next()

        try await store.delete(User.self, id: "user-1")

        guard case .deleted? = try await iterator.next() else {
            Issue.record("Expected a deletion")
            return
        }

        #expect(try await iterator.next() == nil)
    }

    @Test("observing an unknown key finishes without emitting")
    func unknownKeyFinishes() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        var iterator = await store.changes(of: User.self, id: "nope").makeAsyncIterator()

        #expect(try await iterator.next() == nil)
    }
}
