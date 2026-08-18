//
//  QueryPlan.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Turns a ``DatabaseQuery`` into results.
///
/// This is the one piece of genuinely shared logic that 1.x spread across eighteen
/// `*DatabaseOperation` classes — each of them a single method over an inherited
/// `configuredResults()`. Everything else those classes did (`count()`, `first()`,
/// `last()`, `get()`) is now a method on ``RealmStore``.
///
/// Every read and write goes through here, which is what keeps `limited(to:)` meaning
/// the same thing everywhere. Realm has no native `LIMIT`, so the cap has to be applied
/// by this type; routing one call site around it silently ignores the limit.
enum QueryPlan {

    /// Filtered and sorted results, **without** the query's limit applied.
    ///
    /// Realm's `Results` is a live view and cannot itself be truncated, so this is the
    /// right input for change observation, which needs the live collection. Anything
    /// that answers a question about "the objects this query selects" must go through
    /// ``elements(_:in:)``, ``count(_:in:)``, ``first(_:in:)`` or ``last(_:in:)``
    /// instead, so the limit is honoured.
    static func results<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> Results<Element> {
        var results = realm.objects(Element.self)

        if let filter = query.filter {
            results = results.where(filter)
        }

        if let predicateFactory = query.predicateFactory {
            results = results.filter(predicateFactory())
        }

        if !query.distinctPaths.isEmpty {
            results = results.distinct(by: query.distinctPaths)
        }

        if !query.sorts.isEmpty {
            results = results.sorted(by: query.sorts.map(\.realmSortDescriptor))
        }

        return results
    }

    /// The objects the query selects, with its limit applied.
    static func elements<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> [Element] {
        let results = results(query, in: realm)

        guard let limit = query.limit else { return Array(results) }
        return Array(results.prefix(limit))
    }

    /// How many objects the query selects, with its limit applied.
    ///
    /// Counted in the database rather than by materialising the results.
    static func count<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> Int {
        let count = results(query, in: realm).count

        guard let limit = query.limit else { return count }
        return Swift.min(limit, count)
    }

    /// The first object the query selects, or `nil`.
    static func first<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> Element? {
        guard count(query, in: realm) > 0 else { return nil }
        return results(query, in: realm).first
    }

    /// The last object the query selects, or `nil`.
    ///
    /// With a limit, this is the last object *within* the limit — not the last row the
    /// filter matches.
    static func last<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> Element? {
        let count = count(query, in: realm)
        guard count > 0 else { return nil }

        return results(query, in: realm)[count - 1]
    }
}
