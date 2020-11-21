//
//  RealmDatabaseThread.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

final class RealmDatabaseThread: Applyable {
    
    // MARK: - Types
    
    typealias Key = String
    typealias WorkingQueue = (_ key: Key) -> DispatchQueue?
    
    
    // MARK: - Properties
    // MARK: Content
    
    private lazy var realms = [Key : Realm]()
    
    // MARK: Inputs
    
    var workingQueue: WorkingQueue?
    
    
    // MARK: - Appearance
    
    func getInstance() throws -> Realm {
        let key = try threadKey()
        
        let realm = try self.realm(by: key)
        realm.refresh()
        
        return realm
    }
    
    func realm(by key: Key) throws -> Realm {
        if realms[key] != nil {
            let realm = realms[key]
            
            if realm?.isFrozen == true {
                realms.removeValue(forKey: key)
                return try self.realm(by: key)
            }
            
            return realm!
        }
        
        let realm = try Realm(queue: workingQueue?(key))
        realms[key] = realm
        
        return realm
    }
    
    private func threadKey() throws -> Key {
        let key = __dispatch_queue_get_label(nil)
        
        guard let representableKey = Key(cString: key, encoding: .utf8) else {
            fatalError()
        }
        
        return representableKey
    }
}
