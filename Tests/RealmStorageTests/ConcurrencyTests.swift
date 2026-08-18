//
//  ConcurrencyTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// v1 cached `Realm` instances in an unsynchronised dictionary keyed by dispatch-queue
/// label, mutated from arbitrary queues — an outright data race. These exercise the
/// replacement.
///
/// Some of the coverage here is at compile time rather than runtime: if the API ever
/// regressed to handing out non-`Sendable` values, this file would stop building, and a
/// build failure is as good an assertion as an expectation.
@Suite("Concurrency")
struct ConcurrencyTests {

    @Test("concurrent readers see a consistent database")
    func concurrentReads() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        let counts = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<32 {
                group.addTask { try await store.count(User.self) }
            }

            var results: [Int] = []
            for try await count in group { results.append(count) }
            return results
        }

        #expect(counts.count == 32)
        #expect(counts.allSatisfy { $0 == 5 })
    }

    @Test("concurrent writers all land")
    func concurrentWrites() async throws {
        let store = try await TestStore.make()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    try await store.save(User(id: "user-\(index)", age: index))
                }
            }

            try await group.waitForAll()
        }

        #expect(try await store.count(User.self) == 50)
    }

    @Test("interleaved readers and writers neither crash nor deadlock")
    func mixedReadersAndWriters() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 5))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await store.save(User(id: "extra-\(index)", age: index))
                }
                group.addTask {
                    _ = try await store.count(User.self)
                }
                group.addTask {
                    _ = try await store.all(User.self).count
                }
            }

            try await group.waitForAll()
        }

        #expect(try await store.count(User.self) == 25)
    }

    /// Results must survive being moved between isolation domains. This compiling at all
    /// is the point; the expectation just confirms the data came through.
    @Test("results cross actor boundaries")
    func resultsCrossActorBoundaries() async throws {
        actor Collector {
            var received: [String] = []

            func accept<Element: Object>(_ results: StorageResults<Element>) where Element: User {
                received = results.map(\.id)
            }
        }

        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))
        let collector = Collector()

        let users = try await store.objects(User.self, matching: DatabaseQuery<User>().sorted(by: \.age))
        await collector.accept(users)

        #expect(await collector.received == ["user-0", "user-1", "user-2"])
    }

    @Test("a frozen single object crosses to the main actor")
    @MainActor
    func frozenObjectCrossesToMainActor() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let user = try await store.object(User.self, id: "user-1")

        #expect(user?.firstName == "Steve")
        #expect(user?.object.isFrozen == true)
    }

    @Test("two stores are fully independent")
    func storesAreIndependent() async throws {
        let first = try await TestStore.make()
        let second = try await TestStore.make()

        try await first.save(User(id: "only-in-first"))

        #expect(try await first.count(User.self) == 1)
        #expect(try await second.count(User.self) == 0)
    }

    @Test("frozen results keep the values they were read with")
    func frozenResultsAreSnapshots() async throws {
        let store = try await TestStore.seeded(TestStore.sampleUsers(count: 3))

        let snapshot = try await store.all(User.self)
        try await store.deleteAll(User.self)

        #expect(snapshot.count == 3)
        #expect(try await store.count(User.self) == 0)
    }
}
