//
//  ReadObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class ReadObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    open func get() -> [Storage] {
        realmObjects()?.toArray() ?? []
    }
}
