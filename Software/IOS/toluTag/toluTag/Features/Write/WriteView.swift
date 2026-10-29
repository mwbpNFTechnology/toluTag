//
//  WriteView.swift
//  toluTag
//
//  The write menu: create a key, a PIN-protected key, store text, or delete an
//  object.
//

import SwiftUI

struct WriteView: View {
    @Environment(Router.self) private var router
    @State private var model = WriteViewModel()

    var body: some View {
        MenuScreen(
            headerTitle: "write",
            heading: "write",
            subtitle: "provision a key or store data on a tolu tag over nfc.",
            accent: Tolu.Palette.lime,
            items: model.items,
            onBack: { router.pop() },
            onSelect: { router.push($0.route) }
        )
    }
}

#Preview {
    NavigationStack {
        WriteView()
            .environment(Router())
    }
    .preferredColorScheme(.dark)
    .tint(Tolu.Palette.lime)
}
