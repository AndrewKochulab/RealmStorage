//
//  MainRealmStore.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A main-actor database handle that returns **live** Realm results.
///
/// ``RealmStore`` hands back frozen snapshots, which is what makes it safe to share. But
/// SwiftUI and UIKit want live, auto-updating `Results` they can bind to directly, and
/// freezing would break that. Because this type is pinned to the main actor, its Realm is
/// opened on the main actor too and its objects never cross an isolation boundary — so
/// live values are safe here in a way they are not on ``RealmStore``.
///
/// Use this for the view layer; use ``RealmStore`` for everything else. They can point at
/// the same ``StorageConfiguration``.
///
/// ```swift
/// @MainActor
/// final class UserListModel {
///     private let store = MainRealmStore(configuration: .init(objectTypes: [User.self]))
///
///     func load() async throws {
///         try await store.open()
///         users = try store.objects(User.self) { $0.isActive == true }  // live
///     }
/// }
/// ```
@MainActor
public final class MainRealmStore {

    // MARK: - Properties

    /// How this store was configured.
    public nonisolated let configuration: StorageConfiguration

    private var realm: Realm?
    private let backing: RealmStore

    // MARK: - Initialization

    public init(configuration: StorageConfiguration) {
        self.configuration = configuration
        self.backing = RealmStore(configuration: configuration)
    }

    // MARK: - Lifecycle

    /// Opens the database on the main actor.
    ///
    /// File migration, encryption setup and the corruption policy are handled by a
    /// backing ``RealmStore``, so behaviour matches exactly.
    public func open() async throws {
        guard realm == nil else { return }

        try await backing.open()

        let realmConfiguration = try await backing.currentRealmConfiguration()
        realm = try await Realm(configuration: realmConfiguration, actor: MainActor.shared)
    }

    /// Closes the database.
    public func close() async {
        realm = nil
        await backing.close()
    }

    // MARK: - Access

    /// The open `Realm`, or a throw when ``open()`` has not run.
    public func requireRealm() throws -> Realm {
        guard let realm else { throw StorageError.storeNotOpen }
        return realm
    }

    /// Live results matching `query`, suitable for binding to a view.
    public func objects<Element: Object>(
        _ type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) throws -> Results<Element> {
        QueryPlan.resolve(query, in: try requireRealm())
    }

    /// Live results matching a type-safe predicate.
    public func objects<Element: Object>(
        _ type: Element.Type,
        where filter: @escaping DatabaseQuery<Element>.Filter
    ) throws -> Results<Element> {
        try objects(type, matching: DatabaseQuery(filter))
    }

    /// The live object with primary key `id`, or `nil`.
    public func object<Element: IdentifiableStorage>(
        _ type: Element.Type,
        id: Element.ID
    ) throws -> Element? where Element: Object {
        try requireRealm().object(ofType: type, forPrimaryKey: id)
    }

    /// Runs `body` in a write transaction on the main actor.
    @discardableResult
    public func write<T>(_ body: (Realm) throws -> T) throws -> T {
        let realm = try requireRealm()
        return try realm.write { try body(realm) }
    }
}
