//
//  Result+Helpers.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation

public extension Result {
    
    // MARK: - Properties
    
    var value: Success? {
        if case .success(let value) = self {
            return value
        }
        
        return nil
    }
    
    var error: Failure? {
        if case .failure(let error) = self {
            return error
        }
        
        return nil
    }
    
    var isSuccess: Bool {
        return value != nil
    }
    
    var isFailure: Bool {
        return error != nil
    }
}

public typealias DefaultResult<Value> = Result<Value, Error>
public typealias EmptyResult = DefaultResult<()>

public typealias DefaultResultCallback<Value> = (_ result: DefaultResult<Value>) -> Void
public typealias EmptyResultCallback = (_ result: EmptyResult) -> Void

public typealias EmptyClosure = () -> Void
