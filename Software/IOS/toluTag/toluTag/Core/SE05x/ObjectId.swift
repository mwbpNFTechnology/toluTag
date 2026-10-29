//
//  ObjectId.swift
//  toluTag
//
//  A 4-byte SE05x object identifier, parsed from up to 8 hex characters.
//

import Foundation

struct ObjectId {
    let bytes: [UInt8]   // exactly 4

    var hex: String { Hex.string(bytes).uppercased() }

    /// The identifier as a big-endian 32-bit value (for a policy auth id).
    var authId: UInt32 { bytes.reduce(0) { ($0 << 8) | UInt32($1) } }

    /// Parses up to 8 hex characters, left-padding with zeros (e.g. "2222" -> 00002222).
    static func parse(_ text: String) -> ObjectId? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 8, cleaned.allSatisfy(\.isHexDigit) else {
            return nil
        }
        let padded = String(repeating: "0", count: 8 - cleaned.count) + cleaned
        guard let bytes = Hex.bytes(padded), bytes.count == 4 else { return nil }
        return ObjectId(bytes: bytes)
    }
}
