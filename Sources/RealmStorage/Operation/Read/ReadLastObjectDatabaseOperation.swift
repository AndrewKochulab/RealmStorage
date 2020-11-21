//
//  ReadLastObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class ReadLastObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    public func last() -> Storage? {
        realmObjects()?.last
    }
}
