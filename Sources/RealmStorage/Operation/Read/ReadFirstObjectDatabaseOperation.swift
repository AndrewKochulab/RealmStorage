//
//  ReadFirstObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class ReadFirstObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    public func first() -> Storage? {
        realmObjects()?.first
    }
}

public typealias ReadObjectDatabaseOperation<Storage: StorageSchemaObject> = ReadFirstObjectDatabaseOperation<Storage>
