//
//  ToluTheme.swift
//  toluTag
//
//  The toluTag design system: palette, typography and metrics, derived from the
//  brand design (dark "ink" base with a lime accent, monospaced micro-labels and
//  lowercase headings with a colored period).
//

import SwiftUI

enum Tolu {

    /// Brand color palette.
    enum Palette {
        static let ink = Color(hex: 0x0A0B0E)     // app background
        static let ink2 = Color(hex: 0x111318)
        static let ink3 = Color(hex: 0x1A1D25)    // raised card
        static let ink4 = Color(hex: 0x22262F)
        static let line = Color(hex: 0x252932)    // hairline border
        static let line2 = Color(hex: 0x2F3440)

        static let dim = Color(hex: 0x6A6E78)      // faint text
        static let mute = Color(hex: 0x9CA0AA)     // secondary text
        static let text = Color(hex: 0xE8E9EC)     // primary text
        static let paper = Color(hex: 0xF4F2ED)

        static let lime = Color(hex: 0xC6F24E)     // primary accent / write
        static let limeDim = Color(hex: 0x8FB82C)
        static let violet = Color(hex: 0xA78BFA)   // nfc / read
        static let amber = Color(hex: 0xF5B13A)
        static let coral = Color(hex: 0xFB7185)
        static let teal = Color(hex: 0x2DD4BF)
        static let sky = Color(hex: 0x60A5FA)
    }

    /// Corner radii.
    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
        static let pill: CGFloat = 999
    }

    /// Common spacing.
    enum Spacing {
        static let screen: CGFloat = 22
    }
}

extension Font {
    /// Tight sans heading (SF Pro stands in for Inter Tight).
    static func toluTitle(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }

    /// Monospaced label (SF Mono stands in for JetBrains Mono).
    static func toluMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
