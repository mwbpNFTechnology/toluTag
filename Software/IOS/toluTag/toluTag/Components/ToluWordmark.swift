//
//  ToluWordmark.swift
//  toluTag
//
//  The "toluTag" wordmark with the signature accent dot.
//

import SwiftUI

struct ToluWordmark: View {
    var size: CGFloat = 17
    var accent: Color = Tolu.Palette.lime

    var body: some View {
        HStack(spacing: 3) {
            Text("tolu")
                .font(.toluTitle(size, weight: .semibold))
                .foregroundStyle(Tolu.Palette.text)
            Text("Tag")
                .font(.toluTitle(size, weight: .semibold))
                .foregroundStyle(Tolu.Palette.mute)
            Circle()
                .fill(accent)
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(y: size * 0.32)
        }
    }
}

#Preview {
    ToluWordmark()
        .padding()
        .background(Tolu.Palette.ink)
}
