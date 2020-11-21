//
//  DeleteObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class DeleteObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: InTransactionWriteDatabaseOperation {
    
    // MARK: - Types
    
    public typealias Query = DatabaseQuery<Storage.Schema>
    
    
    // MARK: - Properties
    
    public let query: Query
    
    
    // MARK: - Initialization
    
    public init(
        matching query: ((Query) -> Void)? = nil,
        in context: Realm
    ) {
        let q = Query.init()
        query?(q)
        
        self.query = q
        
        super.init(context: context)
    }
    
    
    // MARK: - Appearance
    
    public override func execute() throws {
        let operation = ReadObjectsDatabaseOperation<Storage>(matching: query)
        
        try container.write { transaction in
            transaction.delete(objects: operation.get())
        }
    }
}
