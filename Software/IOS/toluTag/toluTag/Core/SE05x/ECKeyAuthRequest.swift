//
//  ECKeyAuthRequest.swift
//  toluTag
//
//  The body of ECKeySessionInternalAuthenticate (84 88 00 00), which proves
//  to the card that this iPhone holds the private half of the ECKey
//  authentication object the session was created for:
//
//    A6 1D  4F 10 <applet AID>  90 03 AB 01 33  80 01 88  81 01 10
//    7F49 46  B0 41 <ephemeral P-256 public key>  F0 01 03
//    5F37 <n> <ECDSA-SHA256 signature over the two TLVs above, by the iPhone's key>
//
//  The card answers 85 10 <its challenge> 86 10 <receipt>, the receipt
//  being CMAC(S-RMAC, the two signed TLVs).
//

import Foundation

struct ECKeyAuthRequest: Sendable {
    /// What the iPhone signs, and what the card's receipt covers.
    let signedPart: [UInt8]

    /// - Parameter ephemeralPublicKey: `04 ‖ X ‖ Y` of a P-256 key made for
    ///   this session alone.
    init(ephemeralPublicKey: [UInt8]) {
        let controlReference = Tlv.encode(0x4F, Se05x.aid)
            + Tlv.encode(0x90, [0xAB] + ScpSessionKeys.scpParameters)
            + Tlv.encode(0x80, [ScpSessionKeys.keyType])
            + Tlv.encode(0x81, [ScpSessionKeys.keyLength])
        let publicKeyTemplate = Tlv.encode(0xB0, ephemeralPublicKey)
            + Tlv.encode(0xF0, [Se05x.curveIdNistP256])
        signedPart = Tlv.encode(0xA6, controlReference)
            + [0x7F, 0x49] + Tlv.length(publicKeyTemplate.count) + publicKeyTemplate
    }

    /// The whole command body, with the iPhone's DER signature appended.
    func data(signature: [UInt8]) -> [UInt8] {
        signedPart + [0x5F, 0x37] + Tlv.length(signature.count) + signature
    }
}
