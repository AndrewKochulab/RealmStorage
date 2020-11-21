//
//  RealmWriteTransactionContainer.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public class RealmWriteTransactionContainer {
    
    // MARK: - Properties
    
    public let realm: Realm
    
    
    // MARK: - Initialization
    
    public init(realm: Realm) {
        self.realm = realm
    }
    
    
    // MARK: - Appearance
    
    open func write(
        _ transaction: @escaping (RealmWriteTransaction) throws -> Void
    ) throws {
        let writeTransaction = RealmWriteTransaction(realm: realm)
        
        realm.refresh()
        
        do {
            realm.beginWrite()
            
            try transaction(writeTransaction)
            
            try realm.commitWrite()
        } catch let error {
            realm.cancelWrite()
            
            throw error
        }
    }
}
