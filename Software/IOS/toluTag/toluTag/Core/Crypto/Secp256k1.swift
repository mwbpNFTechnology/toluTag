//
//  Secp256k1.swift
//  toluTag
//
//  The slice of secp256k1 needed to turn an SE05x DER signature into an Ethereum
//  (r, s, v) triple: public-key recovery, so v is derived rather than guessed.
//  Ported from the toluCLI reference. Named `Secp256k1` (distinct from the
//  provisioning-only `Secp256k1Curve`).
//

import Foundation

enum Secp256k1 {
    // Field and group order.
    static let p = BigUInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F")!
    static let n = BigUInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")!
    static let halfN = BigUInt(hex: "7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0")!

    private static let gx = BigUInt(hex: "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")!
    private static let gy = BigUInt(hex: "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8")!

    private static let foldFactor = BigUInt(0x1_0000_03D1)
    private static let seven = BigUInt(7)

    // MARK: - Jacobian point

    struct Point {
        var x: BigUInt
        var y: BigUInt
        var z: BigUInt

        static let infinity = Point(x: .one, y: .one, z: .zero)
        var isInfinity: Bool { z.isZero }
    }

    static let generator = Point(x: gx, y: gy, z: .one)

    // MARK: - Public API

    /// Recovers the uncompressed public key (65 bytes, `0x04`-prefixed) that
    /// produced `(r, s)` over `hash` for the given recovery id (0 or 1).
    static func recoverPublicKey(r: BigUInt, s: BigUInt, hash: Data, recoveryId: Int) -> Data? {
        guard !r.isZero, r < n, !s.isZero, s < n else { return nil }

        let alpha = fieldAdd(fieldMul(fieldMul(r, r), r), seven)
        let beta = fieldPow(alpha, (p + .one).shiftedRightTwoBits())
        guard fieldMul(beta, beta) == alpha else { return nil }
        let y = (beta.isOdd == (recoveryId & 1 == 1)) ? beta : fieldSub(p, beta)
        let bigR = Point(x: r, y: y, z: .one)

        let e = BigUInt(bigEndian: hash).modulo(n)
        let rInverse = scalarInverse(r)
        let u1 = scalarMulMod(rInverse, (n - e).modulo(n))
        let u2 = scalarMulMod(rInverse, s)
        let q = add(multiply(generator, by: u1), multiply(bigR, by: u2))

        guard let (qx, qy) = toAffine(q),
              let xBytes = qx.serialized(byteCount: 32),
              let yBytes = qy.serialized(byteCount: 32)
        else { return nil }

        var key = Data([0x04])
        key.append(xBytes)
        key.append(yBytes)
        return key
    }

    // MARK: - Field arithmetic (mod p)

    static func fieldAdd(_ a: BigUInt, _ b: BigUInt) -> BigUInt { reduceModP(a + b) }

    static func fieldSub(_ a: BigUInt, _ b: BigUInt) -> BigUInt {
        a >= b ? a - b : (a + p) - b
    }

    static func fieldMul(_ a: BigUInt, _ b: BigUInt) -> BigUInt { reduceModP(a * b) }

    private static func reduceModP(_ value: BigUInt) -> BigUInt {
        var current = value
        while current.bitWidth > 256 {
            let high = current.shiftedRight(limbs: 8)
            let low = current.truncated(toLimbs: 8)
            current = low + high * foldFactor
        }
        while current >= p { current = current - p }
        return current
    }

    private static func fieldPow(_ base: BigUInt, _ exponent: BigUInt) -> BigUInt {
        var result = BigUInt.one
        var factor = base
        for index in 0..<exponent.bitWidth {
            if exponent.bit(index) { result = fieldMul(result, factor) }
            factor = fieldMul(factor, factor)
        }
        return result
    }

    private static func fieldInverse(_ value: BigUInt) -> BigUInt {
        fieldPow(value, p - BigUInt(2))
    }

    // MARK: - Scalar arithmetic (mod n)

    static func scalarMulMod(_ a: BigUInt, _ b: BigUInt) -> BigUInt { (a * b).modulo(n) }

