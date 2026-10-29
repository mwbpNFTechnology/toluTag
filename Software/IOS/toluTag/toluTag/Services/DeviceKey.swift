//
//  DeviceKey.swift
//  toluTag
//
//  This iPhone's own P-256 key, made in and kept by the Secure Enclave. A
//  tag holds its public half as an ECKey authentication object, and a
//  wallet key on that tag may only be used inside a session this key opens
//  — by signing, which needs Face ID or the passcode. Nothing secret ever
//  crosses NFC: the session is authenticated by a signature and encrypted
//  with keys from a fresh key agreement.
//
//  The private half never leaves the Secure Enclave and is in no backup.
//  The Keychain only holds the enclave's wrapped handle to it, which is
//  useless on any other device.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum DeviceKey {
    private static let service = "io.mwbp.toluTag.deviceKey"
    private static let account = "p256.signing"

    /// `04 ‖ X ‖ Y`. Makes the key the first time it is asked for; reading
    /// the public half needs no Face ID.
    static func publicKey() throws -> [UInt8] {
        Array(try privateKey(context: nil).publicKey.x963Representation)
    }

    /// Asks for Face ID (or the passcode), then hands back a signer that
    /// can sign without asking again — so the prompt comes before the NFC
    /// sheet opens, never on top of it.
    static func unlock(reason: String) async throws -> DeviceKeySigner {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            throw DeviceKeyError.authenticationUnavailable
        }
        _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        return DeviceKeySigner(key: try privateKey(context: context))
    }

    private static func privateKey(context: LAContext?) throws -> SecureEnclave.P256.Signing.PrivateKey {
        guard SecureEnclave.isAvailable else { throw DeviceKeyError.noSecureEnclave }
        if let handle = try storedHandle() {
            return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: handle, authenticationContext: context)
        }
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .userPresence], nil
        ) else {
            throw DeviceKeyError.authenticationUnavailable
        }
        let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access, authenticationContext: context)
        try store(key.dataRepresentation)
        return key
    }

    // MARK: - Keychain

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func storedHandle() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw DeviceKeyError.keychain(status) }
        return data
    }

    private static func store(_ handle: Data) throws {
        var query = baseQuery
        query[kSecValueData as String] = handle
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw DeviceKeyError.keychain(status) }
    }
}
