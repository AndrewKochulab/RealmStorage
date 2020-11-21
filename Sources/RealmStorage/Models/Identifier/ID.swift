//
//  ID.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public protocol ID: Applyable, CustomStringConvertible {
    
    // MARK: - Properties
    
    var value: String { get }
    
    
    // MARK: - Initialization
    
    init(value: String)
    
}

extension ID {
    
    // MARK: - Properties
    
    public var description: String {
        value.description
    }
    
    
    // MARK: - Appearance
    
    func equal(to id: ID) -> Bool {
        self.value == id.value
    }
}
