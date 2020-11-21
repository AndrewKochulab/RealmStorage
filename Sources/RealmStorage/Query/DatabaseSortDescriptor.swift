//
//  DatabaseSortDescriptor.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public protocol DatabaseSortDescriptor {
    
    // MARK: - Properties
    
    var keyPath: String { get }
    var ascending: Bool { get }
    
}

extension RealmSwift.SortDescriptor: DatabaseSortDescriptor { }
