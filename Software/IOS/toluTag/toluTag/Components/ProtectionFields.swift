//
//  ProtectionFields.swift
//  toluTag
//
//  The "protect" switch shared by create and scan: when on, two tabs pick
//  how the key is unlocked — a PIN (6 digits + its object id) or this
//  iPhone's key (ECKey: the object id holding the iPhone's public key).
//

import SwiftUI

struct ProtectionFields: View {
    @Binding var protectOn: Bool
    @Binding var method: ProtectionMethod
    @Binding var pin: String
    @Binding var pinVisible: Bool
    @Binding var pinObjectId: String
    @Binding var phoneKeyObjectId: String
    /// Greys the switch out (e.g. a card-only scan has nothing to unlock).
    var disabled = false
    let pinNote: String
    let ecKeyNote: String
    var accent: Color = Tolu.Palette.lime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    MonoLabel("protect", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                    badge("optional")
                }
                Spacer()
                if showsFields && method == .pin {
                    Button { pinVisible.toggle() } label: {
                        Image(systemName: pinVisible ? "eye.slash" : "eye")
                            .font(.system(size: 15)).foregroundStyle(Tolu.Palette.mute)
                    }
                    .buttonStyle(.plain)
                }
                Toggle("", isOn: $protectOn).labelsHidden().tint(accent)
                    .disabled(disabled)
                    .opacity(disabled ? 0.4 : 1)
            }

            if showsFields {
                ToluTabs(options: ProtectionMethod.allCases, selection: $method, title: \.title, accent: accent)

                switch method {
                case .pin:
                    PinBlockField(pin: $pin, visible: pinVisible, accent: accent)
                    VStack(alignment: .leading, spacing: 11) {
                        HexBlockField(label: "pin object id", text: $pinObjectId, accent: accent)
                        hint("the slot holding the pin (userid) that guards the key.")
                    }
                    note(icon: "lock.fill", color: Tolu.Palette.amber, text: pinNote)

                case .ecKey:
                    VStack(alignment: .leading, spacing: 11) {
                        HexBlockField(label: "phone key object id", text: $phoneKeyObjectId, accent: accent)
                        hint("the slot holding this iphone's public key (p-256). several keys on one tag can share it.")
                    }
                    note(icon: "faceid", color: accent, text: ecKeyNote)
                }
            }
        }
    }

    private var showsFields: Bool { protectOn && !disabled }

    private func hint(_ text: String) -> some View {
        Text(text).font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
    }

    private func note(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color).padding(.top, 1)
            Text(text).font(.system(size: 12)).foregroundStyle(Tolu.Palette.mute).lineSpacing(2)
        }
    }

    private func badge(_ text: String) -> some View {
        MonoLabel(text, size: 8, color: Tolu.Palette.dim, tracking: 1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tolu.Palette.ink3, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Tolu.Palette.line2, lineWidth: 1))
    }
}

#Preview {
    ProtectionFields(
        protectOn: .constant(true), method: .constant(.ecKey), pin: .constant(""),
        pinVisible: .constant(false), pinObjectId: .constant("00000002"),
        phoneKeyObjectId: .constant("00000002"),
        pinNote: "a 6-digit pin protects every signature.",
        ecKeyNote: "only this iphone, after face id, can use the key."
    )
    .padding()
    .background(Tolu.Palette.ink)
}
