//
//  RealmWriteTransaction.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class RealmWriteTransaction {
    
    // MARK: - Properties
    
    private let realm: Realm
    
    
    // MARK: - Initialization
    
    init(realm: Realm) {
        self.realm = realm
    }
    
    
    // MARK: - Appearance
    // MARK: Add
    
    public func add(object: StorageObject, update: Bool) {
        realm.add(object, update: updatePolicy(from: update))
    }
    
    public func add(objects: [StorageObject], update: Bool) {
        realm.add(objects, update: updatePolicy(from: update))
    }
    
    // MARK: Delete
    
    public func delete(object: StorageObject) {
        realm.delete(object)
    }
    
    public func delete(objects: [StorageObject]) {
        realm.delete(objects)
    }
    
    public func deleteAll() {
        realm.deleteAll()
    }
    
    // MARK: Helpers
    
    private func updatePolicy(from update: Bool) -> Realm.UpdatePolicy {
        update ? .modified : .all
    }
}
