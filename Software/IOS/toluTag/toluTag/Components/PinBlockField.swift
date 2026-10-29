//
//  PinBlockField.swift
//  toluTag
//
//  A fixed-length numeric PIN input rendered as individual cells (dots when
//  hidden), matching the tolu design.
//

import SwiftUI

struct PinBlockField: View {
    @Binding var pin: String
    var length: Int = 6
    var visible: Bool = false
    var accent: Color = Tolu.Palette.lime

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(height: 54)
                .onChange(of: pin) { _, value in
                    pin = String(value.filter(\.isNumber).prefix(length))
                }

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    cell(digit(at: index), cursor: index == pin.count && focused)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func digit(at index: Int) -> String {
        let characters = Array(pin)
        return index < characters.count ? String(characters[index]) : ""
    }

    private func cell(_ digit: String, cursor: Bool) -> some View {
        let filled = !digit.isEmpty
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Tolu.Palette.ink2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(filled ? Tolu.Palette.line2 : (cursor ? accent : Tolu.Palette.line), lineWidth: 1)
                )
            if filled {
                if visible {
                    Text(digit).font(.toluMono(18, weight: .medium)).foregroundStyle(Tolu.Palette.text)
                } else {
                    Circle().fill(Tolu.Palette.text).frame(width: 9, height: 9)
                }
            } else if cursor {
                Rectangle().fill(accent).frame(width: 1.5, height: 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
    }
}

#Preview {
    PinBlockField(pin: .constant("1234"))
        .padding()
        .background(Tolu.Palette.ink)
}
