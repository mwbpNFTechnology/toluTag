//
//  EcKeyPolicy.swift
//  toluTag
//
//  SE05x object policy (access-rule) TLV builder. One rule entry binds a set of
//  permission bits to an authentication-object id (0 = the default session).
//

import Foundation

struct EcKeyPolicy {
    // Permission bits (32-bit access-rule mask).
    static let sign: UInt32 = 0x1000_0000
    static let verify: UInt32 = 0x0800_0000
    static let keyAgreement: UInt32 = 0x0400_0000
    static let encrypt: UInt32 = 0x0200_0000
    static let decrypt: UInt32 = 0x0100_0000
    static let read: UInt32 = 0x0020_0000
    static let write: UInt32 = 0x0010_0000
    static let generate: UInt32 = 0x0008_0000
    static let delete: UInt32 = 0x0004_0000

    let authId: UInt32
    let mask: UInt32

    /// `[TAG_POLICY, 0x09, 0x08, authId(4), mask(4)]`
    func toTlv() -> [UInt8] {
        [Se05x.tagPolicy, 0x09, 0x08] + authId.bigEndianBytes + mask.bigEndianBytes
    }

    /// Full EC-key permissions, bound to `authId` (default session when 0),
    /// omitting DELETE so the key can't be removed.
    static func keyUsage(authId: UInt32) -> EcKeyPolicy {
        EcKeyPolicy(
            authId: authId,
            mask: sign | verify | keyAgreement | encrypt | decrypt | generate | write | read
        )
    }

    /// BinaryFile permissions for the default session.
    static func binaryFile(deletable: Bool) -> EcKeyPolicy {
        EcKeyPolicy(authId: 0, mask: read | write | (deletable ? delete : 0))
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 24) & 0xFF), UInt8((self >> 16) & 0xFF),
         UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}
