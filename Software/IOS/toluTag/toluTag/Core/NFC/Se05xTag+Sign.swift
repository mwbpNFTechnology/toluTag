//
//  Se05xTag+Sign.swift
//  toluTag
//
//  ECDSA signing: have the tag sign a 32-byte digest with a secp256k1 key,
//  returning the DER signature. Wrapped in the session (via `execute`) when a
//  PIN session is open, so pin-protected keys can sign.
//

import Foundation

extension Se05xTag {

    /// Signs `digest` with the key at `objectId`, returning the raw DER
    /// signature (`SEQUENCE { INTEGER r, INTEGER s }`).
    func signDigest(objectId: [UInt8], digest: [UInt8]) async throws -> [UInt8] {
        let data = Tlv.encode(Se05x.tag1, objectId)
            + Tlv.encode(Se05x.tag2, [Se05x.sigEcdsaSha256])
            + Tlv.encode(Se05x.tag3, digest)
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insCrypto,
                                         p1: Se05x.p1Signature, p2: Se05x.p2Sign,
                                         data: data, operation: "sign")
        // `execute` already unwraps a session TLV; find the DER sequence to be safe.
        return Self.extractDER(response) ?? response
    }

    private static func extractDER(_ bytes: [UInt8]) -> [UInt8]? {
        guard bytes.count > 2 else { return nil }
        for i in 0..<(bytes.count - 1) where bytes[i] == 0x30 {
            let seqLength = Int(bytes[i + 1])
            if i + 2 + seqLength <= bytes.count { return Array(bytes[i..<(i + 2 + seqLength)]) }
        }
        return nil
    }
}
