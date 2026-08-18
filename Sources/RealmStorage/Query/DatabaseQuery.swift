//
//  DatabaseQuery.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A composable, `Sendable` description of what to fetch.
///
/// This replaces v1's PredicateFlow — roughly 2,000 vendored lines plus a Sourcery build
/// phase that generated a `…Schema` struct per model. Realm's own `Query` covers the same
/// ground natively against key paths, with no code generation:
///
/// ```swift
/// let query = DatabaseQuery<User>()
///     .where { $0.firstName == "Robert" && $0.events.count >= 5 && $0.updatedAt != nil }
///     .sorted(by: \.createdAt, ascending: false)
///     .limited(to: 20)
/// ```
///
/// A query is a value: building on one returns a new query and leaves the original alone,
/// so shared base queries are safe to hold and extend.
public struct DatabaseQuery<Element: Object>: Sendable {

    /// A type-safe Realm predicate closure.
    public typealias Filter = @Sendable (Query<Element>) -> Query<Bool>

    var filter: Filter?
    var predicateFactory: (@Sendable () -> NSPredicate)?
    var sorts: [Sort<Element>]
    var limit: Int?
    var distinctPaths: [String]

    // MARK: - Initialization

    /// An unfiltered, unsorted query matching every object of the type.
    public init() {
        self.filter = nil
        self.predicateFactory = nil
        self.sorts = []
        self.limit = nil
        self.distinctPaths = []
    }

    /// A query filtered by `filter`.
    public init(_ filter: @escaping Filter) {
        self.init()
        self.filter = filter
    }

    // MARK: - Building

    /// Filters using Realm's type-safe query syntax.
    ///
    /// Calling this more than once replaces the previous filter — combine conditions with
    /// `&&`, `||` and the `!` prefix operator inside a single closure instead. (v1's
    /// `add` silently discarded the earlier predicate here; this at least does so
    /// predictably, and composing in one closure is the intended form.)
    public func `where`(_ filter: @escaping Filter) -> Self {
        var copy = self
        copy.filter = filter
        return copy
    }

    /// Filters using a raw `NSPredicate`.
    ///
    /// The escape hatch for queries the type-safe API cannot express directly —
    /// `SUBQUERY(...).@count`, the `NONE` quantifier, `BETWEEN`, and collection operators
    /// such as `@sum` and `@avg`:
    ///
    /// ```swift
    /// query.filter {
    ///     NSPredicate(format: "SUBQUERY(events, $e, $e.name == %@).@count > 1", "Talk")
    /// }
    /// ```
    ///
    /// Takes a factory rather than an `NSPredicate` because `NSPredicate` is not
    /// `Sendable` and this type is.
    ///
    /// - Important: Realm's query engine rejects some predicate features outright, in
    ///   **both** the type-safe API and here — notably the `ALL` modifier and `MATCHES`
    ///   (regular expressions). RealmStorage 1.x exposed `all(_:)` and `matches(_:)`
    ///   through PredicateFlow, but neither ever worked against a Realm database. Only
    ///   `AND`, `OR` and `NOT` compound predicates are supported.
    ///
    /// - Warning: An unsupported predicate raises an Objective-C exception rather than
    ///   throwing a Swift error, so it cannot be caught with `try`. Cover any raw
    ///   predicate with a test.
    public func filter(_ predicate: @escaping @Sendable () -> NSPredicate) -> Self {
        var copy = self
        copy.predicateFactory = predicate
        return copy
    }

    /// Appends a sort ordering. Orderings apply in the order they were added.
    public func sorted<Value>(by keyPath: KeyPath<Element, Value>, ascending: Bool = true) -> Self {
        var copy = self
        copy.sorts.append(Sort(keyPath, ascending: ascending))
        return copy
    }

    /// Appends sort orderings.
    public func sorted(by sorts: [Sort<Element>]) -> Self {
        var copy = self
        copy.sorts.append(contentsOf: sorts)
        return copy
    }

    /// Keeps only the first `count` results.
    public func limited(to count: Int) -> Self {
        var copy = self
        copy.limit = count
        return copy
    }

    /// Keeps one result per distinct combination of `keyPaths`.
    public func distinct<Value>(by keyPath: KeyPath<Element, Value>) -> Self {
        var copy = self
        copy.distinctPaths.append(_name(for: keyPath))
        return copy
    }
}
