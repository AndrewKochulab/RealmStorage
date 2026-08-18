//
//  QueryPlan.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Turns a ``DatabaseQuery`` into `Results`.
///
/// This is the one piece of genuinely shared logic that v1 spread across eighteen
/// `*DatabaseOperation` classes — each of them a single method over an inherited
/// `configuredResults()`. Everything else those classes did (`count()`, `first()`,
/// `last()`, `get()`) is now a method on ``RealmStore``.
enum QueryPlan {

    /// Applies `query` to every object of its type in `realm`.
    static func resolve<Element: Object>(
        _ query: DatabaseQuery<Element>,
        in realm: Realm
    ) -> Results<Element> {
        apply(query, to: realm.objects(Element.self))
    }

    /// Applies `query` within an existing collection, scoping the fetch to a relationship.
    ///
    /// Replaces v1's `ReadObjectObjectsDatabaseOperation`.
    static func resolve<Element: Object, C: RealmCollection>(
        _ query: DatabaseQuery<Element>,
        in collection: C
    ) -> Results<Element> where C.Element == Element {
        apply(query, to: collection.filter(NSPredicate(value: true)))
    }

    // MARK: - Helpers

    private static func apply<Element: Object>(
        _ query: DatabaseQuery<Element>,
        to results: Results<Element>
    ) -> Results<Element> {
        var results = results

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
}
