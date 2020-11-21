//
//  DatabaseQueryable.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import PredicateFlow

public protocol DatabaseQueryable: class {
    
    // MARK: - Types
    
    associatedtype Schema: GeneratedPredicateSchema
    
    
    // MARK: - Properties
    
    var predicate: NSPredicate? { get }
    var sortDescriptors: [DatabaseSortDescriptor] { get }
    
    
    // MARK: - Appearance
    
    @discardableResult
    func add(
        _ condition: (Schema) -> PredicateResult
    ) -> DatabaseQueryCompoundPredicate<Schema>
    
    func sort(
        by sortDescriptors: (Schema) -> [DatabaseSortDescriptor]
    )
    
    func sort(
        by sortDescriptor: (Schema) -> DatabaseSortDescriptor
    )
}
