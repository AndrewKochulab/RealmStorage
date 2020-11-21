//
//  Keychain.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import KeychainSwift

@propertyWrapper
struct Keychain<T: KeychainData> {
    
    // MARK: - Properties
    
    let prefix: String?
    let key: String
    let defaultValue: T?
    let options: KeychainSwiftAccessOptions? = nil
    
    var wrappedValue: T? {
        get { container().get(of: key, type: T.self) ?? defaultValue }
        set {
            if let newValue = newValue {
                container().set(value: newValue, for: key, options: options)
            } else {
                container().delete(key)
            }
        }
    }
    
    
    // MARK: - Helpers
    
    private func container() -> KeychainSwift {
        if let prefix = prefix {
            return KeychainSwift(keyPrefix: prefix)
        }
        
        return KeychainSwift()
    }
}
