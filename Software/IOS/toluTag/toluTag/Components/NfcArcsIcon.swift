//
//  NfcArcsIcon.swift
//  toluTag
//
//  The toluTag NFC glyph — three quad-curve "signal" waves, matching the tolu
//  design system.
//

import SwiftUI

struct NfcArcsIcon: View {
    var size: CGFloat = 20
    var color: Color = Tolu.Palette.violet

    var body: some View {
        Canvas { context, _ in
            let s = size
            let stroke = StrokeStyle(lineWidth: 1.2 * (s / 16), lineCap: .round)

            func wave(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint, opacity: Double = 1) {
                var path = Path()
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
                context.stroke(path, with: .color(color.opacity(opacity)), style: stroke)
            }

            wave(CGPoint(x: s * 0.25, y: s * 0.22), CGPoint(x: s * 0.55, y: s * 0.5), CGPoint(x: s * 0.25, y: s * 0.78))
            wave(CGPoint(x: s * 0.47, y: s * 0.12), CGPoint(x: s * 0.90, y: s * 0.5), CGPoint(x: s * 0.47, y: s * 0.88))
            wave(CGPoint(x: s * 0.69, y: s * 0.05), CGPoint(x: s * 1.18, y: s * 0.5), CGPoint(x: s * 0.69, y: s * 0.95), opacity: 0.5)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    NfcArcsIcon(size: 60)
        .padding(40)
        .background(Tolu.Palette.ink)
}
