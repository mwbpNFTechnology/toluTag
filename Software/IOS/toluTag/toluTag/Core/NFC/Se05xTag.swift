//
//  Se05xTag.swift
//  toluTag
//
//  One SE05x tag in an open NFC session. Commands run plain, or inside an
//  applet session: a PIN (UserID) session, or an encrypted ECKey session
//  opened with this iPhone's Secure Enclave key.
//

import CoreNFC
import Foundation

final class Se05xTag {
    private enum Session {
        /// Plain wrapping: the PIN proved who is asking, but nothing is encrypted.
        case userId(id: [UInt8])
        /// SCP03 secure messaging under keys from the ECKey authentication.
        case ecKey(id: [UInt8], channel: SecureChannel)
    }

    let tag: NFCISO7816Tag
    private var session: Session?

    var hasSession: Bool { session != nil }

    init(_ tag: NFCISO7816Tag) {
        self.tag = tag
    }

    /// Selects the SE05x IoT applet. Must be called before any other command.
    func selectApplet() async throws {
        _ = try await transceive(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00,
                                 data: Se05x.aid, operation: "select applet")
    }

    /// Opens an authenticated session against a UserID and verifies its PIN.
    /// Afterwards `execute` wraps commands so protected objects can be read.
    func openUserIdSession(userObjectId: [UInt8], pin: [UInt8]) async throws {
        let sessionId = try await createSession(authObjectId: userObjectId)
        session = .userId(id: sessionId)
        _ = try await execute(cla: Se05x.cla, ins: Se05x.insMgmt,
                              p1: Se05x.p1Default, p2: Se05x.p2SessionUserId,
                              data: Tlv.encode(Se05x.tag1, pin),
                              operation: "verify pin")
    }

    /// CreateSession: an 8-byte session id for `authObjectId`. The session
    /// is not open until its authentication has passed.
    func createSession(authObjectId: [UInt8]) async throws -> [UInt8] {
        let response = try await transceive(cla: Se05x.cla, ins: Se05x.insMgmt,
                                            p1: Se05x.p1Default, p2: Se05x.p2SessionCreate,
                                            data: Tlv.encode(Se05x.tag1, authObjectId),
                                            operation: "create session")
        guard let sessionId = Tlv.findValue(response, tag: Se05x.tag1), sessionId.count == 8 else {
            throw Se05xError.apdu("create session", 0, 0)
        }
        return sessionId
    }

    /// From here on every command is encrypted and authenticated.
    func beginSecureMessaging(sessionId: [UInt8], keys: ScpSessionKeys) {
        session = .ecKey(id: sessionId, channel: SecureChannel(keys: keys))
    }

    /// Runs a command — plain, or inside whatever session is open.
    /// `extendedLength` only shapes a wrapped ECKey command's Lc, the way
    /// NXP's middleware does: three bytes for its extended-length commands
    /// (ReadObject), one for everything else.
    @discardableResult
    func execute(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: [UInt8],
                 extendedLength: Bool = false, operation: String) async throws -> [UInt8] {
        switch session {
        case nil:
            return try await transceive(cla: cla, ins: ins, p1: p1, p2: p2, data: data, operation: operation)

        case .userId(let sessionId):
            let inner = Self.apduBytes(cla: cla, ins: ins, p1: p1, p2: p2, data: data)
            let response = try await transceive(cla: Se05x.cla, ins: Se05x.insProcess,
                                                p1: Se05x.p1Default, p2: Se05x.p2Default,
                                                data: Self.processSessionData(sessionId, inner),
                                                operation: operation)
            return Tlv.findValue(response, tag: Se05x.tag1) ?? response

        case .ecKey(let sessionId, var channel):
            let inner = channel.protect(cla: cla, ins: ins, p1: p1, p2: p2,
                                        data: data, extendedLength: extendedLength)
            session = .ecKey(id: sessionId, channel: channel)
            let (response, sw1, sw2) = try await send(cla: Se05x.cla, ins: Se05x.insProcess,
                                                      p1: Se05x.p1Default, p2: Se05x.p2Default,
                                                      data: Self.processSessionData(sessionId, inner))
            defer { session = .ecKey(id: sessionId, channel: channel) }
            return try channel.open(response, sw1: sw1, sw2: sw2, operation: operation)
        }
    }

    /// Runs one command inside a session that is still being authenticated:
    /// wrapped (see `SessionApdu`), but not yet protected.
    func executeUnprotected(sessionId: [UInt8], cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8,
                            data: [UInt8], operation: String) async throws -> [UInt8] {
        let inner = SessionApdu.unprotected(cla: cla, ins: ins, p1: p1, p2: p2, data: data)
        return try await transceive(cla: Se05x.cla, ins: Se05x.insProcess,
                                    p1: Se05x.p1Default, p2: Se05x.p2Default,
                                    data: Self.processSessionData(sessionId, inner),
                                    operation: operation)
    }

    /// Sends one raw APDU and returns its response data, throwing on a non-0x9000
    /// status word.
    @discardableResult
    func transceive(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8,
                    data: [UInt8], operation: String) async throws -> [UInt8] {
        let (response, sw1, sw2) = try await send(cla: cla, ins: ins, p1: p1, p2: p2, data: data)
        guard sw1 == Se05x.swSuccessHigh, sw2 == Se05x.swSuccessLow else {
            throw Se05xError.apdu(operation, sw1, sw2)
        }
        return response
    }

    /// Sends one raw APDU. Only a broken tap throws; the status word is the
    /// caller's to judge.
    func send(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8,
              data: [UInt8]) async throws -> (data: [UInt8], sw1: UInt8, sw2: UInt8) {
        let apdu = NFCISO7816APDU(
            instructionClass: cla, instructionCode: ins,
            p1Parameter: p1, p2Parameter: p2,
            data: Data(data), expectedResponseLength: 256
        )
        let (response, sw1, sw2): (Data, UInt8, UInt8) = try await withCheckedThrowingContinuation { continuation in
            tag.sendCommand(apdu: apdu) { responseData, sw1, sw2, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (responseData, sw1, sw2))
                }
            }
        }
        return ([UInt8](response), sw1, sw2)
    }

    /// ProcessSessionCmd's payload: the session id, then the command it carries.
    private static func processSessionData(_ sessionId: [UInt8], _ inner: [UInt8]) -> [UInt8] {
        Tlv.encode(Se05x.tagSessionId, sessionId) + Tlv.encode(Se05x.tag1, inner)
    }

    /// Builds the raw bytes of an inner command APDU (header, Lc, data, Le=256).
    private static func apduBytes(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [cla, ins, p1, p2]
        if !data.isEmpty {
            out.append(UInt8(data.count))
            out += data
        }
        out.append(0x00) // Le
        return out
    }
}
