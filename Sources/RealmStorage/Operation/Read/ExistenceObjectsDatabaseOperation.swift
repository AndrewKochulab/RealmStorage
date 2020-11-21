//
//  ExistenceObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class ExistenceObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    open func hasObjects() -> Bool {
        if let objects = realmObjects() {
            return !objects.isEmpty
        }
        
        return false
    }
}
