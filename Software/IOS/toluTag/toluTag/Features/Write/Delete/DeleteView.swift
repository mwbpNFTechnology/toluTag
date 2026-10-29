//
//  DeleteView.swift
//  toluTag
//
//  Two-stage delete: choose an object (typed or from your records) + confirm,
//  then run the delete and verify it's gone.
//

import SwiftUI

struct DeleteView: View {
    @Environment(Router.self) private var router
    @State private var model = DeleteViewModel()

    let prefill: DeletePrefill?

    private let accent = Tolu.Palette.coral

    init(prefill: DeletePrefill? = nil) {
        self.prefill = prefill
    }

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
        .onAppear {
            if let prefill {
                model.prefill(objectID: prefill.objectID,
                              pinObjectID: prefill.pinObjectID, pin: prefill.pin)
            }
        }
    }

    private func topBar(model: DeleteViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "delete · setup" : "delete",
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
    private func setupContent(model: DeleteViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 22) {
            ToluHeading(text: "pick a slot\nto wipe", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "object id", text: $model.objectIdText, accent: accent)
                Text("the slot on the tag to remove.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            recordsPickerButton(model: model)

            pinSection(model: model)

            ToluCheckbox(isOn: $model.confirmed,
                         title: "i understand this permanently removes the object and can't be undone.",
                         accent: accent)

            if let error = model.setupError {
                Text(error).font(.system(size: 12)).foregroundStyle(accent)
            }
            if !model.isNfcAvailable {
                Text("nfc isn't available here — run on a real iphone.")
                    .font(.system(size: 12)).foregroundStyle(Tolu.Palette.amber)
            }
        }
    }

    @ViewBuilder
    private func pinSection(model: DeleteViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    MonoLabel("requires pin", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
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
                    Text("the slot holding the pin (userid) that guards this object.")
                        .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Tolu.Palette.amber).padding(.top, 1)
                    Text("if the object's policy binds delete to a pin, it can't be removed without it. turn this on and enter the pin to authorise.")
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

    private func recordsPickerButton(model: DeleteViewModel) -> some View {
        Button { model.openPicker() } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(accent)
                Text("choose from your records")
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

    private func pickerSheet(model: DeleteViewModel) -> some View {
        ZStack {
            ToluBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MonoLabel("your records", size: 11, color: Tolu.Palette.text, tracking: 2)
                    Spacer()
                    Button("done") { model.pickerPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 14)

                if model.options.isEmpty {
                    Spacer()
                    Text("no records yet")
                        .font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.options) { option in
                                optionRow(option, model: model)
                            }
                        }
                        .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 8)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func optionRow(_ option: DeleteViewModel.Option, model: DeleteViewModel) -> some View {
        Button { model.select(option) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label.isEmpty ? "record" : option.label)
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Tolu.Palette.text)
                    MonoLabel("\(option.kind) · 0x\(option.objectID)", size: 9, color: Tolu.Palette.dim, tracking: 1)
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

    private func runContent(model: DeleteViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete ? "deleted" : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tolu.Palette.text).padding(.top, 10)

            Text(model.isComplete
                 ? "the object was removed from the tag."
                 : "keep the tag still while it deletes and verifies.")
                .font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 300).padding(.top, 8)

            stepsCard(model: model).padding(.top, 18)

            if let error = model.runError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(accent)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepsCard(model: DeleteViewModel) -> some View {
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
    private func bottomBar(model: DeleteViewModel) -> some View {
        VStack(spacing: 0) {
            switch model.stage {
            case .setup:
                bigButton("Continue", icon: "arrow.right", enabled: model.canContinue) { model.goToRun() }
            case .run:
                if model.isComplete {
                    bigButton("Done", icon: "checkmark", enabled: true) { router.pop() }
                } else {
                    bigButton(model.actionTitle, icon: "trash",
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
    NavigationStack { DeleteView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.coral)
}
