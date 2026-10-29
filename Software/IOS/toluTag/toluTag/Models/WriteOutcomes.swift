//
//  WriteOutcomes.swift
//  toluTag
//
//  Result types for the write flows (create key / write text / delete).
//

import Foundation

struct CreateKeyResult {
    let objectId: String
    let address: String?       // nil for PIN-protected keys (needs the PIN to read)
    let pinProtected: Bool
    let userId: String?
}

struct WriteTextResult {
    let objectId: String
    let byteCount: Int
    let created: Bool          // false = updated an existing file
}

enum DeleteOutcome {
    case deleted
    case blocked               // deletion-protected
    case notFound
}
