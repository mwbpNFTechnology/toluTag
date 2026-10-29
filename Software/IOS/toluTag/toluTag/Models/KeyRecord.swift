//
//  KeyRecord.swift
//  toluTag
//
//  A key the user created on a tag, persisted (encrypted) in the Keychain.
//

import Foundation

struct KeyRecord: Identifiable, Codable {
    var id = UUID()
    let label: String
    let keyObjectID: String
    let pinObjectID: String?
    let publicKey: String?
    let address: String?
    /// The 6-digit signing PIN, if one was set. Stored encrypted in the Keychain;
    /// only revealed in the UI after a Face ID check.
    let pin: String?
    /// The slot holding this iPhone's public key, when the key is protected by
    /// an ECKey session instead of a PIN.
    let phoneKeyObjectID: String?
    /// Whether the key object was created with a DELETE policy, i.e. it can be
    /// removed from the tag later. Defaults to `false` (deletion-protected).
    let deletable: Bool
    /// The card's factory unique id (normalized hex). Distinguishes two physical
    /// tags that reuse the same object id. Nil for records saved before this.
    let uniqueId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, label, keyObjectID, pinObjectID, publicKey, address, pin, phoneKeyObjectID, deletable, uniqueId, createdAt
    }

    init(id: UUID = UUID(), label: String, keyObjectID: String, pinObjectID: String?,
         publicKey: String?, address: String?, pin: String?, phoneKeyObjectID: String? = nil,
         deletable: Bool, uniqueId: String? = nil, createdAt: Date) {
        self.id = id
        self.label = label
        self.keyObjectID = keyObjectID
        self.pinObjectID = pinObjectID
        self.publicKey = publicKey
        self.address = address
        self.pin = pin
        self.phoneKeyObjectID = phoneKeyObjectID
        self.deletable = deletable
        self.uniqueId = uniqueId
        self.createdAt = createdAt
    }

    /// Tolerant decode so records saved before a field existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decode(String.self, forKey: .label)
        keyObjectID = try c.decode(String.self, forKey: .keyObjectID)
        pinObjectID = try c.decodeIfPresent(String.self, forKey: .pinObjectID)
        publicKey = try c.decodeIfPresent(String.self, forKey: .publicKey)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        pin = try c.decodeIfPresent(String.self, forKey: .pin)
        phoneKeyObjectID = try c.decodeIfPresent(String.self, forKey: .phoneKeyObjectID)
        deletable = try c.decodeIfPresent(Bool.self, forKey: .deletable) ?? false
        uniqueId = try c.decodeIfPresent(String.self, forKey: .uniqueId)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
