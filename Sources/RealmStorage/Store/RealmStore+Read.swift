//
//  RealmStore+Read.swift
//  RealmStorage
//

import Foundation
import RealmSwift

public extension RealmStore {

    // MARK: - Fetching

    /// Every object of `type`.
    func all<Element: Object>(_ type: Element.Type) throws -> StorageResults<Element> {
        try objects(type, matching: DatabaseQuery<Element>())
    }

    /// Objects of `type` matching `query`.
    func objects<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> StorageResults<Element> {
        let results = QueryPlan.resolve(query, in: try requireRealm())
        return StorageResults(results, limit: query.limit)
    }

    /// Objects of `type` matching a type-safe predicate.
    ///
    /// Shorthand for the common case:
    /// ```swift
    /// let adults = try await store.objects(User.self) { $0.age >= 18 }
    /// ```
    func objects<Element: Object>(
        _ type: Element.Type,
        where filter: @escaping DatabaseQuery<Element>.Filter
    ) throws -> StorageResults<Element> {
        try objects(type, matching: DatabaseQuery(filter))
    }

    // MARK: - Single objects
    //
    // These return ``Frozen`` rather than a bare optional: a Realm `Object` is not
    // `Sendable` even once frozen, so it cannot leave the actor unwrapped. Dynamic member
    // lookup means call sites still read as `user?.firstName`.

    /// The object of `type` with primary key `id`, or `nil`.
    ///
    /// A compile error on a type without a primary key. v1 raised a runtime `fatalError`.
    func object<Element: IdentifiableStorage>(
        _ type: Element.Type,
        id: Element.ID
    ) throws -> Frozen<Element>? where Element: Object {
        try requireRealm().object(ofType: type, forPrimaryKey: id).map(Frozen.init)
    }

    /// The first object matching `query`, or `nil`.
    func first<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Frozen<Element>? {
        QueryPlan.resolve(query, in: try requireRealm()).first.map(Frozen.init)
    }

    /// The last object matching `query`, or `nil`.
    func last<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Frozen<Element>? {
        QueryPlan.resolve(query, in: try requireRealm()).last.map(Frozen.init)
    }

    // MARK: - Aggregates

    /// How many objects match `query`.
    ///
    /// Counted in the database rather than by materialising the results.
    func count<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Int {
        QueryPlan.resolve(query, in: try requireRealm()).count
    }

    /// Whether any object matches `query`.
    func contains<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Bool {
        !QueryPlan.resolve(query, in: try requireRealm()).isEmpty
    }

    // MARK: - Projections

    /// Fetches objects matching `query` and maps each through `transform`.
    ///
    /// The objects never leave the actor — only the `Sendable` results do. Use this when
    /// the caller wants plain value types rather than Realm objects.
    ///
    /// ```swift
    /// let names = try await store.objects(User.self, matching: query) { $0.firstName }
    /// ```
    func objects<Element: Object, T: Sendable>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init(),
        transform: @Sendable (Element) throws -> T
    ) throws -> [T] {
        let results = QueryPlan.resolve(query, in: try requireRealm())
        let limited = query.limit.map { Array(results.prefix($0)) } ?? Array(results)

        return try limited.map(transform)
    }
}
