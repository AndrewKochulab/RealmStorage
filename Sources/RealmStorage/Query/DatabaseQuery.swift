//
//  DatabaseQuery.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import PredicateFlow

public final class DatabaseQueryCompoundPredicate<Schema: GeneratedPredicateSchema> {
    
    // MARK: - Properties
    
    private let builder: PredicateBuilder
    private let schema: Schema
    
    
    // MARK: - Initialization
    
    public init(
        builder: PredicateBuilder,
        schema: Schema
    ) {
        self.builder = builder
        self.schema = schema
    }
    
    
    // MARK: - Appearance
    
    @discardableResult
    public func and(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.and(condition(schema))
        
        return self
    }
    
    @discardableResult
    public func andNot(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.andNot(condition(schema))
        
        return self
    }
    
    @discardableResult
    public func or(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.or(condition(schema))
        
        return self
    }
    
    @discardableResult
    public func orNot(_ condition: (Schema) -> PredicateResult) -> Self {
        builder.orNot(condition(schema))
        
        return self
    }
}

public final class DatabaseQuery<Schema: GeneratedPredicateSchema>: DatabaseQueryable {
    
    // MARK: - Properties
    
    private var builder: PredicateBuilder?
    
    public var predicate: NSPredicate? {
        builder?.build()
    }
    
    private lazy var schema = Schema()
    private(set) public lazy var sortDescriptors = [DatabaseSortDescriptor]()
    
    
    // MARK: - Initialization
    
    public required init() { }
    
    
    // MARK: - Appearance
    
    @discardableResult
    public func add(
        _ condition: (Schema) -> PredicateResult
    ) -> DatabaseQueryCompoundPredicate<Schema> {
        let builder = PredicateBuilder(condition(schema))
        self.builder = builder
        
        return DatabaseQueryCompoundPredicate(
            builder: builder,
            schema: schema
        )
    }
    
    public func sort(
        by sortDescriptors: (Schema) -> [DatabaseSortDescriptor]
    ) {
        self.sortDescriptors.append(contentsOf: sortDescriptors(schema))
    }
    
    public func sort(
        by sortDescriptor: (Schema) -> DatabaseSortDescriptor
    ) {
        self.sortDescriptors.append(sortDescriptor(schema))
    }
}
