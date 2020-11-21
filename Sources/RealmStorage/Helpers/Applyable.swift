//
//  Applyable.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public protocol Applyable { }

public extension Applyable {
    
    // MARK: - Appearance
    
    @inline(__always)
    @discardableResult
    func apply(_ configuration: (Self) throws -> Void) rethrows -> Self {
        try configuration(self)
        
        return self
    }
}

extension NSObject: Applyable { }
