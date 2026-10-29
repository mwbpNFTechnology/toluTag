//
//  ActionButton.swift
//  toluTag
//
//  A large, reusable action-card button (used for Write / Read on the home
//  screen and reusable for any primary destination).
//

import SwiftUI

struct ActionButton: View {
    let index: String          // e.g. "01"
    let title: String          // e.g. "write"
    let subtitle: String
    let systemImage: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                iconBadge
                textBlock
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tolu.Palette.dim)
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(PressableCardStyle())
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tolu.Radius.control, style: .continuous)
                .fill(accent.opacity(0.12))
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(width: 52, height: 52)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            MonoLabel("\(index) · \(title)", size: 9, tracking: 2)
            ToluHeading(text: title, size: 22, accent: accent)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Tolu.Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
            .fill(Tolu.Palette.ink3)
            .overlay(
                RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                    .stroke(Tolu.Palette.line, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        ActionButton(
            index: "01",
            title: "write",
            subtitle: "create a key or store data on a tag",
            systemImage: "square.and.pencil",
            accent: Tolu.Palette.lime
        ) {}
        ActionButton(
            index: "02",
            title: "read",
            subtitle: "scan a tag to inspect keys and data",
            systemImage: "dot.radiowaves.left.and.right",
            accent: Tolu.Palette.violet
        ) {}
    }
    .padding()
    .background(Tolu.Palette.ink)
}
