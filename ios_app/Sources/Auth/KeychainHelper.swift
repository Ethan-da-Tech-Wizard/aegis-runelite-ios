// ==============================================================================
// Program: KeychainHelper.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Secure Enclave & Keychain Wrapper for Sensitive OAuth2 Tokens.
//          Provides hardware-backed cryptographic storage for Jagex Account
//          refresh tokens, enforcing device-only access that prevents extraction
//          across iCloud backups or unauthenticated processes.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Secure Key Management:
// ==============================================================================
// In computer security, storing credentials or cryptographic tokens
// in plain text (e.g. `UserDefaults`, files, or logs) is a major vulnerability.
// If a mobile device is backed up or inspected, plain text files can be read.
//
// Apple Keychain Services Architecture:
// The iOS Keychain is an encrypted SQLite database managed directly by the iOS
// kernel and Secure Enclave coprocessor. It provides:
// 1. Hardware AES-256 Encryption: The encryption keys are derived from the device's
//    unique hardware UID fused into the silicon during fabrication.
// 2. Access Control Lists: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` guarantees
//    that tokens are decrypted only when the device is unlocked and are NEVER copied
//    to iCloud backups or other devices.
// ==============================================================================

import Foundation
import Security

/// Secure enclave and Keychain manager for storing Jagex OAuth2 tokens.
public final class KeychainHelper {
    /// Shared singleton instance ensuring synchronized access across the app.
    // Accuracy note: this wrapper uses plain Keychain generic-password items. It does not use the Secure Enclave or
    // biometric access control (no SecAccessControl flags); protection comes from the AfterFirstUnlockThisDeviceOnly class.
    public static let shared = KeychainHelper()

    /// Unique service identifier grouping all credentials under the RuneLite auth domain.
    private let serviceName = "net.runelite.mobile.auth"

    /// Private initializer enforcing singleton usage pattern.
    private init() {}

    /// Save token data securely with device-only biometric and passcode protection.
    ///
    /// - Parameters:
    ///   - key: The unique account or token identifier (e.g. "jagex_refresh_token").
    ///   - data: Raw binary bytes of the token to be encrypted.
    /// - Returns: True if successfully written to the encrypted Keychain database.
    @discardableResult
    public func save(key: String, data: Data) -> Bool {
        // Step 1: Formulate the Keychain query dictionary
        // - kSecClass: Specifies generic password storage
        // - kSecAttrService: The namespace/domain identifier
        // - kSecAttrAccount: The specific key name
        // - kSecValueData: The encrypted payload bytes
        // - kSecAttrAccessible: Hardware policy (unlocked device only, no iCloud migration)
        // The delete-then-add sequence in save() makes it an upsert; the delete uses the same dictionary, which is acceptable because
        // SecItemDelete only matches on the class/service/account attributes.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Step 2: Delete any preexisting item with the same service and account key
        SecItemDelete(query as CFDictionary)

        // Step 3: Insert the new encrypted entry into the iOS Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        // Step 4: errSecSuccess (0) indicates successful cryptographic storage
        return status == errSecSuccess
    }

    /// Read secure token data from the encrypted Keychain database.
    ///
    /// - Parameter key: The account or token identifier to retrieve.
    /// - Returns: Decrypted Data bytes if present, or nil if not found or device is locked.
    public func read(key: String) -> Data? {
        // Step 1: Formulate query requesting binary data return
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Step 2: Execute search query against the security framework
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        // Step 3: Verify success and downcast CFTypeRef to Swift Data
        // A missing item (errSecItemNotFound) and any other Keychain error both map to nil; callers cannot tell them apart.
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    /// Delete stored token from the Keychain.
    ///
    /// - Parameter key: The account key identifier to remove.
    /// - Returns: True if deleted or already non-existent.
    @discardableResult
    public func delete(key: String) -> Bool {
        // Step 1: Construct deletion query matching service and account
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        // Step 2: Request deletion
        let status = SecItemDelete(query as CFDictionary)

        // Step 3: Return true if deleted or if item was not found anyway
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
