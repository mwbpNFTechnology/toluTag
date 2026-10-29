//
//  PlaceholderScreen.swift
//  toluTag
//
//  On-brand "coming soon" screen used as the destination for actions whose flow
//  is not built yet.
//

import SwiftUI

struct PlaceholderScreen: View {
    let headerTitle: String
    let heading: String
    let detail: String
    let accent: Color
    let onBack: () -> Void

    var body: some View {
        ZStack {
            ToluBackground()

            VStack(spacing: 0) {
                ScreenHeader(title: headerTitle, accent: accent, onBack: onBack)
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    MonoLabel("coming soon", color: accent, tracking: 2)
                    ToluHeading(text: heading, accent: accent)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Tolu.Palette.mute)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tolu.Spacing.screen)
                Spacer()
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
