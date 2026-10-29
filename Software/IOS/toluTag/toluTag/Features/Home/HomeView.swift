//
//  HomeView.swift
//  toluTag
//
//  The home screen: brand header, hero, and the two primary actions —
//  write and read.
//

import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router
    @State private var model = HomeViewModel()

    var body: some View {
        ZStack {
            ToluBackground()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 24)
            hero
            Spacer(minLength: 28)
            actions
            keysButton
            footer
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            ToluWordmark()
            Spacer()
            MonoLabel("◉ ready", size: 10, color: Tolu.Palette.lime, tracking: 2)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel("secp256k1 · se05x secure element", color: Tolu.Palette.violet, tracking: 1.8)
            ToluHeading(text: "read & write\nsecure tags")
            Text("provision keys, store data, and read it back from your tolu tag over nfc.")
                .font(.system(size: 13))
                .foregroundStyle(Tolu.Palette.mute)
                .lineSpacing(2)
                .frame(maxWidth: 300, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            ForEach(model.items) { item in
                ActionButton(
                    index: item.index,
                    title: item.title,
                    subtitle: item.subtitle,
                    systemImage: item.systemImage,
                    accent: item.accent
                ) {
                    router.push(item.route)
                }
            }
        }
    }

    private var keysButton: some View {
        let count = KeyStore.shared.totalCount
        return Button {
            router.push(.keys)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Tolu.Palette.mute)
                Text("tag records")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tolu.Palette.text)
                Spacer()
                if count > 0 {
                    MonoLabel("\(count)", size: 10, color: Tolu.Palette.lime, tracking: 1)
                }
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tolu.Palette.dim)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tolu.Palette.dim)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tolu.Palette.ink3)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
            )
        }
        .buttonStyle(PressableCardStyle())
        .padding(.top, 12)
    }

    private var footer: some View {
        MonoLabel("developed by mwbp.io - connecting blockchain to the world",
                  size: 9, color: Tolu.Palette.dim, tracking: 1.2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 22)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(Router())
    }
    .preferredColorScheme(.dark)
    .tint(Tolu.Palette.lime)
}
