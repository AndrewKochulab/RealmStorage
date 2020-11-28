//
//  DatabaseQuery.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public final class DatabaseQueryCompoundPredicate<Schema: GeneratedPredicateSchema> {
    
    // MARK: - Properties
    
    private let builder: PredicateBuilder
    
    
    // MARK: - Initialization
    
    public init(builder: PredicateBuilder) {
        self.builder = builder
    }
    
    
    // MARK: - Appearance
    
    @discardableResult
    public func and(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.and(condition(Schema()))
        
        return self
    }
    
    @discardableResult
    public func andNot(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.andNot(condition(Schema()))
        
        return self
    }
    
    @discardableResult
    public func or(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.or(condition(Schema()))
        
        return self
    }
    
    @discardableResult
    public func orNot(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.orNot(condition(Schema()))
        
        return self
    }
}

public final class DatabaseQuery<Schema: GeneratedPredicateSchema>: DatabaseQueryable {
    
    // MARK: - Properties
    
    private var builder: PredicateBuilder?
    
    public var predicate: NSPredicate? {
        builder?.build()
    }
    
    private(set) public lazy var sortDescriptors = [DatabaseSortDescriptor]()
    
    
    // MARK: - Initialization
    
    public required init() { }
    
    
    // MARK: - Appearance
    
    @discardableResult
    public func add(
        _ condition: (Schema) -> PredicateResult
    ) -> DatabaseQueryCompoundPredicate<Schema> {
        let builder = PredicateBuilder(condition(Schema()))
        self.builder = builder
        
        return DatabaseQueryCompoundPredicate(
            builder: builder
        )
    }
    
    public func sort(
        by sortDescriptors: (Schema) -> [DatabaseSortDescriptor]
    ) {
        self.sortDescriptors.append(contentsOf: sortDescriptors(Schema()))
    }
    
    public func sort(
        by sortDescriptor: (Schema) -> DatabaseSortDescriptor
    ) {
        self.sortDescriptors.append(sortDescriptor(Schema()))
    }
}