    private static func scalarInverse(_ value: BigUInt) -> BigUInt {
        var result = BigUInt.one
        var factor = value.modulo(n)
        let exponent = n - BigUInt(2)
        for index in 0..<exponent.bitWidth {
            if exponent.bit(index) { result = scalarMulMod(result, factor) }
            factor = scalarMulMod(factor, factor)
        }
        return result
    }

    // MARK: - Curve arithmetic

    static func double(_ point: Point) -> Point {
        if point.isInfinity || point.y.isZero { return .infinity }
        let a = fieldMul(point.x, point.x)
        let b = fieldMul(point.y, point.y)
        let c = fieldMul(b, b)
        let xPlusB = fieldAdd(point.x, b)
        var d = fieldSub(fieldSub(fieldMul(xPlusB, xPlusB), a), c)
        d = fieldAdd(d, d)
        let e = fieldAdd(fieldAdd(a, a), a)
        let f = fieldMul(e, e)
        let x3 = fieldSub(f, fieldAdd(d, d))
        var eightC = fieldAdd(c, c)
        eightC = fieldAdd(eightC, eightC)
        eightC = fieldAdd(eightC, eightC)
        let y3 = fieldSub(fieldMul(e, fieldSub(d, x3)), eightC)
        let z3 = fieldAdd(fieldMul(point.y, point.z), fieldMul(point.y, point.z))
        return Point(x: x3, y: y3, z: z3)
    }

    static func add(_ lhs: Point, _ rhs: Point) -> Point {
        if lhs.isInfinity { return rhs }
        if rhs.isInfinity { return lhs }

        let z1z1 = fieldMul(lhs.z, lhs.z)
        let z2z2 = fieldMul(rhs.z, rhs.z)
        let u1 = fieldMul(lhs.x, z2z2)
        let u2 = fieldMul(rhs.x, z1z1)
        let s1 = fieldMul(fieldMul(lhs.y, rhs.z), z2z2)
        let s2 = fieldMul(fieldMul(rhs.y, lhs.z), z1z1)

        if u1 == u2 {
            return s1 == s2 ? double(lhs) : .infinity
        }

        let h = fieldSub(u2, u1)
        let twoH = fieldAdd(h, h)
        let i = fieldMul(twoH, twoH)
        let j = fieldMul(h, i)
        let rr = fieldAdd(fieldSub(s2, s1), fieldSub(s2, s1))
        let v = fieldMul(u1, i)
        let x3 = fieldSub(fieldSub(fieldMul(rr, rr), j), fieldAdd(v, v))
        let twoS1J = fieldAdd(fieldMul(s1, j), fieldMul(s1, j))
        let y3 = fieldSub(fieldMul(rr, fieldSub(v, x3)), twoS1J)
        let zSum = fieldAdd(lhs.z, rhs.z)
        let z3 = fieldMul(fieldSub(fieldSub(fieldMul(zSum, zSum), z1z1), z2z2), h)
        return Point(x: x3, y: y3, z: z3)
    }

    static func multiply(_ point: Point, by scalar: BigUInt) -> Point {
        if scalar.isZero || point.isInfinity { return .infinity }
        var result = Point.infinity
        for index in stride(from: scalar.bitWidth - 1, through: 0, by: -1) {
            result = double(result)
            if scalar.bit(index) { result = add(result, point) }
        }
        return result
    }

    static func toAffine(_ point: Point) -> (BigUInt, BigUInt)? {
        guard !point.isInfinity else { return nil }
        let zInverse = fieldInverse(point.z)
        let zInverse2 = fieldMul(zInverse, zInverse)
        let zInverse3 = fieldMul(zInverse2, zInverse)
        return (fieldMul(point.x, zInverse2), fieldMul(point.y, zInverse3))
    }
}

private extension BigUInt {
    /// (p + 1) / 4 for the modular square root (p ≡ 3 mod 4).
    func shiftedRightTwoBits() -> BigUInt {
        var result = [UInt32](repeating: 0, count: limbs.count)
        var carry: UInt32 = 0
        for index in stride(from: limbs.count - 1, through: 0, by: -1) {
            let limb = limbs[index]
            result[index] = (limb >> 2) | (carry << 30)
            carry = limb & 0b11
        }
        return BigUInt(limbs: result)
    }
}
