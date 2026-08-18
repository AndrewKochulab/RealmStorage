//
//  CorruptionPolicy.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// What to do when the database cannot be opened.
///
/// v1 caught **every** error from initialization and deleted the database file. A
/// locked-Keychain background launch, a full disk, or a transient permission error all
/// destroyed user data. The default here is ``rethrow``; deleting anything is opt-in.
public enum CorruptionPolicy: Sendable {

    /// Propagate the error. The database is left untouched. **Default.**
    case rethrow

    /// Delete and recreate the database, but only for errors that are genuinely
    /// unrecoverable — see ``isUnrecoverable(_:)``. Recoverable errors still throw.
    case deleteAndRecreate

    /// Decide per error. Return `true` to delete and recreate, `false` to rethrow.
    case custom(@Sendable (any Error) -> Bool)

    /// Whether `error` means the file itself is beyond saving.
    ///
    /// Deliberately narrow: a transient failure must not be mistaken for corruption,
    /// because the consequence is destroying the user's data. Only two conditions
    /// qualify, and both mean the bytes on disk cannot be opened by this version of
    /// Realm at all:
    ///
    /// - `RLMErrorInvalidDatabase` — not a Realm file, or unreadable.
    /// - `RLMErrorUnsupportedFileFormatVersion` — written by a newer Realm.
    ///
    /// Explicitly **not** included:
    ///
    /// - File access and permission errors, which are usually transient. Treating them
    ///   as corruption is exactly how 1.x destroyed databases on a locked-Keychain
    ///   background launch.
    /// - Schema mismatches, which mean a migration is missing — a developer error, fixed
    ///   by writing the migration rather than by deleting user data. If you really do
    ///   want the database dropped on schema drift, that is
    ///   ``StorageConfiguration/deleteRealmIfMigrationNeeded``.
    ///
    /// - Note: Realm surfaces these as an `NSError` in the `io.realm` domain rather than
    ///   as a `Realm.Error`, so matching is done on the domain and code.
    public static func isUnrecoverable(_ error: any Error) -> Bool {
        // The error may already be wrapped by the time a custom policy passes it back.
        if case StorageError.openFailed(let underlying) = error {
            return isUnrecoverable(underlying)
        }

        let nsError = error as NSError
        guard nsError.domain == realmErrorDomain else { return false }

        return unrecoverableCodes.contains(nsError.code)
    }

    /// `RLMErrorDomain`.
    private static let realmErrorDomain = "io.realm"

    /// `RLMErrorInvalidDatabase` and `RLMErrorUnsupportedFileFormatVersion`.
    private static let unrecoverableCodes: Set<Int> = [20, 16]

    /// Applies the policy to `error`.
    func shouldReset(after error: any Error) -> Bool {
        switch self {
        case .rethrow:
            return false
        case .deleteAndRecreate:
            return Self.isUnrecoverable(error)
        case .custom(let decide):
            return decide(error)
        }
    }
}
