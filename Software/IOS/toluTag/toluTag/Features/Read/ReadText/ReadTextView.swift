//
//  ReadTextView.swift
//  toluTag
//
//  Two-stage read text: setup (object id + optional pin; pick a saved string) →
//  run (a live NFC read that decodes and shows the stored text).
//

import SwiftUI

struct ReadTextView: View {
    @Environment(Router.self) private var router
    @State private var model = ReadTextViewModel()

    private let accent = Tolu.Palette.violet

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
        .sheet(isPresented: $model.pickerPresented) { pickerSheet(model: model) }
    }

    // MARK: - Top bar

    private func topBar(model: ReadTextViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "read text · setup" : "read text",
                      size: 11, color: Tolu.Palette.text, tracking: 2)
            HStack {
                Button {
                    if model.stage == .run { model.backToSetup() } else { router.pop() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.vertical, 10)
        .overlay(Rectangle().fill(Tolu.Palette.line).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Setup

    @ViewBuilder
    private func setupContent(model: ReadTextViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 22) {
            ToluHeading(text: "read a string\nback off a tag", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "object id", text: $model.objectIdText, accent: accent)
                Text("the slot on the tag where the string is stored.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            recordsPickerButton(model: model)

            pinSection(model: model)

            if let error = model.setupError {
                Text(error).font(.system(size: 12)).foregroundStyle(Tolu.Palette.coral)
            }
            if !model.isNfcAvailable {
                Text("nfc isn't available here — run on a real iphone.")
                    .font(.system(size: 12)).foregroundStyle(Tolu.Palette.amber)
            }
        }
    }

    @ViewBuilder
    private func pinSection(model: ReadTextViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    MonoLabel("pin", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                    badge("optional")
                }
                Spacer()
                if model.pinOn {
                    Button { model.pinVisible.toggle() } label: {
                        Image(systemName: model.pinVisible ? "eye.slash" : "eye")
                            .font(.system(size: 15)).foregroundStyle(Tolu.Palette.mute)
                    }
                    .buttonStyle(.plain)
                }
                Toggle("", isOn: $model.pinOn).labelsHidden().tint(accent)
            }

            if model.pinOn {
                PinBlockField(pin: $model.pinText, visible: model.pinVisible, accent: accent)

                VStack(alignment: .leading, spacing: 11) {
                    HexBlockField(label: "pin object id", text: $model.userObjectIdText, accent: accent)
                    Text("the slot holding the pin (userid) that guards the object.")
                        .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Tolu.Palette.amber).padding(.top, 1)
                    Text("turn on to read a pin-protected string — the pin opens a session so the value can be read.")
                        .font(.system(size: 12)).foregroundStyle(Tolu.Palette.mute).lineSpacing(2)
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        MonoLabel(text, size: 8, color: Tolu.Palette.dim, tracking: 1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tolu.Palette.ink3, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Tolu.Palette.line2, lineWidth: 1))
    }

    private func recordsPickerButton(model: ReadTextViewModel) -> some View {
        Button { model.openPicker() } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(accent)
                Text("choose from your saved text")
                    .font(.system(size: 14)).foregroundStyle(Tolu.Palette.text)
                Spacer()
                if model.unlocking {
                    ProgressView().tint(accent)
                } else {
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tolu.Palette.dim)
                }
            }
            .padding(.horizontal, 15).frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Tolu.Palette.ink3)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Picker sheet

    private func pickerSheet(model: ReadTextViewModel) -> some View {
        ZStack {
            ToluBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MonoLabel("your saved text", size: 11, color: Tolu.Palette.text, tracking: 2)
                    Spacer()
                    Button("done") { model.pickerPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 14)

                if model.options.isEmpty {
                    Spacer()
                    Text("no saved text yet")
                        .font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.options) { option in optionRow(option, model: model) }
                        }
                        .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 8)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func optionRow(_ option: ReadTextViewModel.Option, model: ReadTextViewModel) -> some View {
        Button { model.select(option) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label.isEmpty ? "text" : option.label)
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Tolu.Palette.text)
                    MonoLabel("string · 0x\(option.objectID)", size: 9, color: Tolu.Palette.dim, tracking: 1)
                }
                Spacer()
                Image(systemName: "arrow.up.left").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tolu.Palette.dim)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tolu.Palette.ink3)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Run

    private func runContent(model: ReadTextViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete ? "text read" : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tolu.Palette.text).padding(.top, 10)

            Text(model.isComplete
                 ? "here's the string stored on the tag."
                 : "keep the tag still until the read completes.")
                .font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 300).padding(.top, 8)

            stepsCard(model: model).padding(.top, 18)

            if let result = model.result {
                resultCard(result).padding(.top, 14)
            }

            if model.canOfferSave {
                saveCard(model: model).padding(.top, 14)
            } else if model.didSave {
                savedNote.padding(.top, 14)
            }

            if let error = model.runError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.coral)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepsCard(model: ReadTextViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                StepRow(state: model.state(for: index), title: step.title, hint: step.hint, first: index == 0)
            }
        }
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func resultCard(_ result: ReadTextViewModel.Result) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let label = result.matchedLabel {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill").font(.system(size: 11)).foregroundStyle(accent)
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
                }
            }
            InfoRow(label: "object id", value: "0x" + result.objectId)
            if let size = result.sizeBytes {
                InfoRow(label: "size", value: "\(size) bytes")
            }
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel("text", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                Text(result.text.isEmpty ? "—" : result.text)
                    .font(.system(size: 16)).foregroundStyle(Tolu.Palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink3)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        )
    }

    // MARK: - Save / import

    @ViewBuilder
    private func saveCard(model: ReadTextViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 14)).foregroundStyle(accent)
                Text("save to records?").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
            }
            Text("this text isn't in your saved records yet — add a label to keep it (handy for importing text you wrote on your computer).")
                .font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.mute).lineSpacing(2)

            ToluTextField(label: "label", text: $model.saveLabel, placeholder: "e.g. imported note", mono: false)

            Button { model.saveRecord() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    Text("save record").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Tolu.Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(model.canSave ? 1 : 0.5)
            }
            .buttonStyle(PressableCardStyle())
            .disabled(!model.canSave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink2)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(accent.opacity(0.35), lineWidth: 1))
        )
    }

    private var savedNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 14)).foregroundStyle(accent)
            Text("saved to your tag records.").font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.text)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink2)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        )
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(model: ReadTextViewModel) -> some View {
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
                        model.scan()
                    }
                }
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func bigButton(_ title: String, icon: String, enabled: Bool,
                           showsSpinner: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if showsSpinner {
                    ProgressView().tint(Tolu.Palette.ink)
                } else {
                    Image(systemName: icon).font(.system(size: 16, weight: .medium))
                }
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
    NavigationStack { ReadTextView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.violet)
}
