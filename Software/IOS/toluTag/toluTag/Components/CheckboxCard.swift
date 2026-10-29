//
//  CheckboxCard.swift
//  toluTag
//
//  A bordered card with a lime checkbox, a title and a mono description — used
//  for options like "allow deleting this object later".
//

import SwiftUI

struct CheckboxCard: View {
    @Binding var isOn: Bool
    let title: String
    let detail: String
    var accent: Color = Tolu.Palette.lime

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? accent : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isOn ? accent : Tolu.Palette.line2, lineWidth: 1.5)
                        )
                        .frame(width: 26, height: 26)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tolu.Palette.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tolu.Palette.text)
                    Text(detail)
                        .font(.toluMono(9))
                        .foregroundStyle(Tolu.Palette.dim)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                    .fill(Tolu.Palette.ink2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                            .stroke(Tolu.Palette.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
