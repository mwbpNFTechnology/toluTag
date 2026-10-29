//
//  MonoLabel.swift
//  toluTag
//
//  Small uppercase monospaced micro-label used throughout the app
//  (e.g. "SECP256K1 · SE05x", "◉ READY").
//

import SwiftUI

struct MonoLabel: View {
    private let text: String
    private let size: CGFloat
    private let color: Color
    private let tracking: CGFloat

    init(
        _ text: String,
        size: CGFloat = 10,
        color: Color = Tolu.Palette.dim,
        tracking: CGFloat = 1.6
    ) {
        self.text = text
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased())
            .font(.toluMono(size))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MonoLabel("SECP256K1 · SE05x")
        MonoLabel("◉ READY", color: Tolu.Palette.lime, tracking: 2)
    }
    .padding()
    .background(Tolu.Palette.ink)
}
