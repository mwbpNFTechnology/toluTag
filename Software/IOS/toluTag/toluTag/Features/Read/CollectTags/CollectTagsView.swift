//
//  CollectTagsView.swift
//  toluTag
//
//  Two-stage collect tags: setup (a new list — object id + phrase format +
//  label + start count — or a saved list to continue) → run (tap many tags
//  into an address list, dedup by card) → save the collection.
//

import SwiftUI

struct CollectTagsView: View {
    @Environment(Router.self) private var router
    @State private var model = CollectTagsViewModel()

    private let accent = Tolu.Palette.teal

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
        .onAppear { model.loadCollections() }
    }

    private func topBar(model: CollectTagsViewModel) -> some View {
        ZStack {
            MonoLabel(model.stage == .setup ? "collect tags · setup" : "collect tags",
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
    private func setupContent(model: CollectTagsViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 22) {
            ToluHeading(text: "collect tags\ninto a list", accent: accent).padding(.bottom, 2)

            if !model.collections.isEmpty {
                ToluTabs(options: CollectMode.allCases, selection: $model.mode, title: \.title, accent: accent)
            }

            switch model.mode {
            case .newList: newListFields(model: model)
            case .savedList: savedListFields(model: model)
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

    @ViewBuilder
    private func newListFields(model: CollectTagsViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            ToluTextField(label: "label", text: $model.label, placeholder: "e.g. event drop · march", mono: false)
            hint("names this collection so you can export it later.")
        }

        VStack(alignment: .leading, spacing: 11) {
            HexBlockField(label: "key object id", text: $model.objectIdText, accent: accent)
            hint("the secp256k1 key read on every tag.")
        }

        VStack(alignment: .leading, spacing: 8) {
            MonoLabel("phrase format", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
            VStack(spacing: 8) {
                ForEach(CollectTagsViewModel.PhraseFormat.allCases) { format in
                    formatRow(format, model: model)
                }
            }
        }

        if model.format == .count {
            countField("start count", text: $model.startCountText,
                       hint: "the first tag gets this number, each next tag one more.")
        }
    }

    @ViewBuilder
    private func savedListFields(model: CollectTagsViewModel) -> some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            MonoLabel("saved lists", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
            VStack(spacing: 8) {
                ForEach(model.collections) { collection in
                    listRow(collection, model: model)
                }
            }
        }

        if let chosen = model.chosen {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "key object id", value: "0x" + chosen.objectID)
                InfoRow(label: "phrase format", value: model.chosenFormat.menuTitle, valueColor: Tolu.Palette.violet)
            }

            if model.chosenFormat == .count {
                countField("next count", text: $model.nextCountText,
                           hint: chosen.entries.isEmpty
                               ? "the first tag gets this number, each next tag one more."
                               : "the list ends at \(chosen.nextCount - 1) — new tags carry on from here.")
                if model.nextCountOverlaps {
                    Text("this list already goes up to \(chosen.nextCount - 1) — numbers may repeat.")
                        .font(.system(size: 12)).foregroundStyle(Tolu.Palette.amber)
                }
            }
        } else {
            hint("pick a list — new tags go at its end, with its key object id and format.")
        }
    }

    private func formatRow(_ format: CollectTagsViewModel.PhraseFormat, model: CollectTagsViewModel) -> some View {
        let selected = model.format == format
        return Button { model.format = format } label: {
            HStack(spacing: 12) {
                radio(selected)
                Text(format.menuTitle)
                    .font(.toluMono(12)).foregroundStyle(selected ? Tolu.Palette.text : Tolu.Palette.mute)
                Spacer()
            }
            .padding(.horizontal, 14).frame(height: 46)
            .background(rowBackground(selected: selected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func listRow(_ collection: TagCollection, model: CollectTagsViewModel) -> some View {
        let selected = model.chosenID == collection.id
        return Button { model.choose(collection) } label: {
            HStack(spacing: 12) {
                radio(selected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(collection.label.isEmpty ? "collection" : collection.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? Tolu.Palette.text : Tolu.Palette.mute)
                        .lineLimit(1)
                    MonoLabel("\(collection.count) tags · \(collection.createdAt.formatted(date: .abbreviated, time: .omitted))",
                              size: 8, color: Tolu.Palette.dim, tracking: 1)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(rowBackground(selected: selected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func radio(_ selected: Bool) -> some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 16)).foregroundStyle(selected ? accent : Tolu.Palette.line2)
    }

    private func rowBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Tolu.Palette.ink3)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? accent.opacity(0.5) : Tolu.Palette.line, lineWidth: 1))
    }

    private func countField(_ label: String, text: Binding<String>, hint note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ToluTextField(label: label, text: text, placeholder: "0", keyboardType: .numberPad)
            hint(note)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
    }

    // MARK: - Run

    private func runContent(model: CollectTagsViewModel) -> some View {
        VStack(spacing: 14) {
            if let run = model.run {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
                        MonoLabel("0x\(run.objectId) · \(run.format.label)", size: 9, color: Tolu.Palette.dim, tracking: 1)
                        if let detail = model.runDetail {
                            MonoLabel(detail, size: 9, color: Tolu.Palette.dim, tracking: 1)
                        }
                    }
                    Spacer()
                    MonoLabel("\(model.totalCount)", size: 14, color: accent, tracking: 1)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tolu.Palette.ink3)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
                )
            }

            Button { model.scanOne() } label: {
                HStack(spacing: 9) {
                    if model.scanning { ProgressView().tint(Tolu.Palette.ink) }
                    else { Image(systemName: "wave.3.forward").font(.system(size: 16, weight: .medium)) }
                    Text(model.scanning ? "Hold a tag…" : "Scan a tag").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Tolu.Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(model.isNfcAvailable && !model.scanning ? 1 : 0.5)
            }
            .buttonStyle(PressableCardStyle())
            .disabled(!model.isNfcAvailable || model.scanning)

            if let error = model.scanError {
                Text(error).font(.system(size: 12.5)).foregroundStyle(Tolu.Palette.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let added = model.lastAdded {
                Text("added  \(added)").font(.toluMono(10)).foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            }

            if model.entries.isEmpty {
                Text(model.run?.base == nil ? "no tags yet — place a tag and tap scan."
                                            : "no new tags yet — place a tag and tap scan.")
                    .font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
                    .frame(maxWidth: .infinity).padding(.top, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.entries) { entry in entryRow(entry, model: model) }
                }
            }

            if model.didSave {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 14)).foregroundStyle(accent)
                    Text("saved — find it under tag records → collections.")
                        .font(.system(size: 13)).foregroundStyle(Tolu.Palette.text)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Tolu.Palette.ink2)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1)))
            }
        }
    }

    private func entryRow(_ entry: TagCollectionEntry, model: CollectTagsViewModel) -> some View {
        HStack(spacing: 12) {
            MonoLabel("\(entry.index)", size: 11, color: accent, tracking: 1)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.address).font(.toluMono(11)).foregroundStyle(Tolu.Palette.text).lineLimit(1)
                MonoLabel("\(entry.tagId.prefix(12))… · \(entry.value)", size: 8, color: Tolu.Palette.dim, tracking: 0.5).lineLimit(1)
            }
            Spacer()
            Button { model.removeEntry(entry.id) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(Tolu.Palette.dim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Tolu.Palette.ink3)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1)))
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(model: CollectTagsViewModel) -> some View {
        VStack(spacing: 0) {
            switch model.stage {
            case .setup:
                bigButton("Continue", icon: "arrow.right", enabled: model.canContinue) { model.goToRun() }
            case .run:
                if model.didSave {
                    bigButton("Done", icon: "checkmark", enabled: true) { router.pop() }
                } else if model.run?.base != nil {
                    bigButton("Add to list (\(model.count))", icon: "plus",
                              enabled: model.canSave) { model.saveCollection() }
                } else {
                    bigButton("Save collection (\(model.count))", icon: "square.and.arrow.down",
                              enabled: model.canSave) { model.saveCollection() }
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
    NavigationStack { CollectTagsView().environment(Router()) }
        .preferredColorScheme(.dark)
        .tint(Tolu.Palette.teal)
}
