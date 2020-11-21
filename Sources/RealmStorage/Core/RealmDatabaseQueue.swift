//
//  RealmDatabaseQueue.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

final class RealmDatabaseQueue {
    
    // MARK: - Properties
    
    private(set) public lazy var fetch = DispatchQueue(
        label: "io.realm.Database.fetchQueue",
        qos: .userInitiated
    )
    
    private(set) public lazy var write = DispatchQueue(
        label: "io.realm.Database.writeQueue",
        qos: .userInitiated
    )
    
    private(set) public lazy var queues: [String : DispatchQueue] = [
        DispatchQueue.main.label : .main,
        fetch.label : fetch,
        write.label : write
    ]
    
    
    // MARK: - Appearane
    
    func get(by name: String) -> DispatchQueue? {
        queues[name]
    }
}
