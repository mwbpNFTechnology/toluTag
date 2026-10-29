//
//  InfoRow.swift
//  toluTag
//
//  A labeled, selectable value row used in result cards (mono value under a
//  mono micro-label).
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = Tolu.Palette.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoLabel(label, size: 9, color: Tolu.Palette.dim, tracking: 1.6)
            Text(value)
                .font(.toluMono(12))
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack(spacing: 14) {
        InfoRow(label: "ethereum address", value: "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf",
                valueColor: Tolu.Palette.lime)
        InfoRow(label: "tag id", value: "0x00000000000000000000000000000000abcd1234")
    }
    .padding()
    .background(Tolu.Palette.ink)
}
