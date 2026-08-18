//
//  StorageResults.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A lazy, frozen, `Sendable` view over query results.
///
/// Live Realm objects are thread-confined and genuinely cannot cross an actor boundary —
/// under Swift 6 the compiler rejects it. Freezing makes them immutable and safe to read
/// anywhere, which is what lets ``RealmStore`` return results at all.
///
/// The wrapper stays lazy on purpose. v1's `toArray()` inflated every result set eagerly,
/// throwing away the laziness that is most of the reason to use Realm. Indexing here
/// still reads through to the underlying `Results`; use ``array()`` when you actually
/// want everything materialised.
///
/// `@unchecked Sendable` is sound here because of a single invariant, enforced in the
/// initializer: the wrapped `Results` is always frozen. Note that this is a conformance
/// on *our* type — declaring one on Realm's `Object` would also claim live objects are
/// safe to share, which they are not.
public struct StorageResults<Element: Object>: RandomAccessCollection, @unchecked Sendable {

    private let frozen: Results<Element>
    private let limit: Int?

    init(_ results: Results<Element>, limit: Int? = nil) {
        self.frozen = results.isFrozen ? results : results.freeze()
        self.limit = limit
    }

    // MARK: - RandomAccessCollection

    public var startIndex: Int { 0 }

    public var endIndex: Int {
        guard let limit else { return frozen.count }
        return Swift.min(limit, frozen.count)
    }

    public subscript(position: Int) -> Element {
        precondition(position >= startIndex && position < endIndex, "Index out of range")
        return frozen[position]
    }

    // MARK: - Access

    /// Materialises every element into an array.
    public func array() -> [Element] {
        Array(self)
    }

    /// A live, mutable view of these results on the current thread or actor.
    ///
    /// Returns `nil` when the source Realm is no longer available.
    public func thawed() -> Results<Element>? {
        frozen.thaw()
    }

    /// Whether the results are empty.
    public var isEmpty: Bool { endIndex == 0 }
}

/// A single frozen object, safe to carry across isolation boundaries.
///
/// The single-object counterpart to ``StorageResults``, and it exists for the same
/// reason: a Realm `Object` is not `Sendable` even once frozen, so returning one straight
/// out of ``RealmStore`` is rejected — correctly — by the compiler. `sending` does not
/// help either, because the value is derived from actor-isolated state rather than built
/// in a disconnected region.
///
/// `@unchecked Sendable` rests on one invariant, enforced in the initializer: the wrapped
/// object is always frozen, and therefore immutable.
///
/// Dynamic member lookup keeps this out of the way at the call site:
///
/// ```swift
/// let user = try await store.object(User.self, id: "user-1")
/// print(user?.firstName)     // reads through to the frozen object
/// print(user?.object)        // the object itself, when you need it
/// ```
@dynamicMemberLookup
public struct Frozen<Element: Object>: @unchecked Sendable {

    /// The frozen object.
    public let object: Element

    init(_ object: Element) {
        self.object = object.isFrozen ? object : object.freeze()
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Element, Value>) -> Value {
        object[keyPath: keyPath]
    }

    /// A live, mutable view of this object on the current thread or actor.
    ///
    /// Returns `nil` when the object has been deleted or its Realm is gone.
    public func thawed() -> Element? {
        object.thaw()
    }
}
