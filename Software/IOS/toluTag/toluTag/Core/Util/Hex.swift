//
//  Hex.swift
//  toluTag
//
//  Hex encoding/decoding for byte arrays.
//

import Foundation

enum Hex {
    static func string(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func string(_ data: Data) -> String {
        string([UInt8](data))
    }

    static func bytes(_ hex: String) -> [UInt8]? {
        let cleaned = hex.hasPrefix("0x") || hex.hasPrefix("0X") ? String(hex.dropFirst(2)) : hex
        guard cleaned.count % 2 == 0 else { return nil }
        var result = [UInt8]()
        result.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        return result
    }
}
