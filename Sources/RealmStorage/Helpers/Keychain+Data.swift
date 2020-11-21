//
//  Keychain+Data.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import KeychainSwift

protocol KeychainData {
    
}

extension String: KeychainData { }
extension Bool: KeychainData { }
extension Data: KeychainData { }

extension KeychainSwift {
    
    // MARK: - Get/Set
    
    func get<T: KeychainData>(
        of key: String,
        type: T.Type = T.self
    ) -> T? {
        if T.self == String.self {
            return get(key) as? T
        }
        
        if T.self == Bool.self {
            return getBool(key) as? T
        }
        
        if T.self == Data.self {
            return getData(key) as? T
        }
        
        return nil
    }
    
    func set<T: KeychainData>(
        value: T,
        for key: String,
        options: KeychainSwiftAccessOptions? = nil
    ) {
        if T.self == String.self {
            set(value as! String, forKey: key, withAccess: options)
        } else if T.self == Bool.self {
            set(value as! Bool, forKey: key, withAccess: options)
        } else if T.self == Data.self {
            set(value as! Data, forKey: key, withAccess: options)
        }
    }
}
