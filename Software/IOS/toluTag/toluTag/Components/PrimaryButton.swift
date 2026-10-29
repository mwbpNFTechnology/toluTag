//
//  PrimaryButton.swift
//  toluTag
//
//  A filled, full-width primary call-to-action button.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var accent: Color = Tolu.Palette.lime
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        accent: Color = Tolu.Palette.lime,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Tolu.Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? accent : Tolu.Palette.line2)
            )
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton("hold to scan", systemImage: "wave.3.right", accent: Tolu.Palette.violet) {}
        PrimaryButton("disabled", isEnabled: false) {}
    }
    .padding()
    .background(Tolu.Palette.ink)
}
