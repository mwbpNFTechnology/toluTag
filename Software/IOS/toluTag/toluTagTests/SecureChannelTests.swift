//
//  SecureChannelTests.swift
//  toluTagTests
//
//  The ECKey session's crypto: AES-CMAC against RFC 4493, and the session
//  keys, protected commands and decrypted answers against an independent
//  implementation written from NXP's Plug & Trust middleware (nxScp03_Com.c,
//  fsl_sss_se05x_eckey.c). Card answers below were made by that reference.
//

import Foundation
import Testing
@testable import toluTag

@MainActor
struct SecureChannelTests {

    private func bytes(_ hex: String) throws -> [UInt8] {
        try #require(Hex.bytes(hex))
    }

    @Test func cmacMatchesRfc4493() throws {
        let key = try bytes("2b7e151628aed2a6abf7158809cf4f3c")
        let message = try bytes("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51"
            + "30c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710")
        #expect(Hex.string(AesCmac.mac([], key: key)) == "bb1d6929e95937287fa37d129b756746")
        #expect(Hex.string(AesCmac.mac(Array(message.prefix(16)), key: key)) == "070a16b46b4d4144f79bdd9dd04a287c")
        #expect(Hex.string(AesCmac.mac(Array(message.prefix(40)), key: key)) == "dfa66747de9ae63030ca32611497c827")
        #expect(Hex.string(AesCmac.mac(message, key: key)) == "51f0bebf7e3b9d92fc49741779363cfe")
    }

    private func sessionKeys() throws -> ScpSessionKeys {
        ScpSessionKeys(sharedSecret: [UInt8](repeating: 0x5C, count: 32),
                       cardChallenge: try bytes("0102030405060708090a0b0c0d0e0f10"))
    }

    @Test func derivesTheSessionKeys() throws {
        let keys = try sessionKeys()
        #expect(Hex.string(keys.enc) == "925a8a2ac0ce40a0e9d73c7d911ca334")
        #expect(Hex.string(keys.mac) == "eec4750d680964192bf8cb5426948d22")
        #expect(Hex.string(keys.rmac) == "50d62f453b2bbfb20931601378bdf77d")
        #expect(Hex.string(keys.initialChainingValue) == "e7a3a1b1307eef744a282dbeaf8d5406")
    }

    /// Three commands in a row: the counter steps and the MAC chains.
    @Test func protectsCommandsAndOpensAnswers() throws {
        var channel = SecureChannel(keys: try sessionKeys())

        let read = channel.protect(cla: 0x80, ins: 0x02, p1: 0x00, p2: 0x00,
                                   data: try bytes("410400000003"), extendedLength: true)
        #expect(Hex.string(read) == "8402000000001830e658c720910eb7decc14f31b915d19413685974ef9375e")
        let answer = try channel.open(try bytes(
            "d3ddb1485444d50b4872ebd395e25b86524c2c4d51df391ea8d7a69e2fe6ec9f04f56a47f0553e7bc68d814f0889eedc"
            + "f0d031fff2be9bbae2b668867f6dd472d8b941c43cdc8943e1e1f8351c981e2e4709d34a689914a8"
        ), sw1: 0x90, sw2: 0x00, operation: "read")
        #expect(Hex.string(answer) == "414104" + String(repeating: "ab", count: 64))

        let write = channel.protect(
            cla: 0x80, ins: 0x01, p1: 0x61, p2: 0x00,
            data: try bytes("1109" + "08000000021820000041040000000142011043" + "20" + String(repeating: "11", count: 32)
                            + "4441" + "04" + String(repeating: "22", count: 64)),
            extendedLength: false
        )
        #expect(Hex.string(write) == "84016100886d4b1ec6f2e20eeae33461cbe67bdcc634824e9348be8faabd240eec3a12313f"
            + "b0ea0a353de689475cbbb3860485b72b64078b55f48267088ce2965546da57448185e72287e44c10acbe1352ce57d563dd"
            + "d238772dc5383a7dc08212d05fb747f5ea8552e344813c8c9261dcd582b509278b47c00ca0da86691e134abf93e0b8a75a"
            + "486c1c26bb7a")
        #expect(try channel.open(try bytes("8ea90aced232d8d7"), sw1: 0x90, sw2: 0x00, operation: "write").isEmpty)

