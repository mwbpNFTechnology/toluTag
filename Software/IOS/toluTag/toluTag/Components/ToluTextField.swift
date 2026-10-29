//
//  ToluTextField.swift
//  toluTag
//
//  A labeled text field styled for the app (mono for ids/hex, sentence text for
//  free input). Set `axis: .vertical` for a growing multi-line field.
//

import SwiftUI

struct ToluTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var mono: Bool = true
    var axis: Axis = .horizontal
    /// Overrides the keyboard `mono` picks (e.g. `.numberPad` for a number).
    var keyboardType: UIKeyboardType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(label, tracking: 1.6)
            TextField(placeholder, text: $text, axis: axis)
                .font(mono ? .toluMono(15) : .system(size: 15))
                .foregroundStyle(Tolu.Palette.text)
                .tint(Tolu.Palette.lime)
                .textInputAutocapitalization(mono ? .never : .sentences)
                .autocorrectionDisabled(mono)
                .keyboardType(keyboardType ?? (mono ? .asciiCapable : .default))
                .lineLimit(axis == .vertical ? 6 : 1)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tolu.Palette.ink3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Tolu.Palette.line, lineWidth: 1)
                        )
                )
        }
    }
}
