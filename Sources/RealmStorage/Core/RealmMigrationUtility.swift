//
//  RealmMigrationUtility.swift
//  RealmStorage
//
//  Created by Andrew Kochulab on 20.11.2020.
//

import Foundation
import RealmSwift

open class RealmMigrationUtility {
    
    // MARK: - Types
    
    public typealias SchemaVersion = UInt64
    
    enum MigrationError: String, LocalizedError {
        case encryptionKeyGenerationFailed = "Generate database encryption key failed"
        case fileStorageMigrationFailed = "File storage migration failed"
        
        var errorDescription: String? {
            rawValue
        }
    }
    
    
    // MARK: - Properties
    // MARK: Content
    
    public let schemaVersion: SchemaVersion
    public let enableEncryption: Bool
    
    open class var encryptionPrefix: String {
        "io.realm.Database"
    }
    
    open class var encryptionKey: String {
        "encryptionKey"
    }
    
    @Keychain(prefix: encryptionPrefix, key: encryptionKey, defaultValue: nil)
    private var encryptionTokenData: Data?
    
    
    // MARK: - Initialization
    
    public init(
        schemaVersion: SchemaVersion,
        enableEncryption: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.enableEncryption = enableEncryption
    }
    
    
    // MARK: - Appearance
    
    public func initiateMigration() throws {
        
        // Retrieve document directory
        
        guard let storageDirectory = storageDirectoryURL() else {
            throw MigrationError.fileStorageMigrationFailed
        }
        
        
        // Check encryption enabled
        
        guard enableEncryption else {
            
            // Create configuration for non-encrypted Realm database
            
            configureRealm(
                storageURL: unencryptedStorageURL(in: storageDirectory),
                schemaVersion: schemaVersion,
                migrationContext: migrationContext()
            )
            
            return
        }
        
        
        // Create or fetch from Keychain encrypted key
        
        guard let encryptedKeyData = fetchOrCreateEncryptionKeyData() else {
            throw MigrationError.encryptionKeyGenerationFailed
        }
        
        
        // Migrate realm storage from unencrypted version if needed
        
        try migrateFileStorageIfNeeded(
            in: storageDirectory,
            using: encryptedKeyData
        )
        
        
        // Create base configuration for Realm database
        
        configureRealm(
            storageURL: encryptedStorageURL(in: storageDirectory),
            encryptedKeyData: encryptedKeyData,
            schemaVersion: schemaVersion,
            migrationContext: migrationContext()
        )
    }
    
    open func configureRealm(
        storageURL: URL,
        encryptedKeyData: Data? = nil,
        schemaVersion: SchemaVersion,
        migrationContext: @escaping MigrationBlock
    ) {
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            fileURL: storageURL,
            encryptionKey: encryptedKeyData,
            schemaVersion: schemaVersion,
            migrationBlock: migrationContext
        )
    }
    
    open func fetchOrCreateEncryptionKeyData() -> Data? {
        if let data = encryptionTokenData {
            return data
        }
        
        let keyData = generatedKeyData()
        self.encryptionTokenData = keyData
        
        return keyData
    }
    
    open func migrateFileStorageIfNeeded(
        in documentDirectory: URL,
        using encryptedKeyData: Data
    ) throws {
        let unencryptedRealmURL = unencryptedStorageURL(in: documentDirectory)
        let encryptedRealmURL = encryptedStorageURL(in: documentDirectory)
        
        let fileManager = FileManager.default
        let isUnencryptedRealmExist = fileManager.fileExists(atPath: unencryptedRealmURL.path)
        let isEncryptedRealmExist = fileManager.fileExists(atPath: encryptedRealmURL.path)
        
        if isUnencryptedRealmExist && !isEncryptedRealmExist {
            let unencryptedRealm = try Realm(
                configuration: .init(
                    schemaVersion: schemaVersion,
                    migrationBlock: migrationContext()
                )
            )
            
            try unencryptedRealm.writeCopy(
                toFile: encryptedRealmURL,
                encryptionKey: encryptedKeyData
            )
        }
        
        if isUnencryptedRealmExist {
            let realmURL = unencryptedRealmURL
            let urls = [
                realmURL,
                realmURL.appendingPathExtension("lock"),
                realmURL.appendingPathExtension("note"),
                realmURL.appendingPathExtension("management")
            ]
            
            for url in urls {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }
        }
    }
    
    open func storageDirectoryURL() -> URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
    }
    
    open func encryptedStorageName() -> String {
        "default_encrypted"
    }
    
    open func encryptedStorageURL(in documentDirectory: URL) -> URL {
        documentDirectory
            .appendingPathComponent(encryptedStorageName())
            .appendingPathExtension("realm")
    }
    
    open func unencryptedStorageURL(in documentDirectory: URL) -> URL {
        documentDirectory
            .appendingPathComponent("default")
            .appendingPathExtension("realm")
    }
    
    open func migrationContext() -> MigrationBlock {
        return { migration, oldSchemaVersion in
           
        }
    }
    
    private func generatedKeyData() -> Data {
        var keyData: Data
        let firstGenerationAttempt = generateKeyData(count: 64)
        
        if firstGenerationAttempt.success {
            keyData = firstGenerationAttempt.randomBytes
        } else {
            let secondGenerationAttempt = generateKeyData(count: 32)
            keyData = secondGenerationAttempt.randomBytes
        }
        
        return keyData
    }
    
    private func generateKeyData(count: Int) -> (success: Bool, randomBytes: Data) {
        var keyData = Data(count: count)
        
        let result = keyData.withUnsafeMutableBytes { pointer -> OSStatus in
            if let baseAddress = pointer.baseAddress {
                return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
            }
            
            return errSecUnimplemented
        }
        
        return (success: result == errSecSuccess, randomBytes: keyData)
    }
}
