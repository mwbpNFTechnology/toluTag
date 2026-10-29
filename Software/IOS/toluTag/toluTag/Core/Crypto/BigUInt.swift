//
//  BigUInt.swift
//  toluTag
//
//  A small arbitrary-precision unsigned integer — just enough arithmetic to do
//  secp256k1 public-key recovery without a third-party dependency. Little-endian
//  32-bit limbs, always trimmed of trailing zero limbs. Ported from the toluCLI
//  reference. Deliberately not constant-time: it only touches public values
//  (signature components, public keys), never a private key.
//

import Foundation

struct BigUInt: Equatable, Comparable {
    private(set) var limbs: [UInt32]

    static let zero = BigUInt()
    static let one = BigUInt(1)

    init() { limbs = [] }

    init(limbs: [UInt32]) {
        self.limbs = limbs
        trim()
    }

    init(_ value: UInt64) {
        self.init(limbs: [UInt32(truncatingIfNeeded: value), UInt32(truncatingIfNeeded: value >> 32)])
    }

    /// Big-endian bytes, as everything Ethereum hands us is encoded.
    init(bigEndian data: Data) {
        var built: [UInt32] = []
        var accumulator: UInt32 = 0
        var shift: UInt32 = 0
        for byte in data.reversed() {
            accumulator |= UInt32(byte) << shift
            shift += 8
            if shift == 32 {
                built.append(accumulator)
                accumulator = 0
                shift = 0
            }
        }
        if shift > 0 { built.append(accumulator) }
        self.init(limbs: built)
    }

