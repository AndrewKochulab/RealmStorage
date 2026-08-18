//
//  RealmStore.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// An actor-isolated Realm database.
///
/// The `Realm` instance lives inside this actor and never leaves it, which is what makes
/// concurrent access safe. Reads hand back frozen ``StorageResults``; writes run through
/// ``write(_:)``.
///
/// This is a **per-instance** actor, not a global one. v1 exposed a process-wide
/// `RealmContext` singleton that cached `Realm` instances in an unsynchronised dictionary
/// keyed by dispatch-queue label — an outright data race — and mutated
/// `Realm.Configuration.defaultConfiguration` on the way. One store per instance means an
/// encrypted database and an in-memory test database can coexist, and tests can run in
/// parallel.
///
/// ```swift
/// let store = RealmStore(
///     configuration: StorageConfiguration(schemaVersion: 1, objectTypes: [User.self])
/// )
/// try await store.open()
///
/// try await store.save(User(id: UUID(), firstName: "Steve"))
/// let users = try await store.objects(User.self) { $0.firstName == "Steve" }
/// ```
public actor RealmStore {

    // MARK: - Properties

    /// How this store was configured.
    public nonisolated let configuration: StorageConfiguration

    private var realm: Realm?
    private let preparer: DatabasePreparer

    /// The resolved on-disk location, or `nil` for an in-memory database.
    private var resolvedFileURL: URL?

    // MARK: - Initialization

    public init(configuration: StorageConfiguration) {
        self.configuration = configuration
        self.preparer = DatabasePreparer(configuration: configuration)
    }

    // MARK: - Lifecycle

    /// Opens the database, running file migration and encryption setup as needed.
    ///
    /// Calling this more than once is a no-op.
    ///
    /// On failure the configured ``CorruptionPolicy`` decides what happens. The default,
    /// ``CorruptionPolicy/rethrow``, leaves the file untouched — unlike v1, which deleted
    /// the database on *any* initialization error, including a transient one.
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
    ///
    /// For an in-memory store this simply drops the instance.
    public func reset() throws {
        realm = nil

        guard let resolvedFileURL else { return }
        try FileStorageMigrator().removeDatabase(at: resolvedFileURL)
    }

    // MARK: - Access

    /// The open `Realm`, or a throw when ``open()`` has not run.
    func requireRealm() throws -> Realm {
        guard let realm else { throw StorageError.storeNotOpen }
        return realm
    }

    /// Runs `body` against the underlying `Realm` inside the actor.
    ///
    /// The escape hatch for anything this package does not wrap. The `Realm` must not
    /// escape the closure, and neither must any live object read from it — return frozen
    /// values or plain `Sendable` data instead.
    public func withRealm<T: Sendable>(_ body: @Sendable (Realm) throws -> T) throws -> T {
        try body(requireRealm())
    }

    // MARK: - Opening

    private func openRealm() async throws {
        let prepared = try preparer.prepare()

        // Record the path *before* opening. `reset()` needs it to delete a file that
        // failed to open, and assigning it afterwards left recovery with nothing to
        // remove — so `CorruptionPolicy.deleteAndRecreate` could never actually recover.
        resolvedFileURL = prepared.fileURL

        realm = try await Realm(configuration: prepared.realmConfiguration, actor: self)

        try preparer.applyFileAttributes(to: prepared.fileURL)
    }
}
