//
//  RootView.swift
//  toluTag
//
//  Owns the app's single navigation stack and maps each route to its screen.
//

import SwiftUI

struct RootView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
        .tint(Tolu.Palette.lime)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .write:
            WriteView()
        case .read:
            ReadView()
        case .keys:
            TagRecordsView()
        case .createKey:
            CreateKeyView()
        case .writeText:
            WriteTextView()
        case .deleteObject(let prefill):
            DeleteView(prefill: prefill)
        case .scanTag:
            ScanView()
        case .readText:
            ReadTextView()
        case .signMessage:
            SignMessageView()
        case .signTypedData:
            SignTypedDataView()
        case .collectTags:
            CollectTagsView()
        }
    }

    private func placeholder(
        _ headerTitle: String,
        _ heading: String,
        _ detail: String,
        _ accent: Color
    ) -> some View {
        PlaceholderScreen(headerTitle: headerTitle, heading: heading, detail: detail, accent: accent) {
            router.pop()
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
