//
//  ReadDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class ReadDatabaseOperation<
    Storage: StorageSchemaObject
> {
    
    // MARK: - Appearance
    
    public func realm() throws -> Realm {
        try RealmContext.realm()
    }
}
