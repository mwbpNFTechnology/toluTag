//
//  TagCollection.swift
//  toluTag
//
//  A saved list of tag addresses collected across many cards (the collect-tags
//  flow). Persisted in the Keychain so it can be re-exported anytime. Mirrors the
//  Java collectTags JSON output.
//

import Foundation

struct TagCollectionEntry: Identifiable, Codable {
    var id = UUID()
    let index: Int
    let tagId: String
    let address: String
    let value: String
    let phrase: String

    enum CodingKeys: String, CodingKey { case id, index, tagId, address, value, phrase }

    init(index: Int, tagId: String, address: String, value: String, phrase: String) {
        self.index = index; self.tagId = tagId; self.address = address; self.value = value; self.phrase = phrase
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        index = try c.decode(Int.self, forKey: .index)
        tagId = try c.decode(String.self, forKey: .tagId)
        address = try c.decode(String.self, forKey: .address)
        value = try c.decode(String.self, forKey: .value)
        phrase = try c.decode(String.self, forKey: .phrase)
    }
}

struct TagCollection: Identifiable, Codable {
    var id = UUID()
    let label: String
    let objectID: String
    let format: String
    let entries: [TagCollectionEntry]
    let createdAt: Date

    var count: Int { entries.count }

    /// The index the next tag added to this list gets.
    var nextIndex: Int { (entries.map(\.index).max() ?? -1) + 1 }

    /// One past the highest number in the list — where a `{count}` list carries on.
    var nextCount: Int { (entries.compactMap { Int($0.value) }.max() ?? -1) + 1 }

    enum CodingKeys: String, CodingKey { case id, label, objectID, format, entries, createdAt }

    init(id: UUID = UUID(), label: String, objectID: String, format: String,
         entries: [TagCollectionEntry], createdAt: Date) {
        self.id = id; self.label = label; self.objectID = objectID
        self.format = format; self.entries = entries; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decode(String.self, forKey: .label)
        objectID = try c.decode(String.self, forKey: .objectID)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        entries = try c.decodeIfPresent([TagCollectionEntry].self, forKey: .entries) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// The same list with `more` tags at the end.
    func appending(_ more: [TagCollectionEntry]) -> TagCollection {
        TagCollection(id: id, label: label, objectID: objectID, format: format,
                      entries: entries + more, createdAt: createdAt)
    }

    /// The `tags.json` document, matching the Java collectTags output.
    func exportJSON() -> String {
        var sb = "{\n"
        sb += "  \"objectId\": \"\(objectID)\",\n"
        sb += "  \"format\": \"\(format)\",\n"
        sb += "  \"count\": \(entries.count),\n"
        sb += "  \"tags\": ["
        for (i, e) in entries.enumerated() {
            sb += (i == 0 ? "\n" : ",\n")
            sb += "    {\"index\": \(e.index), \"tagId\": \"\(e.tagId)\", \"address\": \"\(e.address)\", "
                + "\"value\": \"\(e.value)\", \"phrase\": \"\(e.phrase)\"}"
        }
        sb += (entries.isEmpty ? "]\n" : "\n  ]\n")
        sb += "}\n"
        return sb
    }
}
