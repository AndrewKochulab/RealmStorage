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
    private let preparer: DatabasePreparer
    private var resolvedFileURL: URL?

    // MARK: - Initialization

    public init(configuration: StorageConfiguration) {
        self.configuration = configuration
        self.preparer = DatabasePreparer(configuration: configuration)
    }

    // MARK: - Lifecycle

    /// Opens the database on the main actor.
    ///
    /// Directory resolution, encryption setup and plaintext-to-encrypted file migration
    /// go through the same ``DatabasePreparer`` as ``RealmStore``, so the two agree
    /// exactly on where the file is and how it is protected — and this opens only one
    /// Realm rather than holding a second store open behind it.
    public func open() async throws {
        guard realm == nil else { return }

        do {
            try await openRealm()
        } catch {
            guard configuration.corruptionPolicy.shouldReset(after: error) else {
                throw StorageError.openFailed(underlying: error)
            }

            try reset()

            do {
                try await openRealm()
            } catch let retryError {
                // Recovery did not help; surface the second failure, wrapped.
                throw StorageError.openFailed(underlying: retryError)
            }

            throw StorageError.databaseWasReset(underlying: error)
        }
    }

    /// Closes the database. A later ``open()`` reopens it.
    public func close() {
        realm = nil
    }

    /// Deletes the database and every sidecar file.
    public func reset() throws {
        realm = nil

        guard let resolvedFileURL else { return }
        try FileStorageMigrator().removeDatabase(at: resolvedFileURL)
    }

    private func openRealm() async throws {
        let prepared = try preparer.prepare()

        // Record the path *before* opening. `reset()` needs it to delete a file that
        // failed to open, and assigning it afterwards left recovery with nothing to
        // remove — so `CorruptionPolicy.deleteAndRecreate` could never actually recover.
        resolvedFileURL = prepared.fileURL

        realm = try await Realm(configuration: prepared.realmConfiguration, actor: MainActor.shared)

        try preparer.applyFileAttributes(to: prepared.fileURL)
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
        QueryPlan.results(query, in: try requireRealm())
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
