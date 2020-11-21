//
//  CountObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class CountObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: QuearyableReadDatabaseOperation<Storage> {
    
    // MARK: - Appearance
    
    public func count() -> Int {
        realmObjects()?.count ?? 0
    }
}
