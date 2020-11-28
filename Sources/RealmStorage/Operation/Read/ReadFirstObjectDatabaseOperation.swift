//
//  ReadFirstObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class ReadFirstObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    open func first() -> Storage? {
        realmObjects()?.first
    }
}

open class ReadObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: ReadFirstObjectDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    open func get() -> Storage? {
        first()
    }
}
