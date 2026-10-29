//
//  Data+Hex.swift
//  toluTag
//

import Foundation

extension Data {
    /// Lowercase hex string of the bytes.
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
