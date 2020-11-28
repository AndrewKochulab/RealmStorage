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
    
    private(set) lazy var thread = RealmDatabaseThread()
    private(set) lazy var queue = RealmDatabaseQueue()
 
    
    // MARK: - Initialization
    
    init() {
        thread.workingQueue = { [unowned self] key in
            self.queue.get(by: key)
        }
    }
    
    
    // MARK: - Appearance
    
    public func realm() throws -> Realm {
        try thread.getInstance()
    }
}
