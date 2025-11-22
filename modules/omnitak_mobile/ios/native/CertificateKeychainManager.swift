//
//  CertificateKeychainManager.swift
//  OmniTAK Mobile - Certificate Keychain Storage
//
//  Secure storage for TAK client certificates using iOS Keychain
//

import Foundation
import Security

/// Manager for secure certificate storage in iOS Keychain
class CertificateKeychainManager {

    // Keychain service identifier
    private let service = "com.engindearing.omnitak.certificates"

    // Keychain access group (for app group sharing if needed)
    private let accessGroup: String?

    init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    // MARK: - Certificate Bundle Storage

    struct CertificateBundle: Codable {
        let certPem: String
        let keyPem: String
        let caPem: String?
        let commonName: String
        let issuer: String
        let validFrom: String
        let validUntil: String
        let serverInfo: ServerInfo?

        struct ServerInfo: Codable {
            let hostname: String
            let port: Int?
        }
    }

    // MARK: - Save Certificate

    /// Save a certificate bundle to Keychain
    /// - Parameters:
    ///   - bundle: Certificate bundle to save
    ///   - certificateId: Unique identifier for this certificate
    /// - Returns: True if saved successfully
    func saveCertificate(_ bundle: CertificateBundle, withId certificateId: String) -> Bool {
        do {
            // Encode bundle to JSON
            let encoder = JSONEncoder()
            let data = try encoder.encode(bundle)

            // Delete existing item if present
            _ = deleteCertificate(withId: certificateId)

            // Create keychain query
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: certificateId,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            // Add to keychain
            let status = SecItemAdd(query as CFDictionary, nil)

            if status == errSecSuccess {
                print("[Keychain] Certificate saved: \(certificateId)")
                return true
            } else {
                print("[Keychain] Failed to save certificate: \(status)")
                return false
            }
        } catch {
            print("[Keychain] Encoding error: \(error)")
            return false
        }
    }

    // MARK: - Load Certificate

    /// Load a certificate bundle from Keychain
    /// - Parameter certificateId: Unique identifier for the certificate
    /// - Returns: Certificate bundle if found, nil otherwise
    func loadCertificate(withId certificateId: String) -> CertificateBundle? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: certificateId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            do {
                let decoder = JSONDecoder()
                let bundle = try decoder.decode(CertificateBundle.self, from: data)
                return bundle
            } catch {
                print("[Keychain] Decoding error: \(error)")
                return nil
            }
        } else if status == errSecItemNotFound {
            return nil
        } else {
            print("[Keychain] Failed to load certificate: \(status)")
            return nil
        }
    }

    // MARK: - List All Certificates

    /// List all certificate IDs stored in Keychain
    /// - Returns: Array of certificate IDs
    func listCertificateIds() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            return items.compactMap { item in
                item[kSecAttrAccount as String] as? String
            }
        } else if status == errSecItemNotFound {
            return []
        } else {
            print("[Keychain] Failed to list certificates: \(status)")
            return []
        }
    }

    /// Load all certificates from Keychain
    /// - Returns: Dictionary of certificate ID to bundle
    func loadAllCertificates() -> [String: CertificateBundle] {
        let certIds = listCertificateIds()
        var certificates: [String: CertificateBundle] = [:]

        for certId in certIds {
            if let bundle = loadCertificate(withId: certId) {
                certificates[certId] = bundle
            }
        }

        return certificates
    }

    // MARK: - Delete Certificate

    /// Delete a certificate from Keychain
    /// - Parameter certificateId: Unique identifier for the certificate
    /// - Returns: True if deleted successfully
    func deleteCertificate(withId certificateId: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: certificateId
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] Certificate deleted: \(certificateId)")
            return true
        } else {
            print("[Keychain] Failed to delete certificate: \(status)")
            return false
        }
    }

    // MARK: - Delete All Certificates

    /// Delete all certificates from Keychain
    /// - Returns: True if all deleted successfully
    func deleteAllCertificates() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] All certificates deleted")
            return true
        } else {
            print("[Keychain] Failed to delete all certificates: \(status)")
            return false
        }
    }

    // MARK: - Update Certificate

    /// Update an existing certificate in Keychain
    /// - Parameters:
    ///   - bundle: New certificate bundle
    ///   - certificateId: Unique identifier for the certificate
    /// - Returns: True if updated successfully
    func updateCertificate(_ bundle: CertificateBundle, withId certificateId: String) -> Bool {
        // For Keychain, update = delete + add
        return saveCertificate(bundle, withId: certificateId)
    }

    // MARK: - Migration Helper

    /// Migrate in-memory certificates to Keychain
    /// - Parameter certificates: Dictionary of certificate ID to bundle
    /// - Returns: Number of certificates successfully migrated
    func migrateCertificates(_ certificates: [String: CertificateBundle]) -> Int {
        var migratedCount = 0

        for (certId, bundle) in certificates {
            if saveCertificate(bundle, withId: certId) {
                migratedCount += 1
            }
        }

        print("[Keychain] Migrated \(migratedCount) of \(certificates.count) certificates")
        return migratedCount
    }
}

// MARK: - Keychain Error Extension

extension CertificateKeychainManager {
    /// Get human-readable error message for OSStatus
    func errorMessage(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        default:
            return "Error code: \(status)"
        }
    }
}
