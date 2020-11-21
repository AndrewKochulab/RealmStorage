//
//  ReadObjectObjectsDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class ReadObjectObjectsDatabaseOperation<
    Storage: StorageSchemaObject
>: ReadObjectsDatabaseOperation<Storage> {
    
    // MARK: - Properties
    
    public let objectList: List<Storage>
    
    
    // MARK: - Initialization
    
    public init(
        objectList: List<Storage>,
        matching query: ((Query) -> Void)? = nil,
        shouldThreadSafe isThreadSafe: Bool = false
    ) {
        self.objectList = objectList
        
        super.init(
            matching: query,
            shouldThreadSafe: isThreadSafe
        )
    }
    
    
    // MARK: - Appearance
    
    override public func configuredResults() throws -> AnyRealmCollection<Storage> {
        if let predicate = query.predicate,
           !query.sortDescriptors.isEmpty {
            return AnyRealmCollection(
                objectList.filter(predicate).sorted(by: query.sortDescriptors)
            )
        }
        
        if let predicate = query.predicate {
            return AnyRealmCollection(
                objectList.filter(predicate)
            )
        }
        
        if !query.sortDescriptors.isEmpty {
            return AnyRealmCollection(
                objectList.sorted(by: query.sortDescriptors)
            )
        }
        
        return AnyRealmCollection(objectList)
    }
}
