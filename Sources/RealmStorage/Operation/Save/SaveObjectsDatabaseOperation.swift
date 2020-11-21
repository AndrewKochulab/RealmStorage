//
//  SaveObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class SaveObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: InTransactionWriteDatabaseOperation {
    
    // MARK: - Properties
    
    public let objects: [Storage]
    
    
    // MARK: - Initialization
    
    public init(
        objects: [Storage],
        in context: Realm
    ) {
        self.objects = objects
        
        super.init(context: context)
    }
    
    
    // MARK: - Appearance
    
    open override func execute() throws {
        try container.write { transaction in
            transaction.add(objects: self.objects, update: true)
        }
    }
}
