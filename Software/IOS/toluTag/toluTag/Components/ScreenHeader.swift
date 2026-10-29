//
//  ScreenHeader.swift
//  toluTag
//
//  Reusable top bar for pushed screens: a back chevron, a centered monospaced
//  title, and a hairline divider — matching the design's step navigation.
//

import SwiftUI

struct ScreenHeader: View {
    let title: String
    var accent: Color = Tolu.Palette.lime
    let onBack: () -> Void

    var body: some View {
        ZStack {
            MonoLabel(title, size: 11, color: Tolu.Palette.text, tracking: 2)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tolu.Palette.line)
                .frame(height: 1)
        }
    }
}

#Preview {
    ScreenHeader(title: "write") {}
        .background(Tolu.Palette.ink)
}
