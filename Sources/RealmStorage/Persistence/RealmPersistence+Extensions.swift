//
//  RealmPersistence+Extensions.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

// MARK: -------
// MARK: Sort

public protocol DatabaseSortableCollection: RandomAccessCollection where Self.Element: RealmCollectionValue {
    
    // MARK: Appearance
    
    func sorted(
        by sortDescriptors: [SortDescriptor]
    ) -> Results<Element>
    
    func sorted<S: Sequence>(
        by sortDescriptors: S
    ) -> Results<Element> where S.Iterator.Element == DatabaseSortDescriptor
    
}

public extension DatabaseSortableCollection where Element: StorageObject {
    
    // MARK: Appearance
    
    func sorted<S: Sequence>(
        by sortDescriptors: S
    ) -> Results<Element> where S.Iterator.Element == DatabaseSortDescriptor {
        let sortDescriptors = sortDescriptors.compactMap { $0 as? SortDescriptor }
        
        return self.sorted(by: sortDescriptors)
    }
}

extension Results: DatabaseSortableCollection where Element: StorageObject { }
extension List: DatabaseSortableCollection where Element: StorageObject { }
extension AnyRealmCollection: DatabaseSortableCollection where Element: StorageObject { }


// MARK: --------
// MARK: Array

public protocol DatabaseArrayCollection: RandomAccessCollection where Self.Element: RealmCollectionValue {
    
    // MARK: Appearance
    
    func toArray() -> [Element]
    
}

extension DatabaseArrayCollection where Element: StorageObject {
    
    // MARK: Appearance
    
    public func toArray() -> [Element] {
        return Array(self)
    }
}

extension Results: DatabaseArrayCollection where Element: StorageObject { }
extension List: DatabaseArrayCollection where Element: StorageObject { }
extension AnyRealmCollection: DatabaseArrayCollection where Element: StorageObject { }

extension LazyFilterCollection where Base: Collection, Base.Element: StorageObject {
    public func toArray() -> [Base.Element] {
        return Array(self)
    }
}
