//
//  DeviceKeyError.swift
//  toluTag
//

import Foundation

enum DeviceKeyError: LocalizedError {
    case noSecureEnclave
    case authenticationUnavailable
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noSecureEnclave:
            return "This device has no Secure Enclave, so it can't hold the key that unlocks a tag. Use a real iPhone."
        case .authenticationUnavailable:
            return "Set up Face ID or a device passcode: the tag only works for this iPhone after you unlock it."
        case .keychain(let status):
            return "The Keychain refused the iPhone's key (\(status))."
        }
    }
}
