//
//  RealmStore+Observe.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A change to a set of query results.
///
/// Payloads are frozen, so they are safe to hand across isolation boundaries.
public enum StorageChange<Element: Object>: @unchecked Sendable {

    /// The initial contents, delivered once when observation starts.
    case initial(StorageResults<Element>)

    /// A subsequent change, with indices relative to the previous delivery.
    case update(
        StorageResults<Element>,
        deletions: [Int],
        insertions: [Int],
        modifications: [Int]
    )

    /// The results as of this change.
    public var results: StorageResults<Element> {
        switch self {
        case .initial(let results):
            return results
        case .update(let results, _, _, _):
            return results
        }
    }
}

public extension RealmStore {

    /// An async stream of changes to the objects matching `query`.
    ///
    /// Realm's whole value for UI is live change notifications, so dropping to
    /// request/response reads would have been a real regression. This keeps observation
    /// while staying within async/await — no completion handlers.
    ///
    /// The stream yields ``StorageChange/initial(_:)`` once, then an
    /// ``StorageChange/update(_:deletions:insertions:modifications:)`` per change. Ending
    /// iteration (or cancelling the task) invalidates the underlying notification token.
    ///
    /// ```swift
    /// for try await change in await store.changes(of: User.self) {
    ///     render(change.results)
    /// }
    /// ```
    func changes<Element: Object>(
        of type: Element.Type,
        matching query: DatabaseQuery<Element> = .init()
    ) -> AsyncThrowingStream<StorageChange<Element>, any Error> {
        AsyncThrowingStream { continuation in
            let realm: Realm

            do {
                realm = try requireRealm()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let limit = query.limit
            let token = QueryPlan.resolve(query, in: realm).observe { change in
                switch change {
                case .initial(let results):
                    continuation.yield(.initial(StorageResults(results.freeze(), limit: limit)))

                case .update(let results, let deletions, let insertions, let modifications):
                    continuation.yield(
                        .update(
                            StorageResults(results.freeze(), limit: limit),
                            deletions: deletions,
                            insertions: insertions,
                            modifications: modifications
                        )
                    )

                case .error(let error):
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                token.invalidate()
            }
        }
    }
}
