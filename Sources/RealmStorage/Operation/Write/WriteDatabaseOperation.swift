//
//  WriteDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class WriteDatabaseOperation {
    
    // MARK: - Properties
    
    public let container: RealmWriteTransactionContainer
    
    
    // MARK: - Initialization
    
    public init(context: Realm) {
        container = RealmWriteTransactionContainer(
            realm: context
        )
    }
    
    
    // MARK: - Appearane
    
    open func execute() throws {
        
    }
}
