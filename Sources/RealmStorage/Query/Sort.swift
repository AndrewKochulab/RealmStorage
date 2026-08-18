//
//  Sort.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A sort ordering over `Element`, expressed as a key path.
///
/// v1 declared `extension RealmSwift.SortDescriptor: DatabaseSortDescriptor` — a
/// retroactive conformance on a type from another module, which Swift 6 warns about and
/// which caused the "ambiguous SortDescriptor" bug fixed in 240c7c0. That collision is
/// worse today: Foundation now ships its own `SortDescriptor`, so the bare name is
/// genuinely ambiguous. Owning the type outright avoids both problems, and every
/// reference to Realm's version in this package is spelled `RealmSwift.SortDescriptor`.
public struct Sort<Element: ObjectBase>: Sendable {

    /// The key path to sort on, as Realm's string form.
    public let keyPath: String

    /// Whether the ordering is ascending.
    public let ascending: Bool

    /// Sorts on a type-safe key path.
    public init<Value>(_ keyPath: KeyPath<Element, Value>, ascending: Bool = true) {
        self.keyPath = _name(for: keyPath)
        self.ascending = ascending
    }

    /// Sorts on a key path given as a string, for paths that cross relationships
    /// (`"author.name"`) or that no key path can express.
    public init(keyPath: String, ascending: Bool = true) {
        self.keyPath = keyPath
        self.ascending = ascending
    }

    /// Ascending order on `keyPath`.
    public static func ascending<Value>(_ keyPath: KeyPath<Element, Value>) -> Sort {
        Sort(keyPath, ascending: true)
    }

    /// Descending order on `keyPath`.
    public static func descending<Value>(_ keyPath: KeyPath<Element, Value>) -> Sort {
        Sort(keyPath, ascending: false)
    }

    /// The Realm equivalent.
    var realmSortDescriptor: RealmSwift.SortDescriptor {
        RealmSwift.SortDescriptor(keyPath: keyPath, ascending: ascending)
    }
}
