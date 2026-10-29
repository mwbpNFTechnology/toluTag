//
//  ScpSessionKeys.swift
//  toluTag
//
//  The AES keys of one ECKey session, worked out the way the SE05x applet
//  does (AN12543 §3.6.3.3, and NXP's Plug & Trust middleware):
//
//    master key = SHA-256(00000001 ‖ ECDH secret ‖ card challenge ‖ 01 33 ‖ 88 10), first 16 bytes
//    S-ENC  = CMAC(master, 00…00 04 00 0080 01)
//    S-MAC  = CMAC(master, 00…00 06 00 0080 01)
//    S-RMAC = CMAC(master, 00…00 07 00 0080 01)
//    first MAC chaining value = CMAC(master, 00…00 08 00 0080 01)
//

import CryptoKit
import Foundation

struct ScpSessionKeys: Sendable {
    /// C-MAC, C-DECRYPTION, R-MAC and R-ENCRYPTION: every command and every
    /// answer encrypted and authenticated.
    static let securityLevel: UInt8 = 0x33
    /// SCP parameter (0x01) followed by the security level.
    static let scpParameters: [UInt8] = [0x01, securityLevel]
    /// GlobalPlatform key type AES, 16 bytes long.
    static let keyType: UInt8 = 0x88
    static let keyLength: UInt8 = 0x10

    let enc: [UInt8]
    let mac: [UInt8]
    let rmac: [UInt8]
    let initialChainingValue: [UInt8]

    init(sharedSecret: [UInt8], cardChallenge: [UInt8]) {
        // The leading counter is there on applets from 3.5 on — every SE051.
        let input = [0x00, 0x00, 0x00, 0x01] + sharedSecret + cardChallenge
            + Self.scpParameters + [Self.keyType, Self.keyLength]
        let master = Array(Array(SHA256.hash(data: input)).prefix(16))
        enc = AesCmac.mac(Self.derivationData(0x04), key: master)
        mac = AesCmac.mac(Self.derivationData(0x06), key: master)
        rmac = AesCmac.mac(Self.derivationData(0x07), key: master)
        initialChainingValue = AesCmac.mac(Self.derivationData(0x08), key: master)
    }

    /// SCP03 key derivation data: an 11-byte zero label, the constant, a
    /// separator, the output length in bits (128) and the KDF counter (1).
    private static func derivationData(_ constant: UInt8) -> [UInt8] {
        [UInt8](repeating: 0, count: 11) + [constant, 0x00, 0x00, 0x80, 0x01]
    }
}
