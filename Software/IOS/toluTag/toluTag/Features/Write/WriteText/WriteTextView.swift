//
//  WriteTextView.swift
//  toluTag
//
//  Two-stage write text: setup (label + object id + text) → run (write and
//  validate), styled after the tolu flow.
//

import SwiftUI

struct WriteTextView: View {
    @Environment(Router.self) private var router
    @State private var model = WriteTextViewModel()

    private let accent = Tolu.Palette.lime

    var body: some View {
        @Bindable var model = model

        ZStack {
            ToluBackground()
            VStack(spacing: 0) {
                topBar(model: model)
                ScrollView {
                    Group {
                        switch model.stage {
                        case .setup: setupContent(model: model)
                        case .run: runContent(model: model)
                        }
                    }
                    .padding(.horizontal, Tolu.Spacing.screen)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                bottomBar(model: model)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func topBar(model: WriteTextViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "write text · setup" : "write text",
                      size: 11, color: Tolu.Palette.text, tracking: 2)
            HStack {
                Button {
                    if model.stage == .run { model.backToSetup() } else { router.pop() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 10)
        .overlay(Rectangle().fill(Tolu.Palette.line).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Setup

    @ViewBuilder
    private func setupContent(model: WriteTextViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 24) {
            ToluHeading(text: "name it, then\ntap the tag", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 8) {
                ToluTextField(label: "label", text: $model.label, placeholder: "e.g. batch note", mono: false)
                Text("a name so you recognise this string later.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "object id", text: $model.objectIdText, accent: accent)
                Text("the slot on the tag where the string is stored.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            VStack(alignment: .leading, spacing: 6) {
                ToluTextField(label: "text", text: $model.text, placeholder: "hello tolu",
                              mono: false, axis: .vertical)
                Text("\(model.byteCount)/\(WriteTextViewModel.maxBytes) bytes")
                    .font(.toluMono(9)).tracking(1)
                    .foregroundStyle(model.byteCount > WriteTextViewModel.maxBytes ? Tolu.Palette.coral : Tolu.Palette.dim)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            CheckboxCard(
                isOn: $model.allowDelete,
                title: "Allow deleting this text later",
                detail: "when on, the object is created with a delete policy so you can remove it from the tag. turn off to lock it permanently.",
                accent: accent
            )

            if let error = model.setupError {
                Text(error).font(.system(size: 12)).foregroundStyle(Tolu.Palette.coral)
            }
            if !model.isNfcAvailable {
                Text("nfc isn't available here — run on a real iphone.")
                    .font(.system(size: 12)).foregroundStyle(Tolu.Palette.amber)
            }
        }
    }

    // MARK: - Run

    private func runContent(model: WriteTextViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete ? "written & verified" : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tolu.Palette.text).padding(.top, 10)

            Text(model.isComplete
                 ? "the string was written and read back to verify."
                 : "keep the tag still while it writes and validates.")
                .font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 300).padding(.top, 8)

            stepsCard(model: model).padding(.top, 18)

            if model.isComplete {
                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(label: "object id", value: "0x" + model.objectIdText)
                    InfoRow(label: "size", value: "\(model.writtenBytes) bytes")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                        .fill(Tolu.Palette.ink3)
                        .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
                )
                .padding(.top, 14)
            }

            if let error = model.runError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.coral)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepsCard(model: WriteTextViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                StepRow(state: model.state(for: index), title: step.title, hint: step.hint, first: index == 0)
            }
        }
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(model: WriteTextViewModel) -> some View {
        VStack(spacing: 0) {
            switch model.stage {
            case .setup:
                bigButton("Continue", icon: "arrow.right", enabled: model.canContinue) { model.goToRun() }
            case .run:
                if model.isComplete {
                    bigButton("Done", icon: "checkmark", enabled: true) { router.pop() }
                } else {
                    bigButton(model.actionTitle, icon: "wave.3.forward",
                              enabled: model.isNfcAvailable && !model.running, showsSpinner: model.running) {
                        model.runCurrentStep()
                    }
                }
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen).padding(.top, 8).padding(.bottom, 10)
    }

    private func bigButton(_ title: String, icon: String, enabled: Bool,
                           showsSpinner: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if showsSpinner { ProgressView().tint(Tolu.Palette.ink) }
                else { Image(systemName: icon).font(.system(size: 16, weight: .medium)) }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Tolu.Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!enabled)
    }
}

#Preview {
    NavigationStack { WriteTextView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.lime)
}
