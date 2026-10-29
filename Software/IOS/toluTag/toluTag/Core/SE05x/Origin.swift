//
//  Origin.swift
//  toluTag
//
//  The SE05x object Origin attribute (spec Table 32): where the key came from.
//

import SwiftUI

enum Origin {
    case imported      // 0x01 - generated outside the module
    case onChip        // 0x02 - generated inside the module (random)
    case provisioned   // 0x03 - trust provisioned by NXP
    case unknown

    static func from(_ byte: UInt8) -> Origin {
        switch byte {
        case 0x01: return .imported
        case 0x02: return .onChip
        case 0x03: return .provisioned
        default: return .unknown
        }
    }

    var label: String {
        switch self {
        case .imported: return "imported"
        case .onChip: return "generated on-chip"
        case .provisioned: return "nxp provisioned"
        case .unknown: return "unknown"
        }
    }

    /// The SE05x enum name, as printed by the Java tooling.
    var name: String {
        switch self {
        case .imported: return "EXTERNAL"
        case .onChip: return "INTERNAL"
        case .provisioned: return "PROVISIONED"
        case .unknown: return "UNKNOWN"
        }
    }

    /// The full description, e.g. "generated on-chip (random)".
    var detail: String {
        switch self {
        case .imported: return "imported (generated outside the chip)"
        case .onChip: return "generated on-chip (random)"
        case .provisioned: return "NXP trust-provisioned"
        case .unknown: return "unknown"
        }
    }

    var color: Color {
        switch self {
        case .onChip: return Tolu.Palette.lime
        case .imported: return Tolu.Palette.amber
        case .provisioned: return Tolu.Palette.violet
        case .unknown: return Tolu.Palette.dim
        }
    }
}
