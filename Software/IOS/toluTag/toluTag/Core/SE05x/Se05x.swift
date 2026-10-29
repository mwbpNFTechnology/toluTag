//
//  Se05x.swift
//  toluTag
//
//  Constants from the NXP SE05x IoT applet APDU specification (AN12543).
//

import Foundation

enum Se05x {
    /// AID of the SE05x IoT applet.
    static let aid: [UInt8] = [
        0xA0, 0x00, 0x00, 0x03, 0x96, 0x54, 0x53, 0x00,
        0x00, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00
    ]

    static let cla: UInt8 = 0x80          // no secure messaging
    static let claSecureMessaging: UInt8 = 0x84

    // Instructions
    static let insWrite: UInt8 = 0x01
    static let insRead: UInt8 = 0x02
    static let insCrypto: UInt8 = 0x03
    static let insMgmt: UInt8 = 0x04
    static let insProcess: UInt8 = 0x05      // process a command within a session
    static let insAttest: UInt8 = 0x20       // OR-ed into insRead for an attested read
    static let insAuthObject: UInt8 = 0x40   // OR-ed into insWrite for auth objects
    static let insInternalAuthenticate: UInt8 = 0x88

    // P1
    static let p1Default: UInt8 = 0x00
    static let p1EC: UInt8 = 0x01
    static let p1Binary: UInt8 = 0x06
    static let p1UserId: UInt8 = 0x07
    static let p1Curve: UInt8 = 0x0B
    static let p1Public: UInt8 = 0x20
    static let p1KeyPair: UInt8 = 0x60

    // P2
    static let p2Default: UInt8 = 0x00
    static let p2Create: UInt8 = 0x04
    static let p2Size: UInt8 = 0x07
    static let p2Version: UInt8 = 0x20
    static let p2Memory: UInt8 = 0x22
    static let p2Type: UInt8 = 0x26
    static let p2Exist: UInt8 = 0x27
    static let p2DeleteObject: UInt8 = 0x28
    static let p2Attributes: UInt8 = 0x3B
    static let p2Param: UInt8 = 0x40
    static let p2SessionCreate: UInt8 = 0x1B
    static let p2SessionUserId: UInt8 = 0x2C

    // Free-memory types (GetFreeMemory)
    static let memPersistent: UInt8 = 0x01
    static let memTransientReset: UInt8 = 0x02
    static let memTransientDeselect: UInt8 = 0x03
    static let freeMemorySaturated = 0x7FFF

    // Signing (ECDSA)
    static let p1Signature: UInt8 = 0x0C
    static let p2Sign: UInt8 = 0x09
    static let sigEcdsaSha256: UInt8 = 0x21

    // TLV tags
    static let tag1: UInt8 = 0x41         // object id / value
    static let tag2: UInt8 = 0x42         // curve id / parameter selector
    static let tag3: UInt8 = 0x43         // parameter value / file length / attributes
    static let tag4: UInt8 = 0x44         // binary file data
    static let tag5: UInt8 = 0x45         // attestation key
    static let tag6: UInt8 = 0x46         // attestation algorithm
    static let tag7: UInt8 = 0x47         // attestation freshness
    static let tagPolicy: UInt8 = 0x11
    static let tagSessionId: UInt8 = 0x10

    static let curveIdSecp256k1: UInt8 = 0x10
    static let curveIdNistP256: UInt8 = 0x03

    /// Reserved object id that returns the chip's factory unique identifier.
    static let reservedUniqueId: [UInt8] = [0x7F, 0xFF, 0x02, 0x06]
    /// The chip's own key pair for ECKey sessions (RESERVED_ID_ECKEY_SESSION).
    static let reservedECKeySession: [UInt8] = [0x7F, 0xFF, 0x02, 0x01]
    /// NXP's attestation key, present on every SE051 A and C.
    static let attestationKey: [UInt8] = [0xF0, 0x00, 0x00, 0x12]

    static let resultSuccess: UInt8 = 0x01
    static let swSuccessHigh: UInt8 = 0x90
    static let swSuccessLow: UInt8 = 0x00
}
