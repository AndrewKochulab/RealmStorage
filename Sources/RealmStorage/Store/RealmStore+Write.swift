//
//  RealmStore+Write.swift
//  RealmStorage
//

import Foundation
import RealmSwift

public extension RealmStore {

    // MARK: - The write primitive

    /// Runs `body` inside a write transaction and commits it.
    ///
    /// Every other write is sugar over this. The transaction is Realm's own
    /// `asyncWrite`, which handles nesting and rollback correctly — v1 hand-rolled two
    /// container classes for this, one of which called `cancelWrite()` in its `catch`
    /// even when it had not opened the transaction, tearing down the caller's outer one.
    ///
    /// ```swift
    /// try await store.write { realm in
    ///     realm.add(user, update: .modified)
    ///     realm.add(event, update: .modified)
    /// }
    /// ```
    @discardableResult
    func write<T: Sendable>(_ body: @Sendable (Realm) throws -> T) async throws -> T {
        let realm = try requireRealm()
        return try await realm.asyncWrite { try body(realm) }
    }

    // MARK: - Saving

    /// Adds or updates `object`.
    ///
    /// `update` is Realm's own ``Realm/UpdatePolicy``, not a `Bool`. v1 took
    /// `update: Bool` and mapped it to `update ? .modified : .all` — but `.all` is itself
    /// an upsert, and the *more* destructive one, so `update: false` overwrote rather than
    /// erroring. Naming the policy directly removes the trap.
    ///
    /// - Parameter object: a `sending` parameter, so a freshly built object can be handed
    ///   to the actor. It must not be referenced afterwards on the calling side.
    func save<Element: Object>(
        _ object: sending Element,
        update: Realm.UpdatePolicy = .modified
    ) async throws {
        let realm = try requireRealm()
        try await realm.asyncWrite { realm.add(object, update: update) }
    }

    /// Adds or updates several objects.
    func save<Element: Object>(
        _ objects: sending [Element],
        update: Realm.UpdatePolicy = .modified
    ) async throws {
        let realm = try requireRealm()
        try await realm.asyncWrite { realm.add(objects, update: update) }
    }

    /// Builds an object inside the transaction and adds it.
    ///
    /// Useful when the object needs a live Realm to construct — for example when linking
    /// to objects already in the database.
    func save<Element: Object>(
        update: Realm.UpdatePolicy = .modified,
        building build: @Sendable (Realm) throws -> Element
    ) async throws {
        let realm = try requireRealm()

        try await realm.asyncWrite {
            let object = try build(realm)
            realm.add(object, update: update)
        }
    }

    // MARK: - Updating

    /// Applies `mutate` to the object with primary key `id`.
    ///
    /// Throws ``StorageError/objectNotFound`` when no such object exists.
    func update<Element: IdentifiableStorage>(
        _ type: Element.Type,
        id: Element.ID,
        _ mutate: @Sendable (Element) throws -> Void
    ) async throws where Element: Object {
        let realm = try requireRealm()

        try await realm.asyncWrite {
            guard let object = realm.object(ofType: type, forPrimaryKey: id) else {
                throw StorageError.objectNotFound
            }

            try mutate(object)
        }
    }

    /// Applies `mutate` to every object matching `query`.
    ///
    /// - Returns: how many objects were updated.
    @discardableResult
    func update<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element>,
        _ mutate: @Sendable (Element) throws -> Void
    ) async throws -> Int {
        let realm = try requireRealm()

        return try await realm.asyncWrite {
            // `elements` applies the query's limit; `results` would not, so an
            // `update(matching: query.limited(to: 5))` would quietly touch every match.
            let objects = QueryPlan.elements(query, in: realm)
            try objects.forEach(mutate)

            return objects.count
        }
    }

    // MARK: - Deleting

    /// Deletes the object with primary key `id`.
    ///
    /// - Returns: `true` when an object was deleted, `false` when none matched.
    @discardableResult
    func delete<Element: IdentifiableStorage>(
        _ type: Element.Type,
        id: Element.ID
    ) async throws -> Bool where Element: Object {
        let realm = try requireRealm()

        return try await realm.asyncWrite {
            guard let object = realm.object(ofType: type, forPrimaryKey: id) else {
                return false
            }

            realm.delete(object)
            return true
        }
    }

    /// Deletes every object matching `query`.
    ///
    /// - Returns: how many objects were deleted.
    @discardableResult
    func delete<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element>
    ) async throws -> Int {
        let realm = try requireRealm()

        return try await realm.asyncWrite {
            // Must go through `elements`, which applies the query's limit. Deleting the
            // unlimited `results` would destroy every match of a `.limited(to:)` query.
            let objects = QueryPlan.elements(query, in: realm)
            let count = objects.count

            realm.delete(objects)
            return count
        }
    }

    /// Deletes every object of `type`.
    @discardableResult
    func deleteAll<Element: Object>(_ type: Element.Type) async throws -> Int {
        try await delete(type, matching: DatabaseQuery<Element>())
    }

    /// Empties the database.
    func deleteAll() async throws {
        let realm = try requireRealm()
        try await realm.asyncWrite { realm.deleteAll() }
    }
}
