//
//  RealmPersistence.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public typealias ReadDatabaseOperationCallback<Operation> = (_ operation: Operation) -> Void
public typealias FailableReadDatabaseOperationCallback<Operation> = DefaultResultCallback<Operation>

public typealias SaveDatabaseOperationCallback<Value> = (Result<Value, Error>) -> Void
public typealias EmptySaveDatabaseOperationCallback = SaveDatabaseOperationCallback<()>

open class RealmPersistence<Storage: StorageSchemaObject> {
    
    // MARK: - Types
    
    public typealias Query = DatabaseQuery<Storage.Schema>
    
    public enum ReadError: LocalizedError {
        case objectWasRemoved
        
        public var errorDescription: String? {
            "Object was removed"
        }
    }
    
    
    // MARK: - Properties
    
    var queue: RealmDatabaseQueue { RealmContext.queue }
    
    
    // MARK: - Initialization
    
    public init() { }
    
    
    // MARK: - Realm
    
    public func realm() throws -> Realm { try RealmContext.realm() }
    
    public func fetchQueue() -> DispatchQueue { queue.fetch }
    public func writeQueue() -> DispatchQueue { queue.write }
    
    public func fetch(operation: @escaping EmptyClosure) {
        fetchQueue().async {
            autoreleasepool(invoking: operation)
        }
    }
    
    public func write(operation: @escaping EmptyClosure) {
        writeQueue().async {
            autoreleasepool(invoking: operation)
        }
    }
    
    // MARK: - Appearance
    // MARK: Fetch
    
    public func all() -> ReadObjectsDatabaseOperation<Storage> {
        ReadObjectsDatabaseOperation()
    }
    
    public func all(
        completion: @escaping ReadDatabaseOperationCallback<ReadObjectsDatabaseOperation<Storage>>
    ) {
        fetch {
            let operation = ReadObjectsDatabaseOperation<Storage>(shouldThreadSafe: true)
            operation.prefetch()
            
            DispatchQueue.main.async {
                completion(operation)
            }
        }
    }
    
    
    public func objects(
        matching query: @escaping (Query) -> Void
    ) -> ReadObjectsDatabaseOperation<Storage> {
        ReadObjectsDatabaseOperation(matching: query)
    }
    
    public func objects(
        matching query: @escaping (DatabaseQuery<Storage.Schema>) -> Void,
        completion: @escaping ReadDatabaseOperationCallback<ReadObjectsDatabaseOperation<Storage>>
    ) {
        fetch {
            let operation = ReadObjectsDatabaseOperation<Storage>(matching: query, shouldThreadSafe: true)
            operation.prefetch()
            
            DispatchQueue.main.async {
                completion(operation)
            }
        }
    }
    
    
    public func object(
        by id: EntityID
    ) -> Storage? {
        ReadUniqueObjectDatabaseOperation<Storage>(id: id).get()
    }
    
    public func object(
        by id: EntityID,
        completion: @escaping (Storage?) -> Void
    ) {
        fetch {
            let object = ReadUniqueObjectDatabaseOperation<Storage>(id: id).get()
            
            DispatchQueue.main.async {
                completion(object)
            }
        }
    }
    
    
    open func first() -> Storage? {
        ReadFirstObjectDatabaseOperation().first()
    }
    
    open func first(
        completion: @escaping (Storage?) -> Void
    ) {
        fetch {
            let object = ReadFirstObjectDatabaseOperation<Storage>(
                shouldThreadSafe: true
            ).first()
            
            DispatchQueue.main.async {
                completion(object)
            }
        }
    }
    
    
    open func last() -> Storage? {
        ReadLastObjectDatabaseOperation().last()
    }
    
    open func last(
        completion: @escaping (Storage?) -> Void
    ) {
        fetch {
            let object = ReadLastObjectDatabaseOperation<Storage>(
                shouldThreadSafe: true
            ).last()
            
            DispatchQueue.main.async {
                completion(object)
            }
        }
    }
    
    
    // MARK: Save
    
    open func save(_ object: Storage) throws {
        let context = try realm()
        
        try SaveObjectDatabaseOperation(
            object: object,
            in: context
        ).execute()
    }
    
    open func save(
        _ object: Storage,
        completion: @escaping EmptySaveDatabaseOperationCallback
    ) {
        write { [weak self] in
            guard let self = self else { return }
            
            do {
                let context = try self.realm()
                
                try SaveObjectDatabaseOperation(
                    object: object,
                    in: context
                ).execute()
                
                DispatchQueue.main.async { completion(.success(())) }
            } catch let error {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    
    open func save(_ objects: [Storage]) throws {
        let context = try self.realm()
        
        try SaveObjectsDatabaseOperation(
            objects: objects,
            in: context
        ).execute()
    }
    
    open func save(
        _ objects: [Storage],
        completion: @escaping EmptySaveDatabaseOperationCallback
    ) {
        write { [weak self] in
            guard let self = self else { return }
            
            do {
                let context = try self.realm()
                
                try SaveObjectsDatabaseOperation(
                    objects: objects,
                    in: context
                ).execute()
                
                DispatchQueue.main.async { completion(.success(())) }
            } catch let error {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    
    // MARK: Update
    
    open func update(
        _ object: Storage,
        using configuration: @escaping (Storage) -> Void
    ) throws {
        let context = try realm()
        
        let operation = try UpdateObjectDatabaseOperation(object: object, in: context)
        operation.configurationClosure = configuration
            
        try operation.execute()
    }
    
    
    // MARK: Delete
    
    open func delete(_ object: Storage) throws {
        let context = try realm()
        
        try DeleteFoundObjectDatabaseOperation(
            object: object,
            in: context
        ).execute()
    }
    
    open func delete(_ objects: [Storage]) throws {
        let context = try realm()
        
        try DeleteFoundObjectsDatabaseOperation(
            objects: objects,
            in: context
        ).execute()
    }
    
    open func delete(by id: EntityID) throws {
        let context = try realm()
        
        try DeleteObjectDatabaseOperation<Storage>(
            by: id,
            in: context
        ).execute()
    }
    
    open func delete(matching query: @escaping (Query) -> Void) throws  {
        let realm = try self.realm()
        
        try DeleteObjectsDatabaseOperation<Storage>(
            matching: query,
            in: realm
        ).execute()
    }
    
    open func deleteAll() throws {
        let realm = try self.realm()
        
        try DeleteObjectsDatabaseOperation<Storage>(in: realm).execute()
    }
}
