//
//  ReadView.swift
//  toluTag
//
//  The read menu: scan a tag, read text, sign a message, sign typed data, or
//  batch-collect addresses.
//

import SwiftUI

struct ReadView: View {
    @Environment(Router.self) private var router
    @State private var model = ReadViewModel()

    var body: some View {
        MenuScreen(
            headerTitle: "read",
            heading: "read",
            subtitle: "hold a tolu tag near the phone to read its keys and sign.",
            accent: Tolu.Palette.violet,
            items: model.items,
            onBack: { router.pop() },
            onSelect: { router.push($0.route) }
        )
    }
}

#Preview {
    NavigationStack {
        ReadView()
            .environment(Router())
    }
    .preferredColorScheme(.dark)
    .tint(Tolu.Palette.violet)
}
