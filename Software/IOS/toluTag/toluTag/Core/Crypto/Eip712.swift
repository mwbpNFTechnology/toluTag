//
//  Eip712.swift
//  toluTag
//
//  EIP-712 typed-data parsing + encoding: computes the signing digest of any
//  eth_signTypedData_v4 document ({types, primaryType, domain, message}) per the
//  spec's encodeType / hashStruct rules, including nested structs and arrays.
//  Ported from the Java Eip712TypedData / Eip712Encoder.
//
//  digest = keccak256(0x19 || 0x01 || hashStruct(EIP712Domain, domain)
//                                  || hashStruct(primaryType, message)).
//

import Foundation

enum Eip712Error: LocalizedError {
    case invalidJson
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidJson: return "The typed-data JSON couldn't be parsed."
        case .message(let m): return m
        }
    }
}

struct Eip712TypedData {
    struct Field { let name: String; let type: String }

    let types: [String: [Field]]
    let primaryType: String
    let domain: [String: Any]
    let message: [String: Any]

    func isStruct(_ type: String) -> Bool { types[type] != nil }

    func fields(_ type: String) throws -> [Field] {
        guard let fields = types[type] else { throw Eip712Error.message("Unknown struct type: \(type)") }
        return fields
    }

    static func parse(_ json: String) throws -> Eip712TypedData {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Eip712Error.invalidJson
        }

        guard let typesRaw = root["types"] as? [String: Any] else {
            throw Eip712Error.message("typed data is missing a \"types\" object")
        }
        var types: [String: [Field]] = [:]
        for (typeName, value) in typesRaw {
            guard let list = value as? [Any] else {
                throw Eip712Error.message("types.\(typeName) must be an array")
            }
            types[typeName] = try list.map { element in
                guard let field = element as? [String: Any],
                      let name = field["name"] as? String, let type = field["type"] as? String else {
                    throw Eip712Error.message("Each field in types.\(typeName) needs string \"name\" and \"type\"")
                }
                return Field(name: name, type: type)
            }
        }

        guard let primary = root["primaryType"] as? String else {
            throw Eip712Error.message("typed data is missing a string \"primaryType\"")
        }
        guard types[primary] != nil else {
            throw Eip712Error.message("primaryType \"\(primary)\" is not defined in types")
        }
        guard types["EIP712Domain"] != nil else {
            throw Eip712Error.message("types is missing the EIP712Domain definition")
        }
        guard let domain = root["domain"] as? [String: Any] else {
            throw Eip712Error.message("Expected a JSON object for domain")
        }
        guard let message = root["message"] as? [String: Any] else {
            throw Eip712Error.message("Expected a JSON object for message")
        }
        return Eip712TypedData(types: types, primaryType: primary, domain: domain, message: message)
    }
}

enum Eip712Encoder {
    private static let word = 32
    private static let prefix: [UInt8] = [0x19, 0x01]

    /// The 32-byte EIP-712 signing digest.
    static func digest(_ td: Eip712TypedData) throws -> [UInt8] {
        let domainSeparator = try hashStruct("EIP712Domain", td.domain, td)
        let messageHash = try hashStruct(td.primaryType, td.message, td)
        return Keccak256.digest(prefix + domainSeparator + messageHash)
    }

    static func hashStruct(_ type: String, _ data: [String: Any], _ td: Eip712TypedData) throws -> [UInt8] {
        let head = try typeHash(type, td)
        let body = try encodeData(type, data, td)
        return Keccak256.digest(head + body)
    }

    static func typeHash(_ type: String, _ td: Eip712TypedData) throws -> [UInt8] {
        Keccak256.digest(Array(try encodeType(type, td).utf8))
    }

    /// The canonical type string: primary type first, then dependencies sorted.
    static func encodeType(_ primaryType: String, _ td: Eip712TypedData) throws -> String {
        var found = Set<String>()
        try collectDependencies(primaryType, td, &found)
        found.remove(primaryType)
        var result = try encodeOneType(primaryType, td)
        for dependency in found.sorted() {
            result += try encodeOneType(dependency, td)
        }
        return result
    }

    private static func collectDependencies(_ type: String, _ td: Eip712TypedData, _ found: inout Set<String>) throws {
        if found.contains(type) || !td.isStruct(type) { return }
        found.insert(type)
        for field in try td.fields(type) {
            try collectDependencies(structBaseType(field.type), td, &found)
        }
    }

    private static func encodeOneType(_ type: String, _ td: Eip712TypedData) throws -> String {
        let fields = try td.fields(type)
        let inner = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
        return "\(type)(\(inner))"
    }

    private static func encodeData(_ type: String, _ data: [String: Any], _ td: Eip712TypedData) throws -> [UInt8] {
        var out: [UInt8] = []
        for field in try td.fields(type) {
            out += try encodeValue(field.type, data[field.name], td)
        }
        return out
    }

