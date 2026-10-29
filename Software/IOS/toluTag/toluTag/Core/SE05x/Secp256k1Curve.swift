//
//  Secp256k1Curve.swift
//  toluTag
//
//  secp256k1 domain parameters, used to provision the curve on the SE05x before
//  creating a key.
//

import Foundation

enum Secp256k1Curve {
    static let curveId: UInt8 = 0x10

    // Parameter selectors
    private static let paramPrime: UInt8 = 0x10
    private static let paramA: UInt8 = 0x01
    private static let paramB: UInt8 = 0x02
    private static let paramG: UInt8 = 0x04
    private static let paramN: UInt8 = 0x08

    private static let prime = Hex.bytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F")!
    private static let a = Hex.bytes("0000000000000000000000000000000000000000000000000000000000000000")!
    private static let b = Hex.bytes("0000000000000000000000000000000000000000000000000000000000000007")!
    private static let g = Hex.bytes("0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8")!
    private static let n = Hex.bytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")!

    /// Parameters in the order they should be written to the card.
    static let orderedParameters: [(selector: UInt8, value: [UInt8])] = [
        (paramPrime, prime), (paramA, a), (paramB, b), (paramG, g), (paramN, n)
    ]
}
