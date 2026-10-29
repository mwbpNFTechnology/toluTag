//
//  ToluHeading.swift
//  toluTag
//
//  A lowercase heading with the signature colored period, e.g. "write."
//  Multi-line text is supported (use "\n").
//

import SwiftUI

struct ToluHeading: View {
    let text: String
    var size: CGFloat = 34
    var accent: Color = Tolu.Palette.lime

    var body: some View {
        (
            Text(text).foregroundStyle(Tolu.Palette.text)
            + Text(".").foregroundStyle(accent)
        )
        .font(.toluTitle(size))
        .tracking(-0.5)
        .lineSpacing(2)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ToluHeading(text: "write")
        ToluHeading(text: "read", accent: Tolu.Palette.violet)
        ToluHeading(text: "read & write\nsecure tags", size: 34)
    }
    .padding()
    .background(Tolu.Palette.ink)
}
