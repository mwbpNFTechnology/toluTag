//
//  EthereumAddress.swift
//  toluTag
//
//  Derives an Ethereum address from a secp256k1 public key point:
//  keccak256(X || Y), last 20 bytes.
//

import Foundation

enum EthereumAddress {
    /// - Parameter point: uncompressed public key (`0x04 || X || Y`, 65 bytes).
    /// - Returns: the `0x`-prefixed lower-case address, or `nil` if the point is invalid.
    static func from(publicKeyPoint point: [UInt8]) -> String? {
        guard point.count == 65, point[0] == 0x04 else { return nil }
        let xy = Array(point[1..<65])
        let hash = Keccak256.digest(xy)
        return "0x" + Hex.string(Array(hash[12..<32]))
    }
}
