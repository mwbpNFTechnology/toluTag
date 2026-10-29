//
//  SecureObjectType.swift
//  toluTag
//
//  Decodes the SE05x SecureObjectType byte (spec Table 30). For EC objects the
//  byte encodes both the curve and the role (pair / private / public).
//

import Foundation

enum SecureObjectType {
    private static let weierstrassCurves = [
        "NIST_P192", "NIST_P224", "NIST_P256", "NIST_P384", "NIST_P521",
        "Brainpool160", "Brainpool192", "Brainpool224", "Brainpool256",
        "Brainpool320", "Brainpool384", "Brainpool512",
        "Secp160k1", "Secp192k1", "Secp224k1", "Secp256k1"
    ]

    private static let base: [Int: String] = [
        0x01: "EC key pair", 0x02: "EC private key", 0x03: "EC public key",
        0x04: "RSA key pair", 0x05: "RSA key pair (CRT)", 0x06: "RSA private key",
        0x07: "RSA private key (CRT)", 0x08: "RSA public key",
        0x09: "AES key", 0x0A: "DES key", 0x0B: "Binary file",
        0x0C: "UserID", 0x0D: "Counter", 0x0F: "PCR", 0x11: "HMAC key"
    ]

    static func describe(_ typeByte: Int) -> String {
        let value = typeByte & 0xFF
        if let name = base[value] { return name }
        if let ec = describeEc(value) { return ec }
        return String(format: "unknown type (0x%02X)", value)
    }

    private static func describeEc(_ value: Int) -> String? {
        let roles = ["key pair", "private key", "public key"]

        // Weierstrass families: 0x21 upward, 4 values per curve.
        if value >= 0x21 {
            let block = (value - 0x21) / 4
            let role = (value - 0x21) % 4
            if block < weierstrassCurves.count, role < 3 {
                return "EC \(roles[role]) (\(weierstrassCurves[block]))"
            }
        }
        // Edwards / Montgomery families.
        for (start, curve) in [(0x65, "ED25519"), (0x69, "MONT_DH_25519"), (0x71, "MONT_DH_448")] {
            let role = value - start
            if role >= 0, role < 3 { return "EC \(roles[role]) (\(curve))" }
        }
        return nil
    }
}
