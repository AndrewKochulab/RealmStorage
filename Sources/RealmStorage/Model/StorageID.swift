//
//  StorageID.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// A type usable as a Realm primary key.
///
/// Conformance is closed to the types Realm actually accepts, so an unsupported key type
/// fails to compile rather than throwing at schema-creation time.
public protocol StorageID: Hashable, Sendable, _Persistable {}

extension String: StorageID {}
extension Int: StorageID {}
extension Int8: StorageID {}
extension Int16: StorageID {}
extension Int32: StorageID {}
extension Int64: StorageID {}
extension UUID: StorageID {}
extension ObjectId: StorageID {}
