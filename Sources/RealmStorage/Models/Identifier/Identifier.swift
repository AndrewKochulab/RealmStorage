//
//  Identifier.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public struct Identifier: ID {
    
    // MARK: - Properties
    
    public let value: String
    
    
    // MARK: - Initialization
    
    public init(value: String) {
        self.value = value
    }
}
