//
//  DeviceKeySigner.swift
//  toluTag
//
//  The iPhone's Secure Enclave key after Face ID: signs without asking
//  again for as long as it is kept, so keep it only for one tap.
//

import CryptoKit
import Foundation

struct DeviceKeySigner {
    private let key: SecureEnclave.P256.Signing.PrivateKey

    init(key: SecureEnclave.P256.Signing.PrivateKey) {
        self.key = key
    }

    /// `04 ‖ X ‖ Y`.
    var publicKey: [UInt8] { Array(key.publicKey.x963Representation) }

    /// ECDSA with SHA-256 over `message`, DER encoded.
    func sign(_ message: [UInt8]) throws -> [UInt8] {
        Array(try key.signature(for: Data(message)).derRepresentation)
    }
}
