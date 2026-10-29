//
//  CreateKeyView.swift
//  toluTag
//
//  Two-stage create: setup (block inputs) → run (create tap, then verify tap),
//  styled after the tolu TagsCreateView + TagsScanView.
//

import SwiftUI

struct CreateKeyView: View {
    @Environment(Router.self) private var router
    @State private var model = CreateKeyViewModel()

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

    private func topBar(model: CreateKeyViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "create secp256k1 · setup" : "create secp256k1",
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
    private func setupContent(model: CreateKeyViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 24) {
            ToluHeading(text: "pick a slot, then\ntap the tag", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 8) {
                ToluTextField(label: "label", text: $model.label, placeholder: "e.g. founder · vault", mono: false)
                Text("a name so you recognise this key later.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "key object id", text: $model.keyObjectIdText, accent: accent)
                Text("the slot on the tag where the secp256k1 pair is stored.")
                    .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
            }

            ProtectionFields(
                protectOn: $model.protectOn, method: $model.method,
                pin: $model.pinText, pinVisible: $model.pinVisible,
                pinObjectId: $model.userObjectIdText, phoneKeyObjectId: $model.phoneKeyObjectIdText,
                pinNote: "a 6-digit pin protects every signature made with this key. it is sent to the tag in the clear on every tap.",
                ecKeyNote: "only this iphone, after face id, can use the key. nothing secret crosses nfc — every command runs in an encrypted session. lose this iphone and the key can't be used.",
                accent: accent
            )

            CheckboxCard(
                isOn: $model.allowDelete,
                title: "Allow deleting this object later",
                detail: "off by default. if off, the object id is permanent — signatures can be made but the slot can never be wiped from this tag."
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

    private func runContent(model: CreateKeyViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete ? "key ready" : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tolu.Palette.text)
                .padding(.top, 10)

            Text(model.isComplete ? "the key was created and verified on the tag." : model.runHint)
                .font(.system(size: 13.5)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 300).padding(.top, 8)

            stepsCard(model: model).padding(.top, 18)

            if model.isComplete, let address = model.verifiedAddress {
                resultCard(address: address, publicKey: model.verifiedPublicKey).padding(.top, 14)
            }

            if let error = model.runError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.coral)
                    .multilineTextAlignment(.center).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepsCard(model: CreateKeyViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                StepRow(state: model.state(for: index), title: step.title, hint: step.hint, first: index == 0)
            }
        }
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func resultCard(address: String, publicKey: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoRow(label: "ethereum address", value: address, valueColor: accent)
            if let publicKey {
                InfoRow(label: "public key", value: publicKey, valueColor: Tolu.Palette.mute)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink3)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        )
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(model: CreateKeyViewModel) -> some View {
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
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
    NavigationStack { CreateKeyView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.lime)
}
