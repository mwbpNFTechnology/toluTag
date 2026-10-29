//
//  Color+Hex.swift
//  toluTag
//
//  Convenience initializer for building colors from hex literals.
//

import SwiftUI

extension Color {
    /// Creates a color from a 24-bit RGB hex value, e.g. `Color(hex: 0xC6F24E)`.
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
