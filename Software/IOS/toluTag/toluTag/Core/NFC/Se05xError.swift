//
//  Se05xError.swift
//  toluTag
//
//  Errors surfaced from the NFC / SE05x scan flow.
//

import Foundation

enum Se05xError: LocalizedError {
    case nfcUnavailable
    case notSupportedTag
    case apdu(String, UInt8, UInt8)
    case noKey
    /// The tag's ECKey-session key could not be read, so no session can be opened.
    case noSessionKey
    /// The card's receipt or a response MAC did not check out: someone is
    /// in between, or the tap broke mid-way.
    case secureChannelBroken
    /// The slot meant for this iPhone's key already holds a different key.
    case phoneKeySlotTaken
    case keySlotInUse

    var errorDescription: String? {
        switch self {
        case .nfcUnavailable:
            return "NFC is not available on this device."
        case .notSupportedTag:
            return "That isn't a supported tolu tag."
        case let .apdu(operation, sw1, sw2):
            return String(format: "%@ failed (SW=%02X%02X)", operation, sw1, sw2)
        case .noKey:
            return "No key found at this object id."
        case .noSessionKey:
            return "This tag can't open an encrypted session (its session key couldn't be read)."
        case .secureChannelBroken:
            return "The tag's answer didn't authenticate, so it was not trusted. Hold the tag still and try again."
        case .phoneKeySlotTaken:
            return "The phone key slot on this tag holds another iPhone's key. Choose another slot."
        case .keySlotInUse:
            return "That key object id is already used on this tag."
        }
    }
}
