//
//  Eip191.swift
//  toluTag
//
//  EIP-191 personal_sign hash:
//  keccak256(0x19 || "Ethereum Signed Message:\n" || len(message) || message),
//  where len is the message's UTF-8 byte length as decimal ASCII. Ported from
//  the Java Eip191.
//

import Foundation

enum Eip191 {
    /// The 32-byte Keccak-256 hash of the prefixed message.
    static func personalMessageHash(_ message: String) -> [UInt8] {
        let body = Array(message.utf8)
        let prefix = Array("\u{19}Ethereum Signed Message:\n\(body.count)".utf8)
        return Keccak256.digest(prefix + body)
    }
}
