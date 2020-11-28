//
//  StorageObject.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift
import Realm

public protocol StorageSchemaProvidable: class {
    associatedtype Schema: GeneratedPredicateSchema
}

public typealias StorageSchemaObject = StorageObject & StorageSchemaProvidable

open class StorageObject: Object {
    public required override init() {
        super.init()
    }
}
