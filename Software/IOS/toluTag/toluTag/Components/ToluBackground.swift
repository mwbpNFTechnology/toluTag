//
//  ToluBackground.swift
//  toluTag
//
//  Full-bleed app background: the ink base with a faint lime glow at the top.
//

import SwiftUI

struct ToluBackground: View {
    var body: some View {
        ZStack {
            Tolu.Palette.ink
            RadialGradient(
                colors: [Tolu.Palette.lime.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ToluBackground()
}
