//
//  RealmDatabaseContext.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public let RealmContext = RealmDatabaseContext()

public final class RealmDatabaseContext {
    
    // MARK: - Properties
    // MARK: Content
    
    private(set) lazy var thread = RealmDatabaseThread().apply {
        $0.workingQueue = { [unowned self] key in
            self.queue.get(by: key)
        }
    }
    
    private(set) lazy var queue = RealmDatabaseQueue()
 
    
    // MARK: - Appearance
    
    public func realm() throws -> Realm {
        try thread.getInstance()
    }
}
