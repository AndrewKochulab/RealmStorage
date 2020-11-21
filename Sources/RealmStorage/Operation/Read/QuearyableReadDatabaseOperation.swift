//
//  QuearyableReadDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class QuearyableReadDatabaseOperation<
    Storage: StorageSchemaObject
>: ReadDatabaseOperation<Storage> {
    
    // MARK: - Types
    
    public typealias Query = DatabaseQuery<Storage.Schema>
    
    
    // MARK: - Properties
    
    public let query: Query
    public let isThreadSafe: Bool
    
    public var results: AnyRealmCollection<Storage>? {
        get {
            if isThreadSafe,
               let threadSafeReference = threadSafeReference {
                if threadSafeReference.isInvalidated {
                    return _resolvedResults
                }
                
                let results = try? realm().resolve(threadSafeReference)
                self._resolvedResults = results
                
                return results
            }
            
            return _results
        }
        set {
            self._results = newValue
        }
    }
    
    private var threadSafeReference: ThreadSafeReference<AnyRealmCollection<Storage>>?
    private var _results: AnyRealmCollection<Storage>?
    private var _resolvedResults: AnyRealmCollection<Storage>?
    
    
    // MARK: - Initialization
    
    public init(
        matching query: ((Query) -> Void)? = nil,
        shouldThreadSafe isThreadSafe: Bool = false
    ) {
        let q = Query.init()
        query?(q)
        
        self.query = q
        self.isThreadSafe = isThreadSafe
    }
    
    public init(
        matching query: Query,
        shouldThreadSafe isThreadSafe: Bool = false
    ) {
        self.query = query
        self.isThreadSafe = isThreadSafe
    }
    
    
    // MARK: - Appearance
    
    public func prefetch() {
        if results == nil {
            setupResultsIfExists(try? configuredResults())
        }
    }
    
    public func realmObjects() -> AnyRealmCollection<Storage>? {
        if let results = results {
            return results
        }
        
        let results = try? configuredResults()
        setupResultsIfExists(results)
        
        return results
    }
    
    public func configuredResults() throws -> AnyRealmCollection<Storage> {
        var results = try realm().objects(Storage.self)
        
        if let predicate = query.predicate {
            results = results.filter(predicate)
        }
        
        if !query.sortDescriptors.isEmpty {
            results = results.sorted(by: query.sortDescriptors)
        }
        
        return AnyRealmCollection(results)
    }
    
    private func setupResultsIfExists(
        _ results: AnyRealmCollection<Storage>?
    ) {
        if let results = results {
            setupResults(results)
        }
    }
    
    private func setupResults(
        _ results: AnyRealmCollection<Storage>
    ) {
        self.results = results
        
        if isThreadSafe {
            self.threadSafeReference = ThreadSafeReference(to: results)
        }
    }
}
