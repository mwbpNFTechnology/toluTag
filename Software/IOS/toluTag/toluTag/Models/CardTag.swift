//
//  CardTag.swift
//  toluTag
//
//  A user-given name for a physical card, keyed by its factory unique id. Lets
//  records be grouped and filtered by card, with a friendly label instead of raw
//  hex.
//

import Foundation

struct CardTag: Identifiable, Codable {
    var id: String { uniqueId }
    let uniqueId: String
    let label: String
}
