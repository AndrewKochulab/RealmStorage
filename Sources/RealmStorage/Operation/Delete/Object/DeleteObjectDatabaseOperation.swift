//
//  DeleteObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class DeleteObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: InTransactionWriteDatabaseOperation {
    
    // MARK: - Properties
    
    public let id: EntityID
    
    
    // MARK: - Initialization
    
    public init(
        by id: EntityID,
        in context: Realm
    ) {
        self.id = id
        
        super.init(context: context)
    }
    
    
    // MARK: - Appearance
    
    public override func execute() throws {
        let operation = ReadUniqueObjectDatabaseOperation<Storage>(id: id)
        
        guard let object = operation.get() else {
            return
        }
        
        try container.write { transaction in
            transaction.delete(object: object)
        }
    }
}
