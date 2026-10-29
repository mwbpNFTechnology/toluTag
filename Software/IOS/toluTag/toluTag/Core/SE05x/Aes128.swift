//
//  Aes128.swift
//  toluTag
//
//  The two AES-128 operations secure messaging needs: one block (ECB) and
//  CBC without padding. Callers pass whole blocks and 16-byte keys.
//

import CommonCrypto
import Foundation

enum Aes128 {
    static let blockSize = 16

    /// Encrypts one 16-byte block.
    static func encryptBlock(_ block: [UInt8], key: [UInt8]) -> [UInt8] {
        crypt(block, key: key, iv: nil, operation: CCOperation(kCCEncrypt))
    }

    static func cbcEncrypt(_ data: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8] {
        crypt(data, key: key, iv: iv, operation: CCOperation(kCCEncrypt))
    }

    static func cbcDecrypt(_ data: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8] {
        crypt(data, key: key, iv: iv, operation: CCOperation(kCCDecrypt))
    }

    /// `iv == nil` means a single ECB block.
    private static func crypt(_ data: [UInt8], key: [UInt8], iv: [UInt8]?, operation: CCOperation) -> [UInt8] {
        precondition(key.count == kCCKeySizeAES128 && data.count % blockSize == 0, "AES-128 takes whole blocks")
        var output = [UInt8](repeating: 0, count: data.count)
        var written = 0
        let options = CCOptions(iv == nil ? kCCOptionECBMode : 0)
        let status = CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES), options,
                             key, key.count, iv, data, data.count,
                             &output, output.count, &written)
        precondition(status == kCCSuccess && written == data.count, "AES-128 failed")
        return output
    }
}