    init?(hex: String) {
        var cleaned = hex.hasPrefix("0x") || hex.hasPrefix("0X") ? String(hex.dropFirst(2)) : hex
        if cleaned.count % 2 == 1 { cleaned = "0" + cleaned }
        var bytes = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bigEndian: bytes)
    }

    /// Parses a non-negative decimal string.
    init?(decimalString: String) {
        var acc = BigUInt.zero
        let ten = BigUInt(10)
        for ch in decimalString {
            guard let digit = ch.wholeNumberValue, (0...9).contains(digit) else { return nil }
            acc = acc * ten + BigUInt(UInt64(digit))
        }
        self = acc
    }

    /// 2^256, used for two's-complement negative ints.
    static let twoPow256 = BigUInt(limbs: [0, 0, 0, 0, 0, 0, 0, 0, 1])

    private mutating func trim() {
        while let last = limbs.last, last == 0 { limbs.removeLast() }
    }

    // MARK: - Inspection

    var isZero: Bool { limbs.isEmpty }
    var isOdd: Bool { (limbs.first ?? 0) & 1 == 1 }

    var bitWidth: Int {
        guard let top = limbs.last else { return 0 }
        return limbs.count * 32 - top.leadingZeroBitCount
    }

    func bit(_ index: Int) -> Bool {
        let word = index >> 5
        guard word < limbs.count else { return false }
        return (limbs[word] >> UInt32(index & 31)) & 1 == 1
    }

    /// Fixed-width big-endian encoding; returns nil if the value doesn't fit.
    func serialized(byteCount: Int) -> Data? {
        var out = [UInt8](repeating: 0, count: byteCount)
        for (index, limb) in limbs.enumerated() {
            for byte in 0..<4 {
                let value = UInt8(truncatingIfNeeded: limb >> (8 * UInt32(byte)))
                let position = byteCount - 1 - (index * 4 + byte)
                if position < 0 {
                    if value != 0 { return nil }
                } else {
                    out[position] = value
                }
            }
        }
        return Data(out)
    }

    // MARK: - Comparison

    static func < (lhs: BigUInt, rhs: BigUInt) -> Bool { compare(lhs, rhs) < 0 }

    private static func compare(_ lhs: BigUInt, _ rhs: BigUInt) -> Int {
        if lhs.limbs.count != rhs.limbs.count {
            return lhs.limbs.count < rhs.limbs.count ? -1 : 1
        }
        for index in stride(from: lhs.limbs.count - 1, through: 0, by: -1) where lhs.limbs[index] != rhs.limbs[index] {
            return lhs.limbs[index] < rhs.limbs[index] ? -1 : 1
        }
        return 0
    }

    // MARK: - Arithmetic

    static func + (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        var result: [UInt32] = []
        result.reserveCapacity(max(lhs.limbs.count, rhs.limbs.count) + 1)
        var carry: UInt64 = 0
        for index in 0..<max(lhs.limbs.count, rhs.limbs.count) {
            let sum = UInt64(index < lhs.limbs.count ? lhs.limbs[index] : 0)
                + UInt64(index < rhs.limbs.count ? rhs.limbs[index] : 0)
                + carry
            result.append(UInt32(truncatingIfNeeded: sum))
            carry = sum >> 32
        }
        if carry > 0 { result.append(UInt32(carry)) }
        return BigUInt(limbs: result)
    }

    /// Precondition: `lhs >= rhs`.
    static func - (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        var result: [UInt32] = []
        result.reserveCapacity(lhs.limbs.count)
        var borrow: Int64 = 0
        for index in 0..<lhs.limbs.count {
            let difference = Int64(lhs.limbs[index])
                - Int64(index < rhs.limbs.count ? rhs.limbs[index] : 0)
                - borrow
            if difference < 0 {
                result.append(UInt32(truncatingIfNeeded: difference + 0x1_0000_0000))
                borrow = 1
            } else {
                result.append(UInt32(difference))
                borrow = 0
            }
        }
        return BigUInt(limbs: result)
    }

    static func * (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        if lhs.isZero || rhs.isZero { return .zero }
        var result = [UInt32](repeating: 0, count: lhs.limbs.count + rhs.limbs.count)
        for i in 0..<lhs.limbs.count {
            var carry: UInt64 = 0
            let a = UInt64(lhs.limbs[i])
            for j in 0..<rhs.limbs.count {
                let product = a * UInt64(rhs.limbs[j]) + UInt64(result[i + j]) + carry
                result[i + j] = UInt32(truncatingIfNeeded: product)
                carry = product >> 32
            }
            var index = i + rhs.limbs.count
            while carry > 0 {
                let sum = UInt64(result[index]) + carry
                result[index] = UInt32(truncatingIfNeeded: sum)
                carry = sum >> 32
                index += 1
            }
        }
        return BigUInt(limbs: result)
    }

    /// Shift right by whole 32-bit limbs — the only shift the reduction needs.
    func shiftedRight(limbs count: Int) -> BigUInt {
        guard count < limbs.count else { return .zero }
        return BigUInt(limbs: Array(limbs[count...]))
    }

    /// Keep only the low `count` limbs.
    func truncated(toLimbs count: Int) -> BigUInt {
        guard limbs.count > count else { return self }
        return BigUInt(limbs: Array(limbs[0..<count]))
    }

    /// Binary long-division remainder. Used only for scalar (mod n) arithmetic.
    func modulo(_ modulus: BigUInt) -> BigUInt {
        precondition(!modulus.isZero, "division by zero")
        if self < modulus { return self }
        var remainder = BigUInt.zero
        for index in stride(from: bitWidth - 1, through: 0, by: -1) {
            remainder = remainder.doubled()
            if bit(index) { remainder.setLowBit() }
            if remainder >= modulus { remainder = remainder - modulus }
        }
        return remainder
    }

    private func doubled() -> BigUInt {
        var result: [UInt32] = []
        result.reserveCapacity(limbs.count + 1)
        var carry: UInt32 = 0
        for limb in limbs {
            result.append((limb << 1) | carry)
            carry = limb >> 31
        }
        if carry > 0 { result.append(carry) }
        return BigUInt(limbs: result)
    }

    private mutating func setLowBit() {
        if limbs.isEmpty {
            limbs = [1]
        } else {
            limbs[0] |= 1
        }
    }
}
