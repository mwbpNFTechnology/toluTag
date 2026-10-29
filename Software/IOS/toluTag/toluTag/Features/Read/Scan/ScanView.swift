//
//  ScanView.swift
//  toluTag
//
//  Two-stage scan tag: setup (object id + optional pin, or nothing for a general
//  card scan; pick from saved records) → run (a live NFC read + details).
//

import SwiftUI

struct ScanView: View {
    @Environment(Router.self) private var router
    @State private var model = ScanViewModel()

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
        .sheet(isPresented: $model.pickerPresented) { pickerSheet(model: model) }
    }

    // MARK: - Top bar

    private func topBar(model: ScanViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "scan tag · setup" : "scan tag",
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
    private func setupContent(model: ScanViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 22) {
            ToluHeading(text: "read a slot, or\njust the card", accent: accent).padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 11) {
                HexBlockField(label: "object id", text: $model.objectIdText, accent: accent)
                Text(model.cardOnly
                     ? "empty — scans the card for its general details only."
                     : "the slot on the tag to read back.")
                    .font(.toluMono(9)).foregroundStyle(model.cardOnly ? Tolu.Palette.violet : Tolu.Palette.dim)
            }

            recordsPickerButton(model: model)

            ProtectionFields(
                protectOn: $model.protectOn, method: $model.method,
                pin: $model.pinText, pinVisible: $model.pinVisible,
                pinObjectId: $model.userObjectIdText, phoneKeyObjectId: $model.phoneKeyObjectIdText,
                disabled: model.cardOnly,
                pinNote: "turn on to read a pin-protected object — the pin opens a session so the value can be read.",
                ecKeyNote: "for an object bound to this iphone's key: face id opens an encrypted session so it can be read.",
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

    private func recordsPickerButton(model: ScanViewModel) -> some View {
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

    private func pickerSheet(model: ScanViewModel) -> some View {
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

    private func optionRow(_ option: ScanViewModel.Option, model: ScanViewModel) -> some View {
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

    private func runContent(model: ScanViewModel) -> some View {
        VStack(spacing: 0) {
            NfcPulseMark(done: model.isComplete, accent: accent).padding(.top, 6)

            Text(model.isComplete
                 ? (model.cardOnly ? "card read" : "read complete")
                 : "hold the tag to\nthe top of your phone")
                .font(.toluTitle(26)).tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tolu.Palette.text).padding(.top, 10)

            Text(model.isComplete
                 ? "here's what the tag reported."
                 : "keep the tag still until every step below completes.")
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

    private func stepsCard(model: ScanViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                StepRow(state: model.state(for: index), title: step.title, hint: step.hint, first: index == 0)
            }
        }
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func resultCard(_ result: ScanResult) -> some View {
        VStack(spacing: 14) {
            chipCard(result.chip)
            if let object = result.object {
                objectCard(object, matchedLabel: result.matchedLabel)
            }
        }
    }

    private func chipCard(_ chip: ScanResult.ChipDetails) -> some View {
        detailCard(title: "chip details", accent: Tolu.Palette.violet) {
            if let v = chip.uniqueId { InfoRow(label: "unique id", value: v, valueColor: Tolu.Palette.mute) }
            if let v = chip.appletVersionRaw { InfoRow(label: "applet version (raw)", value: v) }
            if let v = chip.appletVersion { InfoRow(label: "applet version", value: v, valueColor: accent) }
            if let v = chip.secureBoxVersion { InfoRow(label: "secure box version", value: "\(v)") }
            if let features = chip.features {
                InfoRow(label: "features", value: features.isEmpty ? "—" : features.joined(separator: ", "),
                        valueColor: Tolu.Palette.mute)
            }
            if let v = chip.persistentFreeMemory { InfoRow(label: "persistent free memory", value: memory(v)) }
            if let v = chip.transientResetFreeMemory { InfoRow(label: "transient reset free", value: memory(v)) }
            if let v = chip.transientDeselectFreeMemory { InfoRow(label: "transient deselect free", value: memory(v)) }
        }
    }

    @ViewBuilder
    private func objectCard(_ object: ScanResult.ObjectDetails, matchedLabel: String?) -> some View {
        detailCard(title: "object details · 0x\(object.objectId)", accent: accent) {
            if let label = matchedLabel {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill").font(.system(size: 11)).foregroundStyle(accent)
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
                }
            }
            InfoRow(label: "exists", value: object.exists ? "true" : "false",
                    valueColor: object.exists ? accent : Tolu.Palette.coral)
            if object.exists {
                if let type = object.type {
                    let hex = object.typeByte.map { String(format: " (0x%02X)", $0) } ?? ""
                    InfoRow(label: "type", value: type + hex, valueColor: Tolu.Palette.violet)
                }
                if let size = object.sizeBytes { InfoRow(label: "size", value: "\(size) bytes") }
                if let origin = object.origin {
                    InfoRow(label: "origin", value: "\(origin.name) — \(origin.detail)", valueColor: origin.color)
                }
                if let auth = object.isAuthenticationObject {
                    InfoRow(label: "authentication object", value: auth ? "true" : "false")
                }
                if let version = object.versionAttribute { InfoRow(label: "version attribute", value: "\(version)") }
                if let policy = object.policyRaw { InfoRow(label: "policy (raw)", value: policy, valueColor: Tolu.Palette.mute) }
                if let attributes = object.attributesRaw {
                    InfoRow(label: "attributes (raw)", value: attributes, valueColor: Tolu.Palette.mute)
                }
                if let address = object.address { InfoRow(label: "ethereum address", value: address, valueColor: accent) }
                if let publicKey = object.publicKey { InfoRow(label: "public key", value: publicKey, valueColor: Tolu.Palette.mute) }
                if let text = object.text {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("text", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                        Text(text.isEmpty ? "—" : text)
                            .font(.system(size: 14)).foregroundStyle(Tolu.Palette.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func detailCard<Content: View>(title: String, accent: Color,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(title, size: 10, color: accent, tracking: 1.8)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
                .fill(Tolu.Palette.ink3)
                .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        )
    }

    private func memory(_ bytes: Int) -> String {
        bytes >= Se05x.freeMemorySaturated ? "\(bytes) bytes (≥ 32768)" : "\(bytes) bytes"
    }

    // MARK: - Save / import

    @ViewBuilder
    private func saveCard(model: ScanViewModel) -> some View {
        @Bindable var model = model
        let kindWord = model.saveKind == .key ? "key" : "text"

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 14)).foregroundStyle(accent)
                Text("save to records?").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
            }
            Text("this \(kindWord) isn't in your saved records yet — add a label to keep it (handy for importing objects you made on your computer).")
                .font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.mute).lineSpacing(2)

            ToluTextField(label: "label", text: $model.saveLabel, placeholder: "e.g. imported · vault", mono: false)

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
    private func bottomBar(model: ScanViewModel) -> some View {
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
    NavigationStack { ScanView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.lime)
}
