//
//  SafeRealmWriteTransactionContainer.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class SafeRealmWriteTransactionContainer: RealmWriteTransactionContainer {
    
    // MARK: - Appearance
    
    public override func write(
        _ transaction: @escaping (RealmWriteTransaction) throws -> Void
    ) throws {
        let writeTransaction = RealmWriteTransaction(realm: realm)
        let isInWriteTransaction = realm.isInWriteTransaction
        
        do {
            if !isInWriteTransaction {
                realm.refresh()
                realm.beginWrite()
            }
            
            try transaction(writeTransaction)
            
            if !isInWriteTransaction {
                try realm.commitWrite()
            }
        } catch let error {
            realm.cancelWrite()
            
            throw error
        }
    }
}
