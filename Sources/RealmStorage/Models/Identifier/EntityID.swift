//
//  EntityID.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public protocol EntityID: CustomStringConvertible {
    
    // MARK: - Properties
    
    var value: String { get }
    
}

public extension EntityID {
    
    // MARK: - Properties
    
    var description: String {
        value.description
    }
    
    
    // MARK: - Appearance
    
    func equal(to id: EntityID) -> Bool {
        self.value == id.value
    }
}
