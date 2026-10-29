//
//  EthereumSigner.swift
//  toluTag
//
//  Turns a DER ECDSA signature from the SE05x into an Ethereum (r, s, v) triple:
//  parse DER, apply low-S (EIP-2), and recover v (27/28) against the signer's
//  known public key. Ported from the Java EthereumSignature / toluCLI TagSigner.
//

import Foundation

struct EthereumSignature {
    let r: String            // 0x + 64 lower-case hex
    let s: String            // 0x + 64 lower-case hex
    let v: Int
    let messageHash: String  // 0x + 64 upper-case hex
    /// True when v was recovered by matching the public key (vs. the 28 fallback).
    let recovered: Bool
}

enum EthereumSigner {

    /// Builds an Ethereum signature from a DER signature over `hash`, using the
    /// signer's uncompressed public key to recover v.
    static func makeSignature(der: [UInt8], hash: [UInt8], publicKey: [UInt8]) -> EthereumSignature? {
        guard let (r, parsedS) = parseDER(der) else { return nil }

        // Ethereum only accepts the low-S form.
        let s = parsedS > Secp256k1.halfN ? Secp256k1.n - parsedS : parsedS

        let hashData = Data(hash)
        let publicKeyData = Data(publicKey)
        var recoveredV: Int?
        for recoveryId in 0...1 {
            if let candidate = Secp256k1.recoverPublicKey(r: r, s: s, hash: hashData, recoveryId: recoveryId),
               candidate == publicKeyData {
                recoveredV = 27 + recoveryId
                break
            }
        }

        guard let rBytes = r.serialized(byteCount: 32), let sBytes = s.serialized(byteCount: 32) else { return nil }
        return EthereumSignature(
            r: "0x" + Hex.string([UInt8](rBytes)),
            s: "0x" + Hex.string([UInt8](sBytes)),
            v: recoveredV ?? 28,
            messageHash: "0x" + Hex.string(hash).uppercased(),
            recovered: recoveredV != nil
        )
    }

    /// Parses `SEQUENCE { INTEGER r, INTEGER s }`.
    static func parseDER(_ der: [UInt8]) -> (BigUInt, BigUInt)? {
        var offset = 0

        func readLength() -> Int? {
            guard offset < der.count else { return nil }
            let first = der[offset]; offset += 1
            if first < 0x80 { return Int(first) }
            let count = Int(first & 0x7F)
            guard count > 0, count <= 2, offset + count <= der.count else { return nil }
            var value = 0
            for _ in 0..<count { value = value << 8 | Int(der[offset]); offset += 1 }
            return value
        }

        func readInteger() -> BigUInt? {
            guard offset < der.count, der[offset] == 0x02 else { return nil }
            offset += 1
            guard let length = readLength(), offset + length <= der.count else { return nil }
            let value = BigUInt(bigEndian: Data(der[offset..<(offset + length)]))
            offset += length
            return value
        }

        guard !der.isEmpty, der[0] == 0x30 else { return nil }
        offset = 1
        guard readLength() != nil, let r = readInteger(), let s = readInteger() else { return nil }
        return (r, s)
    }
}
