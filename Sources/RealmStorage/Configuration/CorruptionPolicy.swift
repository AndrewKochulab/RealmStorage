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
    /// because the consequence is deleting the user's data.
    public static func isUnrecoverable(_ error: any Error) -> Bool {
        guard let realmError = error as? Realm.Error else { return false }

        switch realmError.code {
        case .invalidDatabase,
             .unsupportedFileFormatVersion,
             .schemaMismatch:
            return true
        default:
            return false
        }
    }

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
