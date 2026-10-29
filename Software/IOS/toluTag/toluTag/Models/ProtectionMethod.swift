//
//  ProtectionMethod.swift
//  toluTag
//
//  How a protected key is unlocked: a PIN sent to the tag, or this iPhone's
//  Secure Enclave key, which opens an encrypted ECKey session.
//

import Foundation

enum ProtectionMethod: CaseIterable, Identifiable {
    case pin
    case ecKey

    var id: Self { self }

    var title: String {
        switch self {
        case .pin: "pin"
        case .ecKey: "eckey"
        }
    }
}
