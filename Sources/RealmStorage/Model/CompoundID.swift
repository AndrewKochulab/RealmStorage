//
//  CompoundID.swift
//  RealmStorage
//

import Foundation

/// Builds a composite primary key by joining its parts.
///
/// v1's `CompoundEntityID` was a distinct identity *type*. Now that primary keys are
/// ordinary `StorageID` values, composing one is just string building, so this is a
/// helper rather than something in the type system.
///
/// ```swift
/// member.id = CompoundID.make(user.id.uuidString, event.id.uuidString)
/// ```
public enum CompoundID {

    /// The separator used when none is given.
    public static let defaultSeparator = "_"

    /// Joins `parts` with `separator`.
    public static func make(_ parts: String..., separator: String = defaultSeparator) -> String {
        make(parts, separator: separator)
    }

    /// Joins `parts` with `separator`.
    public static func make(_ parts: [String], separator: String = defaultSeparator) -> String {
        parts.joined(separator: separator)
    }
}
