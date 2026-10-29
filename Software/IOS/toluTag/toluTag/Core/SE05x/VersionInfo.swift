//
//  VersionInfo.swift
//  toluTag
//
//  Applet version information returned by GetVersion (spec §4.20.1). The spec
//  doesn't tabulate the exact byte offsets, so this is a best-effort read of the
//  conventional layout [major, minor, patch, config(2), secureBox(2)], with the
//  raw bytes exposed for inspection. Ported from the Java VersionInfo.
//

import Foundation

struct VersionInfo {
    let raw: [UInt8]

    // AppletConfig feature bits (spec Table 48); aggregates (ALL) omitted.
    private static let featureBits: [Int] = [
        0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040,
        0x0080, 0x0100, 0x0200, 0x0400, 0x0800, 0x2000
    ]
    private static let featureNames: [String] = [
        "ECDSA/ECDH/ECDHE", "EdDSA", "DH-Montgomery", "HMAC", "RSA-plain", "RSA-CRT",
        "AES", "DES", "PBKDF", "TLS", "MIFARE", "I2CM"
    ]

    private func at(_ index: Int) -> Int {
        index < raw.count ? Int(raw[index]) : 0
    }

    var rawHex: String { "0x" + Hex.string(raw) }

    /// Best-effort "major.minor.patch" from the first three bytes.
    var versionString: String { "\(at(0)).\(at(1)).\(at(2))" }

    /// Applet feature configuration word (best-effort, bytes 3-4).
    var appletConfig: Int { (at(3) << 8) | at(4) }

    /// Secure-box version (best-effort, bytes 5-6).
    var secureBoxVersion: Int { (at(5) << 8) | at(6) }

    /// Enabled feature names decoded from `appletConfig`.
    var features: [String] {
        let config = appletConfig
        var enabled: [String] = []
        for (i, bit) in Self.featureBits.enumerated() where (config & bit) != 0 {
            enabled.append(Self.featureNames[i])
        }
        return enabled
    }
}
