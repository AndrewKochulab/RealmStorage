//
//  CompoundID.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public protocol CompoundID: ID {
    
    // MARK: - Appearance
    
    static func from(
        items: String...,
        separator: String
    ) -> Self
    
}

public extension CompoundID {
    
    // MARK: - Appearance
    
    static func from(
        items: String...,
        separator: String = "_"
    ) -> Self {
        self.init(value: items.joined(separator: separator))
    }
}
