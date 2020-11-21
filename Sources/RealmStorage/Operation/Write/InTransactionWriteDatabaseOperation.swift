//
//  InTransactionWriteDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class InTransactionWriteDatabaseOperation: Applyable {
    
    // MARK: - Properties
    
    public let container: SafeRealmWriteTransactionContainer
    
    
    // MARK: - Initialization
    
    public init(context: Realm) {
        container = SafeRealmWriteTransactionContainer(
            realm: context
        )
    }
    
    
    // MARK: - Appearane
    
    open func execute() throws {
        
    }
}
