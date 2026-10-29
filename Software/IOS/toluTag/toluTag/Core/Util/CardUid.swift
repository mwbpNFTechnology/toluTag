//
//  CardUid.swift
//  toluTag
//
//  The card's factory unique id, normalized so values read by different code
//  paths (the async reader, the ported writer) compare equal. Two physical tags
//  can share an object id, so records are matched on (uniqueId + objectId).
//

import Foundation

enum CardUid {
    /// Uppercased hex with any "0x" prefix and non-hex characters removed.
    /// Returns nil for an empty / unusable value.
    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var s = raw
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s = String(s.dropFirst(2)) }
        let cleaned = s.uppercased().filter { $0.isHexDigit }
        return cleaned.isEmpty ? nil : cleaned
    }

    /// True when both ids are present and equal after normalization.
    static func sameCard(_ a: String?, _ b: String?) -> Bool {
        guard let a = normalize(a), let b = normalize(b) else { return false }
        return a == b
    }
}
