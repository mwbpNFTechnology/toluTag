//
//  ToluCheckbox.swift
//  toluTag
//
//  A tappable checkbox row used for confirmations (e.g. irreversible delete).
//

import SwiftUI

struct ToluCheckbox: View {
    @Binding var isOn: Bool
    let title: String
    var accent: Color = Tolu.Palette.coral

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn ? accent : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isOn ? accent : Tolu.Palette.line2, lineWidth: 1.5)
                        )
                        .frame(width: 22, height: 22)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Tolu.Palette.ink)
                    }
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Tolu.Palette.mute)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
