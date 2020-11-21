//
//  ClearDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

open class ClearDatabaseOperation: WriteDatabaseOperation {
    
    // MARK: - Appearance
    
    open override func execute() throws {
        try container.write { transaction in
            transaction.deleteAll()
        }
    }
}
