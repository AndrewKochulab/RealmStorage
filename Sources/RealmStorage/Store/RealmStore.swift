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
    private let fileMigrator: FileStorageMigrator

    /// The resolved on-disk location, or `nil` for an in-memory database.
    private var resolvedFileURL: URL?

    // MARK: - Initialization

    public init(configuration: StorageConfiguration) {
        self.configuration = configuration
        self.fileMigrator = FileStorageMigrator()
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
            try await openRealm()

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
        try fileMigrator.removeDatabase(at: resolvedFileURL)
    }

    // MARK: - Access

    /// The open `Realm`, or a throw when ``open()`` has not run.
    func requireRealm() throws -> Realm {
        guard let realm else { throw StorageError.storeNotOpen }
        return realm
    }

    /// The `Realm.Configuration` this store opened with.
    ///
    /// `Realm.Configuration` is `Sendable`, so this can safely cross to another
    /// isolation domain — which is how ``MainRealmStore`` reuses the file migration,
    /// encryption and corruption handling done here instead of repeating it.
    func currentRealmConfiguration() throws -> Realm.Configuration {
        try requireRealm().configuration
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
        let realmConfiguration = try makeRealmConfiguration()

        let realm = try await Realm(configuration: realmConfiguration, actor: self)
        self.realm = realm

        try applyFileAttributes()
    }

    private func makeRealmConfiguration() throws -> Realm.Configuration {
        var realmConfiguration = Realm.Configuration()

        realmConfiguration.schemaVersion = configuration.schemaVersion
        realmConfiguration.objectTypes = configuration.objectTypes
        realmConfiguration.readOnly = configuration.isReadOnly

        if let migrate = configuration.migrate {
            realmConfiguration.migrationBlock = { migration, oldSchemaVersion in
                migrate(migration, oldSchemaVersion)
            }
        }

        // In-memory: no file, and Realm rejects an encryption key alongside an identifier.
        if case .inMemory(let identifier) = configuration.location {
            realmConfiguration.inMemoryIdentifier = identifier
            resolvedFileURL = nil

            return realmConfiguration
        }

        guard let directory = try configuration.location.resolveDirectory() else {
            throw StorageError.storageDirectoryUnavailable
        }

        let encryptionKey = try resolveEncryptionKey()

        let fileURL: URL
        if encryptionKey != nil {
            fileURL = encryptedFileURL(in: directory)

            // Carry a pre-existing plaintext database over to the encrypted file.
            try fileMigrator.migrateToEncrypted(
                from: plaintextFileURL(in: directory),
                to: fileURL,
                key: encryptionKey!,
                source: .init(
                    schemaVersion: configuration.schemaVersion,
                    objectTypes: configuration.objectTypes,
                    migrate: configuration.migrate
                )
            )
        } else {
            fileURL = plaintextFileURL(in: directory)
        }

        realmConfiguration.fileURL = fileURL
        realmConfiguration.encryptionKey = encryptionKey
        resolvedFileURL = fileURL

        return realmConfiguration
    }

    private func resolveEncryptionKey() throws -> Data? {
        switch configuration.encryption {
        case .none:
            return nil

        case .key(let key):
            guard key.count == EncryptionKeyProvider.requiredKeyLength else {
                throw StorageError.encryptionKeyInvalidLength(
                    expected: EncryptionKeyProvider.requiredKeyLength,
                    actual: key.count
                )
            }

            return key

        case .keychain(let store, let account):
            return try EncryptionKeyProvider(store: store, account: account).key()
        }
    }

    private func applyFileAttributes() throws {
        guard let resolvedFileURL else { return }

        if let fileProtection = configuration.fileProtection {
            try fileMigrator.applyFileProtection(fileProtection, to: resolvedFileURL)
        }

        if configuration.excludedFromBackup {
            try fileMigrator.excludeFromBackup(resolvedFileURL)
        }
    }

    private func plaintextFileURL(in directory: URL) -> URL {
        directory
            .appendingPathComponent(configuration.fileName)
            .appendingPathExtension("realm")
    }

    private func encryptedFileURL(in directory: URL) -> URL {
        directory
            .appendingPathComponent("\(configuration.fileName)_encrypted")
            .appendingPathExtension("realm")
    }
}
