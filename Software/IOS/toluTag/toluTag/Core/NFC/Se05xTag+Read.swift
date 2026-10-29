//
//  Se05xTag+Read.swift
//  toluTag
//
//  Read operations: unique id, public key, type, size, origin, existence.
//  These use `execute`, so they are automatically wrapped in a session when one
//  is open (needed for PIN-protected objects).
//

import Foundation

extension Se05xTag {

    func readUniqueId() async throws -> String {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Default,
                                         data: Tlv.encode(Se05x.tag1, Se05x.reservedUniqueId),
                                         extendedLength: true, operation: "read unique id")
        let value = Tlv.findValue(response, tag: Se05x.tag1) ?? response
        var hex = Hex.string(value)
        if hex.count < 40 { hex = String(repeating: "0", count: 40 - hex.count) + hex }
        return "0x" + hex
    }

    func readPublicKeyPoint(objectId: [UInt8]) async throws -> [UInt8] {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Default,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         extendedLength: true, operation: "read public key")
        var i = 0
        while i + 65 <= response.count {
            if response[i] == 0x04 { return Array(response[i..<i + 65]) }
            i += 1
        }
        throw Se05xError.noKey
    }

    func readType(objectId: [UInt8]) async throws -> String {
        return SecureObjectType.describe(try await readTypeByte(objectId: objectId))
    }

    /// Reads the raw SecureObjectType byte (decode with `SecureObjectType`).
    func readTypeByte(objectId: [UInt8]) async throws -> Int {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Type,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         operation: "read type")
        guard let typeByte = Tlv.findValue(response, tag: Se05x.tag1)?.first else {
            throw Se05xError.apdu("read type", 0, 0)
        }
        return Int(typeByte)
    }

    /// Reads and parses the full object attributes buffer (policy, origin, etc.).
    func readAttributes(objectId: [UInt8]) async throws -> ObjectAttributes {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Attributes,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         operation: "read attributes")
        guard let attributes = Tlv.findValue(response, tag: Se05x.tag3),
              let parsed = ObjectAttributes.parse(attributes) else {
            throw Se05xError.apdu("read attributes", 0, 0)
        }
        return parsed
    }

    /// Reads applet version information (GetVersion).
    func getVersion() async throws -> VersionInfo {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insMgmt,
                                         p1: Se05x.p1Default, p2: Se05x.p2Version,
                                         data: [], operation: "get version")
        return VersionInfo(raw: Tlv.findValue(response, tag: Se05x.tag1) ?? response)
    }

    /// Reads the free memory of the given type, in bytes.
    func getFreeMemory(_ memoryType: UInt8) async throws -> Int {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insMgmt,
                                         p1: Se05x.p1Default, p2: Se05x.p2Memory,
                                         data: Tlv.encode(Se05x.tag1, [memoryType]),
                                         operation: "get free memory")
        guard let value = Tlv.findValue(response, tag: Se05x.tag1), !value.isEmpty else {
            throw Se05xError.apdu("get free memory", 0, 0)
        }
        return value.reduce(0) { ($0 << 8) | Int($1) }
    }

    func readSize(objectId: [UInt8]) async throws -> Int {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Size,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         operation: "read size")
        guard let value = Tlv.findValue(response, tag: Se05x.tag1), !value.isEmpty else {
            throw Se05xError.apdu("read size", 0, 0)
        }
        return value.reduce(0) { ($0 << 8) | Int($1) }
    }

    func readOrigin(objectId: [UInt8]) async throws -> Origin {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Attributes,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         operation: "read attributes")
        guard let attributes = Tlv.findValue(response, tag: Se05x.tag3), attributes.count >= 19 else {
            throw Se05xError.apdu("read attributes", 0, 0)
        }
        return Origin.from(attributes[attributes.count - 5])
    }

    func exists(objectId: [UInt8]) async throws -> Bool {
        let response = try await transceive(cla: Se05x.cla, ins: Se05x.insMgmt,
                                            p1: Se05x.p1Default, p2: Se05x.p2Exist,
                                            data: Tlv.encode(Se05x.tag1, objectId),
                                            operation: "check exists")
        return Tlv.findValue(response, tag: Se05x.tag1)?.first == Se05x.resultSuccess
    }

    func readBinary(objectId: [UInt8]) async throws -> [UInt8] {
        let response = try await execute(cla: Se05x.cla, ins: Se05x.insRead,
                                         p1: Se05x.p1Default, p2: Se05x.p2Default,
                                         data: Tlv.encode(Se05x.tag1, objectId),
                                         extendedLength: true, operation: "read binary")
        return Tlv.findValue(response, tag: Se05x.tag1) ?? response
    }
}
