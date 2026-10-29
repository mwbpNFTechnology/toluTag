//
//  MenuScreen.swift
//  toluTag
//
//  Reusable scaffold for a menu screen: header, a heading + subtitle hero, and a
//  scrolling list of action buttons. Used by the write and read screens.
//

import SwiftUI

struct MenuScreen: View {
    let headerTitle: String
    let heading: String
    let subtitle: String
    let accent: Color
    let items: [MenuItem]
    let onBack: () -> Void
    let onSelect: (MenuItem) -> Void

    var body: some View {
        ZStack {
            ToluBackground()

            VStack(spacing: 0) {
                ScreenHeader(title: headerTitle, accent: accent, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            ToluHeading(text: heading, accent: accent)
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(Tolu.Palette.mute)
                                .lineSpacing(2)
                        }
                        .padding(.top, 6)

                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                ActionButton(
                                    index: item.index,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    systemImage: item.systemImage,
                                    accent: item.accent
                                ) {
                                    onSelect(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tolu.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
