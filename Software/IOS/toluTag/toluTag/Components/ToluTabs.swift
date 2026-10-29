//
//  ToluTabs.swift
//  toluTag
//
//  Equal-width tabs in a dark pill, for picking one of a few options — how a
//  key is protected, or whether collect tags starts a new list.
//

import SwiftUI

struct ToluTabs<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var accent: Color = Tolu.Palette.lime

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? Tolu.Palette.ink : Tolu.Palette.mute)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(selected ? accent : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
    }
}

#Preview {
    ToluTabs(options: ProtectionMethod.allCases, selection: .constant(.ecKey), title: \.title)
        .padding()
        .background(Tolu.Palette.ink)
}
