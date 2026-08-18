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

    /// Keeps only the indices that fall inside a limited result set.
    private static func visibleIndices(_ indices: [Int], limit: Int?) -> [Int] {
        guard let limit else { return indices }
        return indices.filter { $0 < limit }
    }

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
    /// - Note: With a `limited(to:)` query, the reported indices are those visible within
    ///   the limit, so `results[index]` is always valid. A change beyond the limit still
    ///   produces an update — the results themselves may have shifted — but contributes
    ///   no indices.
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
            let token = QueryPlan.results(query, in: realm).observe { change in
                switch change {
                case .initial(let results):
                    continuation.yield(.initial(StorageResults(results.freeze(), limit: limit)))

                case .update(let results, let deletions, let insertions, let modifications):
                    // Realm reports indices against the full result set. With a limit in
                    // play those can point past the end of what the caller can see, and
                    // `results[index]` would then trap — so indices outside the visible
                    // window are dropped rather than handed over.
                    continuation.yield(
                        .update(
                            StorageResults(results.freeze(), limit: limit),
                            deletions: Self.visibleIndices(deletions, limit: limit),
                            insertions: Self.visibleIndices(insertions, limit: limit),
                            modifications: Self.visibleIndices(modifications, limit: limit)
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

/// A change to a single observed object.
///
/// Payloads are frozen, so they are safe to hand across isolation boundaries.
public enum StorageObjectChange<Element: Object>: @unchecked Sendable {

    /// The object as it stood when observation began.
    case initial(Frozen<Element>)

    /// The object changed. `properties` names the properties that changed.
    case change(Frozen<Element>, properties: [String])

    /// The object was deleted from the database. The stream finishes after this.
    case deleted
}

public extension RealmStore {

    /// An async stream of changes to one object, identified by primary key.
    ///
    /// Emits ``StorageObjectChange/initial(_:)`` immediately, then one
    /// ``StorageObjectChange/change(_:properties:)`` per modification. The stream
    /// finishes after ``StorageObjectChange/deleted``.
    ///
    /// Returns a stream that finishes immediately if no object has that key — observing
    /// something that does not exist is not an error, it simply has nothing to report.
    ///
    /// ```swift
    /// for try await change in await store.changes(of: User.self, id: userID) {
    ///     if case .change(let user, _) = change { render(user) }
    /// }
    /// ```
    func changes<Element: IdentifiableStorage>(
        of type: Element.Type,
        id: Element.ID
    ) -> AsyncThrowingStream<StorageObjectChange<Element>, any Error> where Element: Object {
        AsyncThrowingStream { continuation in
            let realm: Realm

            do {
                realm = try requireRealm()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            guard let object = realm.object(ofType: type, forPrimaryKey: id) else {
                continuation.finish()
                return
            }

            continuation.yield(.initial(Frozen(object)))

            let token = object.observe { change in
                switch change {
                case .change(let object, let properties):
                    guard let object = object as? Element else { return }
                    continuation.yield(
                        .change(Frozen(object), properties: properties.map(\.name))
                    )

                case .deleted:
                    continuation.yield(.deleted)
                    continuation.finish()

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