    private static func encodeValue(_ type: String, _ value: Any?, _ td: Eip712TypedData) throws -> [UInt8] {
        if type.hasSuffix("]") {
            guard let bracket = type.lastIndex(of: "[") else { throw Eip712Error.message("Bad array type \(type)") }
            let elementType = String(type[type.startIndex..<bracket])
            guard let items = value as? [Any] else { throw Eip712Error.message("Expected an array for type \(type)") }
            var out: [UInt8] = []
            for item in items { out += try encodeValue(elementType, item, td) }
            return Keccak256.digest(out)
        }
        if td.isStruct(type) {
            guard let object = value as? [String: Any] else {
                throw Eip712Error.message("Expected an object for struct \(type)")
            }
            return try hashStruct(type, object, td)
        }
        return try encodeAtomic(type, value)
    }

    private static func encodeAtomic(_ type: String, _ value: Any?) throws -> [UInt8] {
        if type == "string" {
            return Keccak256.digest(Array(try asString(value).utf8))
        }
        if type == "bytes" {
            return Keccak256.digest(try hexBytes(asString(value)))
        }
        if type.hasPrefix("bytes") {
            return try fixedBytes(type, value)
        }
        if type == "address" {
            let bytes = try hexBytes(asString(value))
            guard bytes.count == 20 else { throw Eip712Error.message("address must be 20 bytes, got \(bytes.count)") }
            return try leftPadded(bytes)
        }
        if type == "bool" {
            var out = [UInt8](repeating: 0, count: word)
            out[word - 1] = try asBool(value) ? 1 : 0
            return out
        }
        if type.hasPrefix("uint") {
            return try integerWord(value, signed: false)
        }
        if type.hasPrefix("int") {
            return try integerWord(value, signed: true)
        }
        throw Eip712Error.message("Unsupported EIP-712 type: \(type)")
    }

    private static func fixedBytes(_ type: String, _ value: Any?) throws -> [UInt8] {
        guard let n = Int(type.dropFirst("bytes".count)) else {
            throw Eip712Error.message("Bad fixed-bytes type \(type)")
        }
        let bytes = try hexBytes(asString(value))
        guard bytes.count == n else { throw Eip712Error.message("\(type) expects \(n) bytes, got \(bytes.count)") }
        var out = [UInt8](repeating: 0, count: word)
        for i in 0..<n { out[i] = bytes[i] } // left-aligned, right zero-padded
        return out
    }

    /// Encodes an integer value (decimal or 0x-hex, optional leading `-` for
    /// signed types) into a 32-byte word.
    private static func integerWord(_ value: Any?, signed: Bool) throws -> [UInt8] {
        var text = try asString(value).trimmingCharacters(in: .whitespaces)
        let negative = text.hasPrefix("-")
        if negative {
            guard signed else { throw Eip712Error.message("Negative value for an unsigned type") }
            text = String(text.dropFirst())
        }
        let magnitude: BigUInt
        if text.hasPrefix("0x") || text.hasPrefix("0X") {
            guard let value = BigUInt(hex: text) else { throw Eip712Error.message("Bad hex integer \(text)") }
            magnitude = value
        } else {
            guard let value = BigUInt(decimalString: text) else { throw Eip712Error.message("Bad integer \(text)") }
            magnitude = value
        }
        if negative {
            let complement = BigUInt.twoPow256 - magnitude
            guard let bytes = complement.serialized(byteCount: word) else {
                throw Eip712Error.message("Value exceeds 32 bytes")
            }
            return [UInt8](bytes)
        }
        return try leftPadded(magnitude)
    }

    private static func leftPadded(_ magnitude: BigUInt) throws -> [UInt8] {
        guard let bytes = magnitude.serialized(byteCount: word) else {
            throw Eip712Error.message("Value exceeds 32 bytes")
        }
        return [UInt8](bytes)
    }

    private static func leftPadded(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count <= word else { throw Eip712Error.message("Value exceeds 32 bytes") }
        return [UInt8](repeating: 0, count: word - bytes.count) + bytes
    }

    // MARK: - Value coercion

    private static func asString(_ value: Any?) throws -> String {
        guard let value else { throw Eip712Error.message("Missing value") }
        if let s = value as? String { return s }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        return "\(value)"
    }

    private static func asBool(_ value: Any?) throws -> Bool {
        if let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
        return try asString(value).lowercased() == "true"
    }

    private static func hexBytes(_ value: String) throws -> [UInt8] {
        let body = value.hasPrefix("0x") || value.hasPrefix("0X") ? String(value.dropFirst(2)) : value
        guard let bytes = Hex.bytes(body) else { throw Eip712Error.message("Bad hex value") }
        return bytes
    }

    private static func structBaseType(_ type: String) -> String {
        guard let bracket = type.firstIndex(of: "[") else { return type }
        return String(type[type.startIndex..<bracket])
    }
}
