//
//  AppRoute.swift
//  toluTag
//
//  Every destination reachable through the app's single navigation stack.
//

import Foundation

/// Pre-fills the delete flow from a saved record's "delete" button. Carries the
/// PIN/UserID for a pin-protected key so the session can authorise the delete.
struct DeletePrefill: Hashable {
    let objectID: String
    let pinObjectID: String?
    let pin: String?
}

enum AppRoute: Hashable {
    // Top-level sections
    case write
    case read
    case keys

    // Write actions
    case createKey
    case writeText
    /// Delete an object. Optionally pre-filled from a saved record's "delete"
    /// button.
    case deleteObject(DeletePrefill?)

    // Read actions
    case scanTag
    case readText
    case signMessage
    case signTypedData
    case collectTags
}
