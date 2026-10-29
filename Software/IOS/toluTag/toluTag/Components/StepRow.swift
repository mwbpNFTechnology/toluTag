//
//  StepRow.swift
//  toluTag
//
//  One row in a steps list, with a state indicator (pending / active / done /
//  error). Matches the tolu design.
//

import SwiftUI

enum StepState {
    case pending
    case active
    case done
    case error
}

struct StepRow: View {
    let state: StepState
    let title: String
    let hint: String
    var first: Bool = false

    @State private var blink = false

    private var color: Color {
        switch state {
        case .done: return Tolu.Palette.lime
        case .active: return Tolu.Palette.amber
        case .error: return Tolu.Palette.coral
        case .pending: return Tolu.Palette.dim
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(state == .pending ? Tolu.Palette.dim : Tolu.Palette.text)
                MonoLabel(hint, size: 8.5, color: state == .active ? Tolu.Palette.amber : Tolu.Palette.dim, tracking: 0.9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(first ? nil : Rectangle().fill(Tolu.Palette.line).frame(height: 1), alignment: .top)
        .onAppear {
            if state == .active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { blink = true }
            }
        }
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .fill(state == .done ? Tolu.Palette.lime : Color.clear)
                .overlay(Circle().stroke(color, lineWidth: 1.5))
                .frame(width: 18, height: 18)
            switch state {
            case .done:
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Tolu.Palette.ink)
            case .active:
                Circle().fill(Tolu.Palette.amber).frame(width: 6, height: 6).opacity(blink ? 0.3 : 1)
            case .error:
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Tolu.Palette.coral)
            case .pending:
                EmptyView()
            }
        }
    }
}
