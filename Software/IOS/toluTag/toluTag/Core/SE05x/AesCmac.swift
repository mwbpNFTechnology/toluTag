//
//  AesCmac.swift
//  toluTag
//
//  AES-CMAC (RFC 4493, NIST SP 800-38B): the MAC and the key derivation
//  function of SCP03 secure messaging.
//

import Foundation

enum AesCmac {

    /// The full 16-byte CMAC of `message` under a 16-byte `key`.
    static func mac(_ message: [UInt8], key: [UInt8]) -> [UInt8] {
        let blockSize = Aes128.blockSize
        let (k1, k2) = subkeys(key)

        let blockCount = max(1, (message.count + blockSize - 1) / blockSize)
        let lastIsWhole = !message.isEmpty && message.count % blockSize == 0

        var last = Array(message[((blockCount - 1) * blockSize)...])
        if lastIsWhole {
            last = xor(last, k1)
        } else {
            last.append(0x80)
            last += [UInt8](repeating: 0, count: blockSize - last.count)
            last = xor(last, k2)
        }

        var state = [UInt8](repeating: 0, count: blockSize)
        for index in 0..<(blockCount - 1) {
            let block = Array(message[(index * blockSize)..<((index + 1) * blockSize)])
            state = Aes128.encryptBlock(xor(state, block), key: key)
        }
        return Aes128.encryptBlock(xor(state, last), key: key)
    }

    private static func subkeys(_ key: [UInt8]) -> ([UInt8], [UInt8]) {
        let l = Aes128.encryptBlock([UInt8](repeating: 0, count: Aes128.blockSize), key: key)
        let k1 = doubled(l)
        return (k1, doubled(k1))
    }

    /// Multiplication by x in GF(2^128): a left shift, folding the carry with 0x87.
    private static func doubled(_ block: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: block.count)
        var carry: UInt8 = 0
        for index in stride(from: block.count - 1, through: 0, by: -1) {
            out[index] = (block[index] << 1) | carry
            carry = block[index] >> 7
        }
        if carry == 1 { out[block.count - 1] ^= 0x87 }
        return out
    }

    private static func xor(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        zip(a, b).map { $0 ^ $1 }
    }
}
