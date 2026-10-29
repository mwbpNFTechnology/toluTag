//
//  Se05xTag+ECKeySession.swift
//  toluTag
//
//  Opening an ECKey session (AN12543 §3.6.3.3), the way NXP's Plug & Trust
//  middleware does:
//
//    1. read the card's key-agreement public key (RESERVED_ID_ECKEY_SESSION)
//    2. CreateSession for the authentication object holding this iPhone's key
//    3. ECKeySessionInternalAuthenticate: a fresh P-256 key, signed by the
//       iPhone's Secure Enclave key; the card answers its challenge and a receipt
//    4. both sides derive the session keys from ECDH; the receipt proves the
//       card did — and only then is the session trusted
//

import CryptoKit
import Foundation
import Security

extension Se05xTag {

    /// After this every command runs encrypted, and only the objects whose
    /// policy names `authObjectId` are usable.
    func openECKeySession(authObjectId: [UInt8], signer: DeviceKeySigner) async throws {
        let cardKey = try await ecKeyAgreementPublicKey()
        let sessionId = try await createSession(authObjectId: authObjectId)

        let ephemeral = P256.KeyAgreement.PrivateKey()
        let request = ECKeyAuthRequest(ephemeralPublicKey: Array(ephemeral.publicKey.x963Representation))
        let response = try await executeUnprotected(
            sessionId: sessionId, cla: Se05x.claSecureMessaging, ins: Se05x.insInternalAuthenticate,
            p1: Se05x.p1Default, p2: Se05x.p2Default,
            data: request.data(signature: try signer.sign(request.signedPart)),
            operation: "open session"
        )
        guard let challenge = Tlv.findValue(response, tag: 0x85), challenge.count == 16,
              let receipt = Tlv.findValue(response, tag: 0x86), receipt.count == 16 else {
            throw Se05xError.secureChannelBroken
        }

        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: cardKey)
            .withUnsafeBytes { Array($0) }
        let keys = ScpSessionKeys(sharedSecret: sharedSecret, cardChallenge: challenge)
        guard AesCmac.mac(request.signedPart, key: keys.rmac) == receipt else {
            throw Se05xError.secureChannelBroken
        }
        beginSecureMessaging(sessionId: sessionId, keys: keys)
    }

    /// The card's static key for ECKey sessions. A plain read first; NXP's
    /// own code asks for it attested, which some configurations require.
    private func ecKeyAgreementPublicKey() async throws -> P256.KeyAgreement.PublicKey {
        let objectId = Tlv.encode(Se05x.tag1, Se05x.reservedECKeySession)
        var response = try? await transceive(cla: Se05x.cla, ins: Se05x.insRead,
                                             p1: Se05x.p1Default, p2: Se05x.p2Default,
                                             data: objectId, operation: "read session key")
        if response.flatMap({ Tlv.findValue($0, tag: Se05x.tag1) }) == nil {
            var freshness = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, freshness.count, &freshness)
            response = try await transceive(
                cla: Se05x.cla, ins: Se05x.insRead | Se05x.insAttest,
                p1: Se05x.p1Default, p2: Se05x.p2Default,
                data: objectId + Tlv.encode(Se05x.tag5, Se05x.attestationKey)
                    + Tlv.encode(Se05x.tag6, [Se05x.sigEcdsaSha256]) + Tlv.encode(Se05x.tag7, freshness),
                operation: "read session key"
            )
        }
        // The initializer checks the point is on P-256.
        guard let point = response.flatMap({ Tlv.findValue($0, tag: Se05x.tag1) }),
              let key = try? P256.KeyAgreement.PublicKey(x963Representation: point) else {
            throw Se05xError.noSessionKey
        }
        return key
    }
}
