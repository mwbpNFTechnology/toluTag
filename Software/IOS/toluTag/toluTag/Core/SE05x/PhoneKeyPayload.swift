//
//  PhoneKeyPayload.swift
//  toluTag
//
//  The body of the WriteECKey (80 41 21 00) that stores an iPhone's P-256
//  public key as an ECKey authentication object. No policy and no attempt
//  limit: the defaults let anyone read the key and nobody change or delete
//  it. tolu_cold sends the same bytes; the tests on both sides pin them.
//

import Foundation

enum PhoneKeyPayload {

    /// - Parameters:
    ///   - authObjectID: the slot for the authentication object (4 bytes).
    ///   - publicKey: `04 ‖ X ‖ Y` on NIST P-256.
    static func make(authObjectID: [UInt8], publicKey: [UInt8]) -> [UInt8] {
        Tlv.encode(Se05x.tag1, authObjectID)
            + Tlv.encode(Se05x.tag2, [Se05x.curveIdNistP256])
            + Tlv.encode(Se05x.tag4, publicKey)
    }
}
