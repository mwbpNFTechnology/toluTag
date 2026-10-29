//
//  SignMessageView.swift
//  toluTag
//
//  Two-stage EIP-191 sign: setup (object id + optional pin; custom message or
//  the toluTag template with optional wallet address) → run (sign on the tag and
//  show the copyable r/s/v + message hash).
//

import SwiftUI
import UIKit

struct SignMessageView: View {
    @Environment(Router.self) private var router
    @State private var model = SignMessageViewModel()

    private let accent = Tolu.Palette.sky

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

    private func topBar(model: SignMessageViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "sign message · setup" : "sign message",
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
    private func setupContent(model: SignMessageViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 22) {
            ToluHeading(text: "sign an eip-191\nmessage", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "key object id", text: $model.objectIdText, accent: accent)
                Text("the secp256k1 key that signs.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            recordsPickerButton(model: model)

            pinSection(model: model)

            modeSelector(model: model)

            if model.mode == .template {
                VStack(alignment: .leading, spacing: 8) {
                    ToluTextField(label: "wallet address (msg.sender)", text: $model.walletAddress,
                                  placeholder: "0x…  (leave empty for the chip)", mono: true)
                    Text("empty → uses the chip's own address. the message is\n{address}_{uid}_{timestamp}.")
                        .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim).lineSpacing(2)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ToluTextField(label: "message", text: $model.customMessage,
                                  placeholder: "type anything to sign", mono: false, axis: .vertical)
                    Text("signed verbatim as an eip-191 personal_sign message.")
                        .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
                }
            }

            if let error = model.setupError {
                Text(error).font(.system(size: 12)).foregroundStyle(Tolu.Palette.coral)
            }
            if !model.isNfcAvailable {
                Text("nfc isn't available here — run on a real iphone.")
                    .font(.system(size: 12)).foregroundStyle(Tolu.Palette.amber)
            }
        }
    }

    private func modeSelector(model: SignMessageViewModel) -> some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 8) {
            MonoLabel("message type", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
            HStack(spacing: 8) {
                modeButton("toluTag template", selected: model.mode == .template) { model.mode = .template }
                modeButton("custom message", selected: model.mode == .custom) { model.mode = .custom }
            }
            .padding(4)
            .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        }
    }

    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(selected ? Tolu.Palette.ink : Tolu.Palette.mute)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(selected ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pinSection(model: SignMessageViewModel) -> some View {
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
                    Text("the slot holding the pin (userid) that guards the key.")
                        .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
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

    private func recordsPickerButton(model: SignMessageViewModel) -> some View {
        Button { model.openPicker() } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(accent)
                Text("choose from your keys")
                    .font(.system(size: 14)).foregroundStyle(Tolu.Palette.text)
                Spacer()
                if model.unlocking { ProgressView().tint(accent) }
                else { Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tolu.Palette.dim) }
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

    private func pickerSheet(model: SignMessageViewModel) -> some View {
        ZStack {
            ToluBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MonoLabel("your keys", size: 11, color: Tolu.Palette.text, tracking: 2)
                    Spacer()
                    Button("done") { model.pickerPresented = false }
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(accent)
                }
                .padding(.horizontal, Tolu.Spacing.screen).padding(.vertical, 14)

                if model.options.isEmpty {
                    Spacer()
                    Text("no keys yet").font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
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

    private func optionRow(_ option: SignMessageViewModel.Option, model: SignMessageViewModel) -> some View {
        Button { model.select(option) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label.isEmpty ? "key" : option.label)
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Tolu.Palette.text)
                    MonoLabel("key · 0x\(option.objectID)", size: 9, color: Tolu.Palette.dim, tracking: 1)
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

    private func runContent(model: SignMessageViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete ? "signed" : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center).foregroundStyle(Tolu.Palette.text).padding(.top, 10)

            Text(model.isComplete
                 ? "here's the ethereum signature."
                 : "keep the tag still while it signs.")
                .font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 300).padding(.top, 8)

            stepsCard(model: model).padding(.top, 18)

            if let result = model.result {
                resultCard(result).padding(.top, 14)
            }

            if let error = model.runError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.coral)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepsCard(model: SignMessageViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                StepRow(state: model.state(for: index), title: step.title, hint: step.hint, first: index == 0)
            }
        }
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func resultCard(_ result: SignMessageViewModel.Result) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel("ethereum verification data", size: 10, color: accent, tracking: 1.6)

            copyRow("chip address", result.chipAddress, color: accent)
            if let customSender = result.customSender {
                copyRow("custom msg.sender", customSender)
            }
            if let addressUsed = result.addressUsed {
                copyRow("address used", addressUsed)
            }
            copyRow("message", result.message)
            if let timestamp = result.timestamp { copyRow("timestamp", timestamp) }
            if let uniqueId = result.uniqueId { copyRow("unique id", uniqueId) }

            Rectangle().fill(Tolu.Palette.line).frame(height: 1)

            copyRow("r", result.r)
            copyRow("s", result.s)
            HStack {
                MonoLabel("v", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                Spacer()
                Text("\(result.v)").font(.toluMono(13)).foregroundStyle(Tolu.Palette.text)
                if !result.recovered {
                    MonoLabel("fallback", size: 8, color: Tolu.Palette.amber, tracking: 1)
                }
            }
            copyRow("message hash", result.messageHash)
            copyRow("public key", result.publicKey, color: Tolu.Palette.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink3)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        )
    }

    private func copyRow(_ label: String, _ value: String, color: Color = Tolu.Palette.text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MonoLabel(label, size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                Spacer()
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
            Text(value).font(.toluMono(12)).foregroundStyle(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(model: SignMessageViewModel) -> some View {
        VStack(spacing: 0) {
            switch model.stage {
            case .setup:
                bigButton("Continue", icon: "arrow.right", enabled: model.canContinue) { model.goToRun() }
            case .run:
                if model.isComplete {
                    bigButton("Done", icon: "checkmark", enabled: true) { router.pop() }
                } else {
                    bigButton(model.actionTitle, icon: "signature",
                              enabled: model.isNfcAvailable && !model.running, showsSpinner: model.running) {
                        model.scan()
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
    NavigationStack { SignMessageView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.sky)
}
