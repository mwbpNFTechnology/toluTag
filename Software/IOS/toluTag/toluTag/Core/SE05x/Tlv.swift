//
//  Tlv.swift
//  toluTag
//
//  Minimal TLV (tag-length-value) build/parse for SE05x APDU payloads.
//

import Foundation

enum Tlv {
    /// Encodes a TLV: the short length form up to 127 bytes, then the
    /// 0x81 / 0x82 long forms (a wrapped session command can be longer).
    static func encode(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
        [tag] + length(value.count) + value
    }

    /// An ISO 7816 BER length field.
    static func length(_ count: Int) -> [UInt8] {
        switch count {
        case ..<0x80: [UInt8(count)]
        case ..<0x100: [0x81, UInt8(count)]
        default: [0x82, UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count)]
        }
    }

    /// Returns the value of the first top-level TLV with the given tag.
    /// Understands the ISO 7816 short form and the 0x81 / 0x82 length forms.
    static func findValue(_ bytes: [UInt8], tag: UInt8) -> [UInt8]? {
        var i = 0
        while i + 2 <= bytes.count {
            let currentTag = bytes[i]
            i += 1
            var length = Int(bytes[i])
            i += 1
            if length == 0x81 {
                if i >= bytes.count { break }
                length = Int(bytes[i]); i += 1
            } else if length == 0x82 {
                if i + 1 >= bytes.count { break }
                length = (Int(bytes[i]) << 8) | Int(bytes[i + 1]); i += 2
            }
            if i + length > bytes.count { break }
            if currentTag == tag { return Array(bytes[i..<i + length]) }
            i += length
        }
        return nil
    }
}
