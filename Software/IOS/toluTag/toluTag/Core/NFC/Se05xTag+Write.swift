//
//  Se05xTag+Write.swift
//  toluTag
//
//  Write operations: provision the curve, create a UserID / key pair, write a
//  binary file, and delete an object.
//

import Foundation

extension Se05xTag {

    /// Provisions the secp256k1 curve. Tolerant: a curve or parameter that is
    /// already present returns an error, which is ignored.
    func initializeSecp256k1Curve() async {
        _ = try? await transceive(cla: Se05x.cla, ins: Se05x.insWrite,
                                  p1: Se05x.p1Curve, p2: Se05x.p2Create,
                                  data: Tlv.encode(Se05x.tag1, [Secp256k1Curve.curveId]),
                                  operation: "create curve")
        for parameter in Secp256k1Curve.orderedParameters {
            let data = Tlv.encode(Se05x.tag1, [Secp256k1Curve.curveId])
                + Tlv.encode(Se05x.tag2, [parameter.selector])
                + Tlv.encode(Se05x.tag3, parameter.value)
            _ = try? await transceive(cla: Se05x.cla, ins: Se05x.insWrite,
                                      p1: Se05x.p1Curve, p2: Se05x.p2Param,
                                      data: data, operation: "set curve parameter")
        }
    }

    /// Creates a UserID Authentication Object holding the given PIN (4-16 bytes).
    func createUserId(objectId: [UInt8], pin: [UInt8]) async throws {
        let data = Tlv.encode(Se05x.tag1, objectId) + Tlv.encode(Se05x.tag2, pin)
        _ = try await transceive(cla: Se05x.cla, ins: Se05x.insWrite | Se05x.insAuthObject,
                                 p1: Se05x.p1UserId, p2: Se05x.p2Default,
                                 data: data, operation: "create user")
    }

    /// Creates a secp256k1 key pair. When `policy` is non-nil the key is bound to
    /// that policy (e.g. a PIN- or iPhone-key-protected key). Runs inside the
    /// open session, if any — inside an ECKey session the command is encrypted.
    func createSecp256k1KeyPair(objectId: [UInt8], policy: EcKeyPolicy?) async throws {
        var data: [UInt8] = []
        if let policy { data += policy.toTlv() }
        data += Tlv.encode(Se05x.tag1, objectId)
        data += Tlv.encode(Se05x.tag2, [Se05x.curveIdSecp256k1])
        _ = try await execute(cla: Se05x.cla, ins: Se05x.insWrite,
                              p1: Se05x.p1KeyPair | Se05x.p1EC, p2: Se05x.p2Default,
                              data: data, operation: "create key")
    }

    /// Provisions NIST P-256, the curve of the iPhone's key. Tolerant like the
    /// secp256k1 one, except that a dropped tap is reported.
    func initializeNistP256Curve() async throws {
        _ = try await send(cla: Se05x.cla, ins: Se05x.insWrite, p1: Se05x.p1Curve, p2: Se05x.p2Create,
                           data: Tlv.encode(Se05x.tag1, [NistP256Curve.curveId]))
        for parameter in NistP256Curve.orderedParameters {
            _ = try await send(cla: Se05x.cla, ins: Se05x.insWrite, p1: Se05x.p1Curve, p2: Se05x.p2Param,
                               data: Tlv.encode(Se05x.tag1, [NistP256Curve.curveId])
                                   + Tlv.encode(Se05x.tag2, [parameter.selector])
                                   + Tlv.encode(Se05x.tag3, parameter.value))
        }
    }

    /// Whether `authObjectId` is free, already holds `publicKey`, or holds
    /// something else. Authentication objects can be read by anyone (their
    /// default policy), so this needs no session.
    func phoneKeySlot(_ authObjectId: [UInt8], publicKey: [UInt8]) async throws -> PhoneKeySlot {
        guard try await exists(objectId: authObjectId) else { return .free }
        let response = try? await transceive(cla: Se05x.cla, ins: Se05x.insRead,
                                             p1: Se05x.p1Default, p2: Se05x.p2Default,
                                             data: Tlv.encode(Se05x.tag1, authObjectId),
                                             operation: "read phone key")
        let stored = response.flatMap { Tlv.findValue($0, tag: Se05x.tag1) }
        return stored == publicKey ? .thisPhone : .taken
    }

    /// WriteECKey of this iPhone's public key as an authentication object: no
    /// attempt limit (a signature can't be guessed) and the default policy,
    /// under which nobody may change or delete it.
    func writePhoneKey(_ authObjectId: [UInt8], publicKey: [UInt8]) async throws {
        try await transceive(cla: Se05x.cla, ins: Se05x.insWrite | Se05x.insAuthObject,
                             p1: Se05x.p1Public | Se05x.p1EC, p2: Se05x.p2Default,
                             data: PhoneKeyPayload.make(authObjectID: authObjectId, publicKey: publicKey),
                             operation: "write phone key")
    }

    /// Creates a new BinaryFile sized to `bytes` and writes it.
    func writeBinaryCreate(objectId: [UInt8], bytes: [UInt8], policy: EcKeyPolicy) async throws {
        let length: [UInt8] = [UInt8((bytes.count >> 8) & 0xFF), UInt8(bytes.count & 0xFF)]
        let data = policy.toTlv()
            + Tlv.encode(Se05x.tag1, objectId)
            + Tlv.encode(Se05x.tag3, length)
            + Tlv.encode(Se05x.tag4, bytes)
        _ = try await transceive(cla: Se05x.cla, ins: Se05x.insWrite,
                                 p1: Se05x.p1Binary, p2: Se05x.p2Default,
                                 data: data, operation: "write binary")
    }

    /// Overwrites an existing BinaryFile (must fit its original length).
    func writeBinaryUpdate(objectId: [UInt8], bytes: [UInt8]) async throws {
        let data = Tlv.encode(Se05x.tag1, objectId) + Tlv.encode(Se05x.tag4, bytes)
        _ = try await transceive(cla: Se05x.cla, ins: Se05x.insWrite,
                                 p1: Se05x.p1Binary, p2: Se05x.p2Default,
                                 data: data, operation: "update binary")
    }

    /// Deletes an object. When a UserID/PIN session is open the command is wrapped
    /// in it (via `execute`), so objects whose policy requires that auth can be
    /// removed. Returns `false` if the card refuses (e.g. the object is
    /// deletion-protected or the session isn't authorised for it).
    func deleteObject(objectId: [UInt8]) async throws -> Bool {
        do {
            _ = try await execute(cla: Se05x.cla, ins: Se05x.insMgmt,
                                  p1: Se05x.p1Default, p2: Se05x.p2DeleteObject,
                                  data: Tlv.encode(Se05x.tag1, objectId),
                                  operation: "delete")
            return true
        } catch Se05xError.apdu {
            return false
        }
    }
}
