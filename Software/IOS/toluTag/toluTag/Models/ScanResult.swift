//
//  ScanResult.swift
//  toluTag
//
//  Everything a scan reports, mirroring the Java scanDetails tool: chip-level
//  details (unique id / version / features / free memory) and, when an object id
//  is given, per-object details (type / size / origin / policy / attributes and,
//  for EC keys, the public point + address). Fields are optional because each
//  read is best-effort.
//

import Foundation

struct ScanResult {
    var chip: ChipDetails
    var object: ObjectDetails?
    /// The label of a saved record matching the object id, if any.
    var matchedLabel: String?

    var isCardOnly: Bool { object == nil }

    struct ChipDetails {
        var uniqueId: String?
        var appletVersionRaw: String?
        var appletVersion: String?
        var secureBoxVersion: Int?
        var features: [String]?
        var persistentFreeMemory: Int?
        var transientResetFreeMemory: Int?
        var transientDeselectFreeMemory: Int?
    }

    struct ObjectDetails {
        var objectId: String
        var exists: Bool
        var type: String?
        var typeByte: Int?
        var sizeBytes: Int?
        var origin: Origin?
        var isAuthenticationObject: Bool?
        var versionAttribute: UInt64?
        var policyRaw: String?
        var attributesRaw: String?
        var deletable: Bool?
        var publicKey: String?
        var address: String?
        var text: String?
    }
}
