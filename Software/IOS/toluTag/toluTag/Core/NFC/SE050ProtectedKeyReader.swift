//
//  SE050ProtectedKeyReader.swift
//  toluTag
//
//  Authenticates with the UserID/PIN and reads back the protected public key.
//  Ported verbatim from the tolu app (the proven CoreNFC read path).
//

import Foundation
import CoreNFC
import Combine

enum ProtectedKeyReaderError: LocalizedError {
    case noNFCTag, unsupportedTagType, connectionError(Error)
    case appletSelectionFailed, sessionCreationFailed, authenticationFailed, publicKeyReadFailed

    var errorDescription: String? {
        switch self {
        case .noNFCTag: return "No NFC tag detected"
        case .unsupportedTagType: return "Unsupported tag type"
        case .connectionError(let e): return "Connection error: \(e.localizedDescription)"
        case .appletSelectionFailed: return "Failed to select SE050 applet"
        case .sessionCreationFailed: return "Failed to create authenticated session"
        case .authenticationFailed: return "PIN authentication failed"
        case .publicKeyReadFailed: return "Failed to read public key"
        }
    }
}

final class SE050ProtectedKeyReader: NSObject, ObservableObject {

    @Published var status: String = "Ready to read key"
    @Published var isSessionActive = false

    /// Called with the raw public-key hex (0x04 + 64 bytes) on success.
    var onFinish: ((Result<String, Error>) -> Void)?

    private struct C {
        static let appletAID: [UInt8] = [0xA0,0x00,0x00,0x03,0x96,0x54,0x53,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00]
        static let INS_READ: UInt8 = 0x02
        static let INS_MGMT: UInt8 = 0x04
        static let INS_PROCESS: UInt8 = 0x05
        static let P1_DEFAULT: UInt8 = 0x00
        static let P2_DEFAULT: UInt8 = 0x00
        static let P2_SESSION_CREATE: UInt8 = 0x1B
        static let P2_SESSION_USERID: UInt8 = 0x2C
        static let CLA_NO_SM: UInt8 = 0x80
        static let CLA_ISO: UInt8 = 0x00
        static let TAG_OBJECT_ID: UInt8 = 0x41
        static let TAG_SESSION_ID: UInt8 = 0x10
    }

    private var tagSession: NFCTagReaderSession?
    private var sessionId: Data?
    private var userIDObjectID = ""
    private var keyObjectID = ""
    private var pin = ""
    private var publicKey: Data?
    private var didFinish = false

    func read(userIDObjectID: String, keyObjectID: String, pin: String, alert: String) {
        self.userIDObjectID = userIDObjectID
        self.keyObjectID = keyObjectID
        self.pin = pin
        self.sessionId = nil
        self.publicKey = nil
        self.didFinish = false

        guard NFCTagReaderSession.readingAvailable else { finishFailure(ProtectedKeyReaderError.noNFCTag); return }
        tagSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main)
        tagSession?.alertMessage = alert
        tagSession?.begin()
        isSessionActive = true
    }

    private func hexBytes(_ hex: String) -> [UInt8]? {
        var hex = hex
        if hex.hasPrefix("0x") { hex = String(hex.dropFirst(2)) }
        guard hex.count % 2 == 0 else { return nil }
        var out: [UInt8] = []; var i = hex.startIndex
        while i < hex.endIndex { let n = hex.index(i, offsetBy: 2)
            guard let b = UInt8(hex[i..<n], radix: 16) else { return nil }; out.append(b); i = n }
        return out
    }

    private func fail(_ session: NFCTagReaderSession, _ error: ProtectedKeyReaderError) {
        status = error.localizedDescription
        isSessionActive = false
        session.invalidate(errorMessage: error.localizedDescription)
        finishFailure(error)
    }

    private func finishFailure(_ error: Error) {
        guard !didFinish else { return }; didFinish = true; onFinish?(.failure(error))
    }
}

extension SE050ProtectedKeyReader: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { isSessionActive = true }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        isSessionActive = false
        if publicKey == nil { finishFailure(error) }
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { fail(session, .noNFCTag); return }
        session.connect(to: tag) { error in
            if let error = error { self.fail(session, .connectionError(error)); return }
            guard case let .iso7816(isoTag) = tag else { self.fail(session, .unsupportedTagType); return }
            self.selectApplet(isoTag, session)
        }
    }
}

extension SE050ProtectedKeyReader {
    private func selectApplet(_ tag: NFCISO7816Tag, _ session: NFCTagReaderSession) {
        status = "Selecting SE050 applet..."
        let apdu = NFCISO7816APDU(instructionClass: C.CLA_ISO, instructionCode: 0xA4, p1Parameter: 0x04,
                                  p2Parameter: 0x00, data: Data(C.appletAID), expectedResponseLength: 256)
        tag.sendCommand(apdu: apdu) { _, sw1, sw2, error in
            if error != nil || !(sw1 == 0x90 && sw2 == 0x00) { self.fail(session, .appletSelectionFailed); return }
            self.createSession(tag, session)
        }
    }

