//
//  HexBlockField.swift
//  toluTag
//
//  An 8-digit hex object-id input rendered as individual cells (a hidden text
//  field behind a row of boxes), matching the tolu design.
//

import SwiftUI

struct HexBlockField: View {
    let label: String
    @Binding var text: String
    var accent: Color = Tolu.Palette.lime

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                MonoLabel(label, size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                badge("8 digits")
            }

            ZStack {
                TextField("", text: $text)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .frame(height: 46)
                    .onChange(of: text) { _, value in
                        text = String(value.lowercased().filter(\.isHexDigit).prefix(8))
                    }

                HStack(spacing: 6) {
                    Text("0x")
                        .font(.toluMono(15))
                        .foregroundStyle(Tolu.Palette.dim)
                    ForEach(0..<8, id: \.self) { index in
                        cell(digit(at: index), cursor: index == text.count && focused)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
    }

    private func badge(_ text: String) -> some View {
        MonoLabel(text, size: 8, color: Tolu.Palette.dim, tracking: 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Tolu.Palette.ink3, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Tolu.Palette.line2, lineWidth: 1))
    }

    private func digit(at index: Int) -> String {
        let characters = Array(text)
        return index < characters.count ? String(characters[index]) : ""
    }

    private func cell(_ digit: String, cursor: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Tolu.Palette.ink2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(!digit.isEmpty ? Tolu.Palette.line2 : (cursor ? accent : Tolu.Palette.line), lineWidth: 1)
                )
            if !digit.isEmpty {
                Text(digit).font(.toluMono(15)).foregroundStyle(Tolu.Palette.text)
            } else if cursor {
                Rectangle().fill(accent).frame(width: 1.5, height: 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }
}

#Preview {
    HexBlockField(label: "object id", text: .constant("9f3ac4"))
        .padding()
        .background(Tolu.Palette.ink)
}
