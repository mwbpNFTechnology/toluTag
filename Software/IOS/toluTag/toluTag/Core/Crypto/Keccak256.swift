//
//  Keccak256.swift
//  toluTag
//
//  Self-contained Keccak-256 (Ethereum flavor, padding byte 0x01 — not NIST
//  SHA3). No third-party dependency. Ported from the toluTag Java reference and
//  verified against known Ethereum vectors.
//

import Foundation

enum Keccak256 {

    private static let rateBytes = 136   // 1600-bit state minus 512-bit capacity
    private static let outputBytes = 32

    private static let roundConstants: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
        0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
        0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]

    private static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27,
        36, 44, 6, 55, 20,
        3, 10, 43, 25, 39,
        41, 45, 15, 21, 8,
        18, 2, 61, 56, 14
    ]

    /// Computes the Keccak-256 digest of `input`.
    static func digest(_ input: [UInt8]) -> [UInt8] {
        var state = [UInt64](repeating: 0, count: 25)

        var offset = 0
        let fullBlocks = input.count / rateBytes
        for _ in 0..<fullBlocks {
            absorb(&state, input, offset)
            keccakF(&state)
            offset += rateBytes
        }

        var last = [UInt8](repeating: 0, count: rateBytes)
        let remaining = input.count - offset
        for i in 0..<remaining { last[i] = input[offset + i] }
        last[remaining] ^= 0x01
        last[rateBytes - 1] ^= 0x80
        absorb(&state, last, 0)
        keccakF(&state)

        var output = [UInt8](repeating: 0, count: outputBytes)
        for i in 0..<outputBytes {
            output[i] = UInt8((state[i / 8] >> (8 * (i % 8))) & 0xFF)
        }
        return output
    }

    static func digest(_ data: Data) -> [UInt8] {
        digest([UInt8](data))
    }

    private static func absorb(_ state: inout [UInt64], _ data: [UInt8], _ offset: Int) {
        for i in 0..<(rateBytes / 8) {
            state[i] ^= readLane(data, offset + i * 8)
        }
    }

    private static func readLane(_ data: [UInt8], _ offset: Int) -> UInt64 {
        var lane: UInt64 = 0
        for i in 0..<8 { lane |= UInt64(data[offset + i]) << (8 * i) }
        return lane
    }

    private static func keccakF(_ state: inout [UInt64]) {
        var c = [UInt64](repeating: 0, count: 5)
        var d = [UInt64](repeating: 0, count: 5)
        var b = [UInt64](repeating: 0, count: 25)

        for round in 0..<24 {
            // Theta
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1)
            }
            for x in 0..<5 {
                for y in 0..<5 { state[x + 5 * y] ^= d[x] }
            }

            // Rho + Pi
            for x in 0..<5 {
                for y in 0..<5 {
                    let index = x + 5 * y
                    let newIndex = y + 5 * ((2 * x + 3 * y) % 5)
                    b[newIndex] = rotl(state[index], rotationOffsets[index])
                }
            }

            // Chi
            for x in 0..<5 {
                for y in 0..<5 {
                    let index = x + 5 * y
                    state[index] = b[index] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y])
                }
            }

            // Iota
            state[0] ^= roundConstants[round]
        }
    }

    private static func rotl(_ value: UInt64, _ n: Int) -> UInt64 {
        n == 0 ? value : (value << n) | (value >> (64 - n))
    }
}
