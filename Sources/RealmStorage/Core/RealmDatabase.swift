//
//  RealmDatabase.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

public final class RealmDatabase {
 
    // MARK: - Types
    
    public typealias MigrationUtilityContext = () -> RealmMigrationUtility
    
    public enum DatabaseError: String, LocalizedError {
        case initiateModuleFailed = "Initiate Realm Database module failed"
        
        public var errorDescription: String? {
            rawValue
        }
    }
    
    
    // MARK: - Properties
    // MARK: Content
    
    private lazy var dbContext = RealmContext
    private var thread: RealmDatabaseThread { dbContext.thread }
    private var queue: RealmDatabaseQueue { dbContext.queue}
    
    // MARK: Inputs
    
    public var migrationUtilityContext: MigrationUtilityContext = {
        RealmMigrationUtility(
            schemaVersion: 1,
            enableEncryption: false
        )
    }
    
    
    // MARK: - Initialization
    
    public init() { }
    
    
    // MARK: - Configuration
    
    public func initiateModule() throws {
        do {
            try initiateMigration()
            try performInitialConfiguration()
        } catch _ {
            flushCorruptedDatabase()
            
            throw DatabaseError.initiateModuleFailed
        }
    }
    
    private func initiateMigration() throws {
        try migrationUtilityContext()
            .initiateMigration()
    }
    
    private func performInitialConfiguration() throws {
        let realm = try self.realm()
        
        guard let rootFolderPath = realm
                .configuration
                .fileURL?
                .deletingLastPathComponent()
                .path else { return }
        
        let fileManager = FileManager.default
        
        try fileManager.setAttributes([
            .protectionKey : FileProtectionType.none
        ], ofItemAtPath: rootFolderPath)
    }
    
    public func clearDatabase() throws {
        let realm = try self.realm()

        try ClearDatabaseOperation(context: realm)
            .execute()
    }
    
    private func flushCorruptedDatabase() {
        guard let url = Realm.Configuration.defaultConfiguration.fileURL else {
            return
        }
        
        try? FileManager.default.removeItem(at: url)
    }
    
    private func realm() throws -> Realm {
        try thread.getInstance()
    }
}
