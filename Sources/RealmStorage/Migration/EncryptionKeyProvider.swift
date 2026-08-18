//
//  EncryptionKeyProvider.swift
//  RealmStorage
//

import Foundation
import Security

/// Supplies the 64-byte key Realm uses to encrypt a database file.
struct EncryptionKeyProvider: Sendable {

    /// Realm requires an encryption key of exactly this many bytes.
    static let requiredKeyLength = 64

    let store: any SecretStore
    let account: String

    /// Returns the stored key, generating and persisting one on first use.
    ///
    /// v1 asked for 64 random bytes and, if that failed, silently fell back to 32 —
    /// producing a key Realm rejects at open time, which then reached a blanket `catch`
    /// that deleted the database. Failure throws here instead.
    func key() throws -> Data {
        if let existing = try store.data(forKey: account) {
            guard existing.count == Self.requiredKeyLength else {
                throw StorageError.encryptionKeyInvalidLength(
                    expected: Self.requiredKeyLength,
                    actual: existing.count
                )
            }

            return existing
        }

        let generated = try Self.generateKey()
        try store.set(generated, forKey: account)

        return generated
    }

    /// 64 cryptographically random bytes, or a throw.
    static func generateKey() throws -> Data {
        var key = Data(count: requiredKeyLength)

        let status = key.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }

            return SecRandomCopyBytes(kSecRandomDefault, requiredKeyLength, baseAddress)
        }

        guard status == errSecSuccess else {
            throw StorageError.encryptionKeyGenerationFailed(status: status)
        }

        return key
    }
}
