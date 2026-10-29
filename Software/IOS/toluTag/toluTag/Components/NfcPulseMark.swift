//
//  NfcPulseMark.swift
//  toluTag
//
//  A pulsing NFC mark: expanding rings around a centered wave (or checkmark when
//  done). The "hold the tag" hero from the tolu design.
//

import SwiftUI

struct NfcPulseMark: View {
    var done: Bool = false
    var accent: Color = Tolu.Palette.lime

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .stroke(accent, lineWidth: 1)
                    .scaleEffect(pulse ? 1.25 : 0.7)
                    .opacity(pulse ? 0 : 0.4)
            }
            Circle()
                .fill(accent.opacity(0.07))
                .overlay(Circle().stroke(accent, lineWidth: 1))
                .frame(width: 104, height: 104)
                .overlay(
                    Image(systemName: done ? "checkmark" : "wave.3.forward")
                        .font(.system(size: done ? 40 : 42, weight: done ? .bold : .regular))
                        .foregroundStyle(accent)
                )
        }
        .frame(width: 186, height: 186)
        .onAppear {
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

#Preview {
    NfcPulseMark()
        .background(Tolu.Palette.ink)
}
