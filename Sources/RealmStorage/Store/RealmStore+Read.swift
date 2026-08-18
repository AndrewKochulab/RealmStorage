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
        StorageResults(QueryPlan.results(query, in: try requireRealm()), limit: query.limit)
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
    /// A compile error on a type without a primary key. 1.x raised a runtime `fatalError`.
    func object<Element: IdentifiableStorage>(
        _ type: Element.Type,
        id: Element.ID
    ) throws -> Frozen<Element>? where Element: Object {
        try requireRealm().object(ofType: type, forPrimaryKey: id).map(Frozen.init)
    }

    /// The objects of `type` with the given primary keys, in the order they are found.
    ///
    /// Missing keys are skipped rather than producing `nil` holes.
    func objects<Element: IdentifiableStorage>(
        _ type: Element.Type,
        ids: some Sequence<Element.ID>
    ) throws -> StorageResults<Element> where Element: Object {
        let realm = try requireRealm()
        let primaryKeyPath = Element.primaryKeyPath(in: realm)

        return StorageResults(
            realm.objects(Element.self)
                .filter(NSPredicate(format: "%K IN %@", primaryKeyPath, Array(ids)))
        )
    }

    /// The first object matching `query`, or `nil`.
    func first<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Frozen<Element>? {
        QueryPlan.first(query, in: try requireRealm()).map(Frozen.init)
    }

    /// The last object matching `query`, or `nil`.
    func last<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Frozen<Element>? {
        QueryPlan.last(query, in: try requireRealm()).map(Frozen.init)
    }

    // MARK: - Aggregates

    /// How many objects match `query`.
    ///
    /// Counted in the database rather than by materialising the results.
    func count<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Int {
        QueryPlan.count(query, in: try requireRealm())
    }

    /// Whether any object matches `query`.
    func contains<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Bool {
        QueryPlan.count(query, in: try requireRealm()) > 0
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
        try QueryPlan.elements(query, in: try requireRealm()).map(transform)
    }
}

extension IdentifiableStorage where Self: Object {

    /// The name of this type's primary-key property, for predicates that cannot use a
    /// Swift key path.
    static func primaryKeyPath(in realm: Realm) -> String {
        realm.schema[className()]?.primaryKeyProperty?.name ?? "id"
    }
}
