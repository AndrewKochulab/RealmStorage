//
//  UpdateObjectDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class UpdateObjectDatabaseOperation<
    Storage: StorageSchemaObject
>: InTransactionWriteDatabaseOperation {
    
    // MARK: - Types
    
    public typealias ConfigurationClosure = (_ object: Storage) -> Void
    
    
    // MARK: - Properties
    // MARK: Content
    
    public let object: Storage
    
    // MARK: Configuration
    
    public var configurationClosure: ConfigurationClosure?
    
    
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
        try container.write { [weak self] _ in
            guard let self = self else { return }
            
            self.configurationClosure?(self.object)
        }
    }
}
