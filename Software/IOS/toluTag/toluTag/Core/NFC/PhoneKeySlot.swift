//
//  PhoneKeySlot.swift
//  toluTag
//
//  What the slot meant for this iPhone's key holds on a tag.
//

import Foundation

enum PhoneKeySlot {
    case free
    /// This iPhone's key is already there — written by an earlier wallet or
    /// an earlier try — and can be used as it is.
    case thisPhone
    /// Something else: another iPhone's key, or not a key at all.
    case taken
}
