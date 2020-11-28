//
//  CompoundEntityID.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public struct CompoundEntityID: EntityID {
   
    // MARK: - Properties
    
    public let value: String
    
    
    // MARK: - Initialization
    
    public init(
        items: String...,
        separator: String
    ) {
        self.value = items.joined(separator: separator)
    }
}
