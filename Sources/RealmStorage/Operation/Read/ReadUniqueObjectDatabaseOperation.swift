//
//  ReadUniqueObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class ReadUniqueObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: ReadDatabaseOperation<Storage> {
    
    // MARK: - Properties
    
    public let id: ID
    
    
    // MARK: - Initialization
    
    public init(id: ID) {
        if Storage.self is IdentifiableStorageObject.Type {
            self.id = id
        } else {
            fatalError("Please conform your class `\(String(describing: Storage.self))` to `IdentifiableStorageObject` protocol")
        }
    }
    
    
    // MARK: - Appearance
    
    public func get() -> Storage? {
        try? realm().object(
            ofType: Storage.self,
            forPrimaryKey: id.value
        )
    }
}