        let empty = channel.protect(cla: 0x80, ins: 0x04, p1: 0x00, p2: 0x1C, data: [], extendedLength: false)
        #expect(Hex.string(empty) == "8404001c085681e46604a16208")
    }

    @Test func refusesAnAnswerThatDoesNotAuthenticate() throws {
        var channel = SecureChannel(keys: try sessionKeys())
        _ = channel.protect(cla: 0x80, ins: 0x02, p1: 0x00, p2: 0x00,
                            data: try bytes("410400000003"), extendedLength: true)
        var tampered = try bytes("d3ddb1485444d50b4872ebd395e25b86524c2c4d51df391ea8d7a69e2fe6ec9f04f56a47f0553e7b"
            + "c68d814f0889eedcf0d031fff2be9bbae2b668867f6dd472d8b941c43cdc8943e1e1f8351c981e2e4709d34a689914a8")
        tampered[3] ^= 0x01
        #expect(throws: Se05xError.self) {
            try channel.open(tampered, sw1: 0x90, sw2: 0x00, operation: "read")
        }
    }

    @Test func anErrorStatusThrows() throws {
        var channel = SecureChannel(keys: try sessionKeys())
        _ = channel.protect(cla: 0x80, ins: 0x02, p1: 0x00, p2: 0x00,
                            data: try bytes("410400000003"), extendedLength: true)
        #expect(throws: Se05xError.self) {
            try channel.open([], sw1: 0x69, sw2: 0x85, operation: "read")
        }
    }

    /// ECKeySessionInternalAuthenticate, laid out as AN12543 §3.6.3.3 and the
    /// middleware's nxECKey_InternalAuthenticate build it.
    @Test func buildsTheAuthenticateCommand() throws {
        let ephemeral = [UInt8(0x04)] + [UInt8](repeating: 0xEE, count: 64)
        let request = ECKeyAuthRequest(ephemeralPublicKey: ephemeral)
        let signedPart = "a61d" + "4f10a0000003965453000000010300000000" + "9003ab0133" + "800188" + "810110"
            + "7f4946" + "b041" + Hex.string(ephemeral) + "f00103"
        #expect(Hex.string(request.signedPart) == signedPart)
        let signature = [UInt8](repeating: 0x30, count: 71)
        #expect(Hex.string(request.data(signature: signature)) == signedPart + "5f3747" + Hex.string(signature))
    }

    /// InternalAuthenticate goes in with a 1-byte Lc and no Le, as the
    /// middleware sends it; the 3-byte form is answered with 6A80.
    @Test func wrapsTheAuthenticateCommandLikeTheMiddleware() {
        let body = ECKeyAuthRequest(ephemeralPublicKey: [UInt8(0x04)] + [UInt8](repeating: 0xEE, count: 64))
            .data(signature: [UInt8](repeating: 0x30, count: 71))
        let apdu = SessionApdu.unprotected(cla: 0x84, ins: 0x88, p1: 0x00, p2: 0x00, data: body)
        #expect(Array(apdu.prefix(5)) == [0x84, 0x88, 0x00, 0x00, UInt8(body.count)])
        #expect(apdu.count == 5 + body.count)
        #expect(SessionApdu.unprotected(cla: 0x80, ins: 0x04, p1: 0x00, p2: 0x1C, data: []) == [0x80, 0x04, 0x00, 0x1C])
    }

    @Test func encodesLongTlvLengths() {
        #expect(Tlv.encode(0x41, [UInt8](repeating: 1, count: 127)).prefix(2) == [0x41, 0x7F])
        #expect(Tlv.encode(0x41, [UInt8](repeating: 1, count: 200)).prefix(3) == [0x41, 0x81, 0xC8])
        #expect(Tlv.encode(0x41, [UInt8](repeating: 1, count: 300)).prefix(4) == [0x41, 0x82, 0x01, 0x2C])
    }
}
