//
//  ClearDatabaseOperation.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public final class ClearDatabaseOperation: WriteDatabaseOperation {
    
    // MARK: - Appearance
    
    public override func execute() throws {
        try container.write { transaction in
            transaction.deleteAll()
        }
    }
}
