//
//  StringRecord.swift
//  toluTag
//
//  A string the user stored on a tag, persisted (encrypted) in the Keychain.
//

import Foundation

struct StringRecord: Identifiable, Codable {
    var id = UUID()
    let label: String
    let objectID: String
    let text: String
    /// Whether the binary object was created with a DELETE policy, i.e. it can
    /// be removed from the tag later. Text defaults to deletable.
    let deletable: Bool
    /// The card's factory unique id (normalized hex). Distinguishes two physical
    /// tags that reuse the same object id. Nil for records saved before this.
    let uniqueId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, label, objectID, text, deletable, uniqueId, createdAt
    }

    init(id: UUID = UUID(), label: String, objectID: String, text: String,
         deletable: Bool, uniqueId: String? = nil, createdAt: Date) {
        self.id = id
        self.label = label
        self.objectID = objectID
        self.text = text
        self.deletable = deletable
        self.uniqueId = uniqueId
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decode(String.self, forKey: .label)
        objectID = try c.decode(String.self, forKey: .objectID)
        text = try c.decode(String.self, forKey: .text)
        deletable = try c.decodeIfPresent(Bool.self, forKey: .deletable) ?? true
        uniqueId = try c.decodeIfPresent(String.self, forKey: .uniqueId)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
