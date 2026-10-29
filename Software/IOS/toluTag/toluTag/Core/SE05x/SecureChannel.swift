//
//  SecureChannel.swift
//  toluTag
//
//  SCP03 secure messaging inside an ECKey session, byte for byte as NXP's
//  Plug & Trust middleware does it (nxScp03_Com.c, se05x_Transform_scp):
//
//  command: data padded (80 00…) and AES-CBC encrypted under S-ENC, the IV
//           being the encryption counter encrypted under S-ENC; CLA | 0x04;
//           then CMAC(S-MAC, chaining value ‖ header ‖ Lc ‖ data), whose
//           first 8 bytes are appended and whose 16 become the next
//           chaining value.
//  answer:  data ‖ R-MAC ‖ SW, where R-MAC = CMAC(S-RMAC, chaining value ‖
//           data ‖ SW); data decrypted with the IV 80 ‖ counter under S-ENC.
//  The counter steps after every answer, error or not.
//

import Foundation

struct SecureChannel: Sendable {
    private static let macLength = 8

    private let keys: ScpSessionKeys
    private var counter: [UInt8]
    private var chainingValue: [UInt8]

    init(keys: ScpSessionKeys) {
        self.keys = keys
        counter = [UInt8](repeating: 0, count: 15) + [0x01]
        chainingValue = keys.initialChainingValue
    }

    /// The protected command APDU, to be carried by ProcessSessionCmd.
    /// `extendedLength` picks the 3-byte Lc form, which the middleware uses
    /// only for its extended-length commands (ReadObject, GetRandom); every
    /// other command gets a 1-byte Lc.
    mutating func protect(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8,
                          data: [UInt8], extendedLength: Bool) -> [UInt8] {
        var body = data
        if !body.isEmpty {
            body.append(0x80)
            body += [UInt8](repeating: 0, count: (Aes128.blockSize - body.count % Aes128.blockSize) % Aes128.blockSize)
            let iv = Aes128.encryptBlock(counter, key: keys.enc)
            body = Aes128.cbcEncrypt(body, key: keys.enc, iv: iv)
        }

        let lc = body.count + Self.macLength
        var apdu = [cla | 0x04, ins, p1, p2]
        if lc < 0xFF && !extendedLength {
            apdu.append(UInt8(lc))
        } else {
            apdu += [0x00, UInt8(truncatingIfNeeded: lc >> 8), UInt8(truncatingIfNeeded: lc)]
        }
        apdu += body

        chainingValue = AesCmac.mac(chainingValue + apdu, key: keys.mac)
        return apdu + chainingValue.prefix(Self.macLength)
    }

    /// The plain answer data of the command `protect` last built. Throws
    /// when the card's MAC does not check out, or a status word other than
    /// 9000 comes back.
    mutating func open(_ response: [UInt8], sw1: UInt8, sw2: UInt8, operation: String) throws -> [UInt8] {
        defer { stepCounter() }
        // An error answer carries neither MAC nor data.
        guard sw1 == Se05x.swSuccessHigh, sw2 == Se05x.swSuccessLow else {
            throw Se05xError.apdu(operation, sw1, sw2)
        }
        guard !response.isEmpty else { return [] }
        guard response.count >= Self.macLength else { throw Se05xError.secureChannelBroken }

        let encrypted = Array(response.dropLast(Self.macLength))
        let expectedMac = AesCmac.mac(chainingValue + encrypted + [sw1, sw2], key: keys.rmac).prefix(Self.macLength)
        guard Self.constantTimeEqual(Array(expectedMac), Array(response.suffix(Self.macLength))) else {
            throw Se05xError.secureChannelBroken
        }
        guard !encrypted.isEmpty else { return [] }
        guard encrypted.count % Aes128.blockSize == 0 else { throw Se05xError.secureChannelBroken }

        var ivBlock = counter
        ivBlock[0] = 0x80
        let iv = Aes128.encryptBlock(ivBlock, key: keys.enc)
        let padded = Aes128.cbcDecrypt(encrypted, key: keys.enc, iv: iv)
        guard let plain = Self.unpadded(padded) else { throw Se05xError.secureChannelBroken }
        return plain
    }

    private mutating func stepCounter() {
        for index in stride(from: counter.count - 1, through: 0, by: -1) {
            counter[index] &+= 1
            if counter[index] != 0 { break }
        }
    }

    /// Strips ISO 9797-1 method 2 padding: zeros back to a 0x80, within the last block.
    private static func unpadded(_ data: [UInt8]) -> [UInt8]? {
        var index = data.count - 1
        while index >= 0, data.count - index <= Aes128.blockSize {
            if data[index] == 0x80 { return Array(data[..<index]) }
            guard data[index] == 0x00 else { return nil }
            index -= 1
        }
        return nil
    }

    private static func constantTimeEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
