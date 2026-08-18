//
//  QueryTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

/// Covers the operators that PredicateFlow used to provide, confirming Realm's native
/// `Query` is a complete replacement.
@Suite("Queries")
struct QueryTests {

    private func seededStore() async throws -> RealmStore {
        try await TestStore.seeded(TestStore.sampleUsers(count: 5))
    }

    // MARK: - Equality and comparison

    @Test("equality and inequality")
    func equality() async throws {
        let store = try await seededStore()

        let matching = try await store.count(User.self, matching: DatabaseQuery { $0.firstName == "Robert" })
        let others = try await store.count(User.self, matching: DatabaseQuery { $0.firstName != "Robert" })

        #expect(matching == 1)
        #expect(others == 4)
    }

    @Test("comparison operators")
    func comparison() async throws {
        let store = try await seededStore()

        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.age > 30 }) == 3)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.age >= 30 }) == 4)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.age < 30 }) == 1)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.age <= 30 }) == 2)
    }

    @Test("in(_:) matches a set of values")
    func inCollection() async throws {
        let store = try await seededStore()

        let count = try await store.count(
            User.self,
            matching: DatabaseQuery { $0.firstName.in(["Robert", "Tony"]) }
        )

        #expect(count == 2)
    }

    // MARK: - Optionals

    @Test("nil and non-nil comparisons")
    func nilChecks() async throws {
        let store = try await seededStore()

        let unset = try await store.count(User.self, matching: DatabaseQuery { $0.updatedAt == nil })
        let set = try await store.count(User.self, matching: DatabaseQuery { $0.updatedAt != nil })

        #expect(unset == 3)
        #expect(set == 2)
    }

    // MARK: - Booleans

    @Test("boolean fields")
    func booleans() async throws {
        let store = try await seededStore()

        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.isActive == true }) == 3)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.isActive == false }) == 2)
    }

    // MARK: - Strings

    @Test("string operators with options")
    func stringOperators() async throws {
        let store = try await seededStore()

        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.firstName.contains("ob") }) == 1)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.firstName.starts(with: "S") }) == 1)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.firstName.ends(with: "y") }) == 1)
        #expect(try await store.count(User.self, matching: DatabaseQuery { $0.firstName.like("R*t") }) == 1)

        // Case-insensitivity replaces PredicateFlow's StringComparisonOption.
        let insensitive = try await store.count(
            User.self,
            matching: DatabaseQuery { $0.firstName.contains("ROBERT", options: .caseInsensitive) }
        )
        #expect(insensitive == 1)
    }

    @Test("the ! prefix operator covers PredicateFlow's not* variants")
    func negation() async throws {
        let store = try await seededStore()

        let notContaining = try await store.count(
            User.self,
            matching: DatabaseQuery { !$0.firstName.contains("o") }
        )

        #expect(notContaining == 2)
    }

    // MARK: - Compound

    @Test("&& and || compose conditions")
    func compound() async throws {
        let store = try await seededStore()

        let both = try await store.count(
            User.self,
            matching: DatabaseQuery { $0.age >= 30 && $0.isActive == true }
        )
        let either = try await store.count(
            User.self,
            matching: DatabaseQuery { $0.age < 25 || $0.age > 55 }
        )

        #expect(both == 2)
        #expect(either == 2)
    }

    // MARK: - Collections

    @Test("collection count and aggregates")
    func collections() async throws {
        let store = try await TestStore.make()

        try await store.write { realm in
            let user = User(id: "with-events", firstName: "Nick")
            user.events.append(objectsIn: [
                Event(id: "e1", name: "One"),
                Event(id: "e2", name: "Two")
            ])
            realm.add(user)
            realm.add(User(id: "no-events", firstName: "Solo"))
        }

        let busy = try await store.count(User.self, matching: DatabaseQuery { $0.events.count >= 2 })
        let idle = try await store.count(User.self, matching: DatabaseQuery { $0.events.count == 0 })

        #expect(busy == 1)
        #expect(idle == 1)
    }

    @Test("implicit-ANY traversal into a relationship")
    func relationshipTraversal() async throws {
        let store = try await TestStore.make()

        try await store.write { realm in
            let user = User(id: "u", firstName: "Nick")
            user.events.append(Event(id: "e1", name: "Avengers Game"))
            realm.add(user)
        }

        let count = try await store.count(
            User.self,
            matching: DatabaseQuery { $0.events.name == "Avengers Game" }
        )

        #expect(count == 1)
    }

    // MARK: - Sorting, limiting, distinct

    @Test("sorting by key path, both directions")
    func sorting() async throws {
        let store = try await seededStore()

        let ascending = try await store.objects(
            User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age)
        ) { $0.age }

        let descending = try await store.objects(
            User.self,
            matching: DatabaseQuery<User>().sorted(by: \.age, ascending: false)
        ) { $0.age }

        #expect(ascending == [20, 30, 40, 50, 60])
        #expect(descending == [60, 50, 40, 30, 20])
    }

    @Test("Sort.ascending / .descending helpers")
    func sortHelpers() async throws {
        let store = try await seededStore()
        let query = DatabaseQuery<User>().sorted(by: [Sort.descending(\User.age)])

        let ages = try await store.objects(User.self, matching: query) { $0.age }

        #expect(ages.first == 60)
    }

    @Test("limit truncates results")
    func limit() async throws {
        let store = try await seededStore()
        let query = DatabaseQuery<User>().sorted(by: \.age).limited(to: 2)

        let users = try await store.all(User.self)
        let limited = try await store.objects(User.self, matching: query)

        #expect(users.count == 5)
        #expect(limited.count == 2)
        #expect(limited[0].age == 20)
    }

    @Test("distinct collapses duplicates")
    func distinct() async throws {
        let store = try await TestStore.make()
        try await store.save([
            User(id: "a", lastName: "Stark"),
            User(id: "b", lastName: "Stark"),
            User(id: "c", lastName: "Rogers")
        ])

        let query = DatabaseQuery<User>().distinct(by: \.lastName)
        let count = try await store.count(User.self, matching: query)

        #expect(count == 2)
    }

    // MARK: - Escape hatch

    @Test("NSPredicate escape hatch reaches SUBQUERY")
    func nsPredicateEscapeHatch() async throws {
        let store = try await TestStore.make()

        try await store.write { realm in
            let busy = User(id: "busy", firstName: "Busy")
            busy.events.append(objectsIn: [
                Event(id: "e1", name: "Talk"),
                Event(id: "e2", name: "Talk")
            ])

            let quiet = User(id: "quiet", firstName: "Quiet")
            quiet.events.append(Event(id: "e3", name: "Talk"))

            realm.add([busy, quiet])
        }

        // A counted SUBQUERY is awkward to express through the type-safe API; this is
        // what the escape hatch is for.
        let query = DatabaseQuery<User>().filter {
            NSPredicate(format: "SUBQUERY(events, $e, $e.name == %@).@count > 1", "Talk")
        }

        let ids = try await store.objects(User.self, matching: query) { $0.id }

        #expect(ids == ["busy"])
    }

    @Test("NONE is reachable through the escape hatch")
    func nonePredicate() async throws {
        let store = try await TestStore.make()

        try await store.write { realm in
            let clean = User(id: "clean", firstName: "Clean")
            clean.events.append(Event(id: "e1", name: "Talk"))

            let flagged = User(id: "flagged", firstName: "Flagged")
            flagged.events.append(Event(id: "e2", name: "banned"))

            realm.add([clean, flagged])
        }

        let query = DatabaseQuery<User>().filter {
            NSPredicate(format: "NONE events.name == %@", "banned")
        }

        let ids = try await store.objects(User.self, matching: query) { $0.id }

        #expect(ids == ["clean"])
    }

    @Test("queries are values: building on one leaves the original alone")
    func queriesAreValues() async throws {
        let store = try await seededStore()

        let base = DatabaseQuery<User>()
        let filtered = base.where { $0.age >= 40 }

        #expect(try await store.count(User.self, matching: base) == 5)
        #expect(try await store.count(User.self, matching: filtered) == 3)
    }

    @Test("where(_:) replaces rather than appends the filter")
    func whereReplaces() async throws {
        let store = try await seededStore()

        let query = DatabaseQuery<User>()
            .where { $0.age >= 40 }
            .where { $0.age < 30 }

        #expect(try await store.count(User.self, matching: query) == 1)
    }
}
