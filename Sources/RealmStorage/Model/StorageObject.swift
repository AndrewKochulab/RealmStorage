//
//  StorageObject.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Marks a Realm model as usable with ``RealmStore``.
///
/// This is a protocol, not a base class. v1 shipped an `open class StorageObject: Object`
/// that declared `@objc private dynamic var _schemaValue`, and Realm forbids mixing
/// `@objc dynamic` and `@Persisted` properties within a class *or any of its ancestors* —
/// so inheriting from it locked every consumer out of `@Persisted` entirely. It also added
/// a real, always-empty column to every table, and permanently excluded `EmbeddedObject`
/// and `AsymmetricObject`.
///
/// ```swift
/// final class User: Object, StorageObject {
///     @Persisted var firstName: String
/// }
/// ```
public protocol StorageObject: ObjectBase, RealmFetchable, RealmCollectionValue {}

/// A ``StorageObject`` with a primary key, enabling lookup and update by identity.
///
/// The key's type is an `associatedtype`, so `UUID` and `ObjectId` keys are first-class.
/// v1 modelled identity as an `EntityID` existential that hard-coded `String`, and looking
/// an object up by id on a type without a primary key was a runtime `fatalError`. Here it
/// is a compile error.
///
/// ```swift
/// final class User: Object, IdentifiableStorage {
///     @Persisted(primaryKey: true) var id: UUID
///     @Persisted var firstName: String
/// }
/// ```
public protocol IdentifiableStorage: StorageObject, Identifiable where ID: StorageID {
    var id: ID { get set }
}
