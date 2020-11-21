//
//  DeleteFoundObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class DeleteFoundObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: InTransactionWriteDatabaseOperation {
    
    // MARK: - Properties
    
    public let object: Storage
    
    
    // MARK: - Initialization
    
    public init(
        object: Storage,
        in context: Realm
    ) {
        self.object = object
        
        super.init(context: context)
    }
    
    
    // MARK: - Appearance
    
    public override func execute() throws {
        try container.write { transaction in
            transaction.delete(object: self.object)
        }
    }
}
