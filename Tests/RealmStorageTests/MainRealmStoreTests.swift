//
//  MainRealmStoreTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// The main-actor façade exists so SwiftUI and UIKit can bind to **live**, auto-updating
/// results. `RealmStore` deliberately hands back frozen snapshots; freezing would break
/// observation, so the view layer gets its own entry point.
@Suite("Main-actor store")
@MainActor
struct MainRealmStoreTests {

    private func makeStore() -> MainRealmStore {
        MainRealmStore(
            configuration: .inMemory(identifier: UUID().uuidString, objectTypes: TestModels.all)
        )
    }

    @Test("results are live, not frozen")
    func resultsAreLive() async throws {
        let store = makeStore()
        try await store.open()

        try store.write { realm in
            realm.add(User(id: "u1", firstName: "Steve"))
        }

        let users = try store.objects(User.self)

        #expect(users.count == 1)
        #expect(!users[0].isFrozen)
    }

    @Test("live results update in place after a write")
    func resultsUpdateInPlace() async throws {
        let store = makeStore()
        try await store.open()

        let users = try store.objects(User.self)
        #expect(users.count == 0)

        try store.write { realm in
            realm.add(User(id: "u1", firstName: "Steve"))
        }

        // The same Results value now reflects the write — this is what freezing costs you.
        #expect(users.count == 1)
    }

    @Test("a type-safe predicate filters live results")
    func filteredResults() async throws {
        let store = makeStore()
        try await store.open()

        try store.write { realm in
            realm.add(User(id: "a", age: 20))
            realm.add(User(id: "b", age: 40))
        }

        let adults = try store.objects(User.self) { $0.age >= 30 }

        #expect(adults.count == 1)
        #expect(adults[0].id == "b")
    }

    @Test("object(id:) returns a live object")
    func objectByID() async throws {
        let store = makeStore()
        try await store.open()

        try store.write { realm in
            realm.add(User(id: "u1", firstName: "Steve"))
        }

        let user = try store.object(User.self, id: "u1")

        #expect(user?.firstName == "Steve")
        #expect(user?.isFrozen == false)
    }

    @Test("reading before open() throws storeNotOpen")
    func readingBeforeOpen() throws {
        let store = makeStore()

        #expect(throws: StorageError.self) {
            _ = try store.objects(User.self)
        }
    }

    @Test("close() then a read throws storeNotOpen")
    func closeThenRead() async throws {
        let store = makeStore()
        try await store.open()
        await store.close()

        #expect(throws: StorageError.self) {
            _ = try store.objects(User.self)
        }
    }
}
