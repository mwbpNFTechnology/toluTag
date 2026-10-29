//
//  NistP256Curve.swift
//  toluTag
//
//  NIST P-256, the curve of the iPhone's Secure Enclave key. The tag has to
//  know it before that key can be stored as an ECKey authentication object.
//

import Foundation

enum NistP256Curve {
    static let curveId: UInt8 = 0x03

    // Parameter selectors
    private static let paramPrime: UInt8 = 0x10
    private static let paramA: UInt8 = 0x01
    private static let paramB: UInt8 = 0x02
    private static let paramG: UInt8 = 0x04
    private static let paramN: UInt8 = 0x08

    private static let prime = Hex.bytes("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF")!
    private static let a = Hex.bytes("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC")!
    private static let b = Hex.bytes("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B")!
    private static let g = Hex.bytes("046B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C2964FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")!
    private static let n = Hex.bytes("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")!

    /// Parameters in the order they should be written to the card.
    static let orderedParameters: [(selector: UInt8, value: [UInt8])] = [
        (paramPrime, prime), (paramA, a), (paramB, b), (paramG, g), (paramN, n)
    ]
}