    private func createSession(_ tag: NFCISO7816Tag, _ session: NFCTagReaderSession) {
        status = "Creating authenticated session..."
        guard let idBytes = hexBytes(userIDObjectID) else { fail(session, .sessionCreationFailed); return }
        var payload = Data([C.TAG_OBJECT_ID, UInt8(idBytes.count)]); payload.append(contentsOf: idBytes)
        let apdu = NFCISO7816APDU(instructionClass: C.CLA_NO_SM, instructionCode: C.INS_MGMT,
                                  p1Parameter: C.P1_DEFAULT, p2Parameter: C.P2_SESSION_CREATE,
                                  data: payload, expectedResponseLength: 256)
        tag.sendCommand(apdu: apdu) { response, sw1, sw2, _ in
            guard sw1 == 0x90 && sw2 == 0x00, self.extractSessionId(from: response) else {
                self.fail(session, .sessionCreationFailed); return
            }
            self.verifyUserID(tag, session)
        }
    }

    private func verifyUserID(_ tag: NFCISO7816Tag, _ session: NFCTagReaderSession) {
        status = "Authenticating with PIN..."
        let pinData = pin.data(using: .utf8)!
        var payload = Data([C.TAG_OBJECT_ID, UInt8(pinData.count)]); payload.append(pinData)
        let verify = NFCISO7816APDU(instructionClass: C.CLA_NO_SM, instructionCode: C.INS_MGMT,
                                    p1Parameter: C.P1_DEFAULT, p2Parameter: C.P2_SESSION_USERID,
                                    data: payload, expectedResponseLength: 256)
        processSession(verify, tag: tag) { _, sw1, sw2, _ in
            guard sw1 == 0x90 && sw2 == 0x00 else { self.fail(session, .authenticationFailed); return }
            self.readPublicKey(tag, session)
        }
    }

    private func readPublicKey(_ tag: NFCISO7816Tag, _ session: NFCTagReaderSession) {
        status = "Reading public key..."
        guard let keyBytes = hexBytes(keyObjectID) else { fail(session, .publicKeyReadFailed); return }
        var readData = Data([C.TAG_OBJECT_ID, 0x04]); readData.append(contentsOf: keyBytes)
        let apdu = NFCISO7816APDU(instructionClass: C.CLA_NO_SM, instructionCode: C.INS_READ,
                                  p1Parameter: C.P1_DEFAULT, p2Parameter: C.P2_DEFAULT,
                                  data: readData, expectedResponseLength: 256)
        processSession(apdu, tag: tag) { response, sw1, sw2, _ in
            guard sw1 == 0x90 && sw2 == 0x00, let pk = self.extractRawPublicKey(from: response) else {
                self.fail(session, .publicKeyReadFailed); return
            }
            self.publicKey = pk
            session.alertMessage = "Key verified ✓"
            session.invalidate()
            if !self.didFinish { self.didFinish = true; self.onFinish?(.success(pk.toHexString())) }
        }
    }

    // MARK: session wrapping
    private func processSession(_ command: NFCISO7816APDU, tag: NFCISO7816Tag,
                                completion: @escaping (Data, UInt8, UInt8, Error?) -> Void) {
        guard let sessionId = sessionId, let commandBytes = command.bytes else {
            completion(Data(), 0, 0, ProtectedKeyReaderError.sessionCreationFailed); return
        }
        var payload = Data([C.TAG_SESSION_ID, UInt8(sessionId.count)]); payload.append(sessionId)
        payload.append(C.TAG_OBJECT_ID); payload.append(UInt8(commandBytes.count)); payload.append(commandBytes)
        let apdu = NFCISO7816APDU(instructionClass: C.CLA_NO_SM, instructionCode: C.INS_PROCESS,
                                  p1Parameter: C.P1_DEFAULT, p2Parameter: C.P2_DEFAULT,
                                  data: payload, expectedResponseLength: 256)
        tag.sendCommand(apdu: apdu) { response, sw1, sw2, error in
            completion(self.extractWrapped(from: response), sw1, sw2, error)
        }
    }

    private func extractWrapped(from data: Data) -> Data {
        var index = 0
        while index < data.count - 2 {
            if data[index] == C.TAG_OBJECT_ID {
                var offset = index + 1; var length: Int
                if data[offset] == 0x82 && data.count > offset + 2 {
                    length = Int(data[offset + 1]) << 8 | Int(data[offset + 2]); offset += 3
                } else { length = Int(data[offset]); offset += 1 }
                if data.count >= offset + length { return data.subdata(in: offset..<(offset + length)) }
            }
            index += 1
        }
        return data
    }

    private func extractSessionId(from data: Data) -> Bool {
        guard data.count >= 2, data[0] == C.TAG_OBJECT_ID else { return false }
        var offset = 1; var length: Int
        if data[offset] == 0x82 && data.count > offset + 2 {
            length = Int(data[offset + 1]) << 8 | Int(data[offset + 2]); offset += 3
        } else { length = Int(data[offset]); offset += 1 }
        guard data.count >= offset + length else { return false }
        sessionId = data.subdata(in: offset..<(offset + length))
        return true
    }

    private func extractRawPublicKey(from data: Data) -> Data? {
        if data.count == 65 && data[0] == 0x04 { return data }
        guard data.count > 64 else { return nil }
        for i in 0..<(data.count - 64) where data[i] == 0x04 && i + 65 <= data.count {
            return data.subdata(in: i..<(i + 65))
        }
        return nil
    }
}

extension NFCISO7816APDU {
    var bytes: Data? {
        var out = Data([instructionClass, instructionCode, p1Parameter, p2Parameter])
        if let cmd = data, !cmd.isEmpty { out.append(UInt8(cmd.count)); out.append(cmd) }
        if expectedResponseLength > 0 && expectedResponseLength <= 256 {
            out.append(UInt8(expectedResponseLength == 256 ? 0 : expectedResponseLength))
        }
        return out
    }
}
