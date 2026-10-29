//
//  ObjectAttributes.swift
//  toluTag
//
//  Parsed attributes buffer of a Secure Object (ReadObjectAttributes, spec
//  Table 4). The spec lists the fields but not the exact serialization, so this
//  reads the fixed header from the front and origin/version from the back, with
//  the variable-length policy in between. Ported from the Java ObjectAttributes.
//
//  Field order: object id (4), type (1), auth indicator (1), min AEAD tag length
//  (2), session owner (4), min output length (2), policy (variable), origin (1),
//  version (4).
//

import Foundation

struct ObjectAttributes {
    private static let headerLength = 14   // up to and including min output length
    private static let trailerLength = 5   // origin (1) + version (4)
    private static let minimumLength = headerLength + trailerLength
    private static let setIndicatorSet = 0x02  // SET (0x02) vs NOT_SET (0x01)

    let raw: [UInt8]
    let objectIdentifier: [UInt8]
    let typeByte: Int
    private let authIndicatorByte: Int
    let policy: [UInt8]
    let origin: Origin
    let version: UInt64

    var isAuthenticationObject: Bool { authIndicatorByte == Self.setIndicatorSet }
    var rawHex: String { "0x" + Hex.string(raw) }
    var policyHex: String { "0x" + Hex.string(policy) }

    /// Whether any access rule in the policy grants DELETE. The policy is a run
    /// of rules, each `[ruleLen][authId(4)][mask(4)]`; the mask's DELETE bit
    /// (`EcKeyPolicy.delete`) says the object can be removed from the tag.
    var allowsDelete: Bool {
        var i = 0
        while i < policy.count {
            let ruleLen = Int(policy[i])
            i += 1
            if ruleLen >= 8, i + 8 <= policy.count {
                let mask = (UInt32(policy[i + 4]) << 24) | (UInt32(policy[i + 5]) << 16)
                    | (UInt32(policy[i + 6]) << 8) | UInt32(policy[i + 7])
                if mask & EcKeyPolicy.delete != 0 { return true }
            }
            i += ruleLen
        }
        return false
    }

    /// Parses an attributes buffer, or returns nil if it is too short.
    static func parse(_ buffer: [UInt8]) -> ObjectAttributes? {
        guard buffer.count >= minimumLength else { return nil }
        let identifier = Array(buffer[0..<4])
        let type = Int(buffer[4])
        let authIndicator = Int(buffer[5])

        let originIndex = buffer.count - trailerLength
        let policy = Array(buffer[headerLength..<originIndex])
        let origin = Origin.from(buffer[originIndex])

        var version: UInt64 = 0
        for i in (originIndex + 1)..<buffer.count {
            version = (version << 8) | UInt64(buffer[i])
        }

        return ObjectAttributes(raw: buffer, objectIdentifier: identifier, typeByte: type,
                                authIndicatorByte: authIndicator, policy: policy,
                                origin: origin, version: version)
    }
}
