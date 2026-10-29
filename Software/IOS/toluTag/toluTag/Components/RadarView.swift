//
//  RadarView.swift
//  toluTag
//
//  Animated concentric rings with a violet NFC puck at the center — the scan
//  hero from the tolu design.
//

import SwiftUI

struct RadarView: View {
    @State private var animate = false
    private let diameters: [CGFloat] = [340, 260, 180, 120]

    var body: some View {
        ZStack {
            ForEach(Array(diameters.enumerated()), id: \.offset) { index, diameter in
                ring(diameter: diameter,
                     isDashed: index == 0,
                     opacity: 0.9 - Double(index) * 0.12,
                     delay: Double(index) * 0.3)
            }
            centerPuck
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animate = true }
    }

    private func ring(diameter: CGFloat, isDashed: Bool, opacity: Double, delay: Double) -> some View {
        Circle()
            .stroke(
                Tolu.Palette.line2.opacity(opacity),
                style: StrokeStyle(lineWidth: 1, dash: isDashed ? [4, 4] : [])
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate ? 1.08 : 0.96)
            .opacity(animate ? 0 : 0.5)
            .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay), value: animate)
    }

    private var centerPuck: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Tolu.Palette.violet, Color(hex: 0x5B3EC9), Color(hex: 0x1B1130)],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 86, height: 86)
                .shadow(color: Tolu.Palette.violet.opacity(0.45), radius: 20)

            NfcArcsIcon(size: 36, color: .white)
        }
    }
}

#Preview {
    RadarView()
        .frame(height: 320)
        .background(Tolu.Palette.ink)
}
