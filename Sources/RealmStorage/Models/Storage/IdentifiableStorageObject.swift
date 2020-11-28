//
//  IdentifiableStorageObject.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

open class IdentifiableStorageObject: StorageObject {
    
    // MARK: - Properties
    
    public var id: EntityID {
        get { EntityIdentifier(value: identifier) }
        set { identifier = newValue.value }
    }
    
    @objc
    private dynamic var identifier = ""
    
    
    // MARK: - Appearance
    
    public override static func primaryKey() -> String? {
        "identifier"
    }
}

public extension IdentifiableStorageObject {
    
    // MARK: - Equatable
    
    static func == (
        lhs: IdentifiableStorageObject,
        rhs: IdentifiableStorageObject
    ) -> Bool {
        lhs.id.equal(to: rhs.id)
    }
}
