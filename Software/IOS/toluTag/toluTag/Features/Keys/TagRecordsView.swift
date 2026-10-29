//
//  TagRecordsView.swift
//  toluTag
//
//  Face ID-gated "tag records": keys and strings, in two tabs.
//

import SwiftUI
import UIKit

struct TagRecordsView: View {
    @Environment(Router.self) private var router
    @State private var model = TagRecordsViewModel()

    private let accent = Tolu.Palette.lime

    var body: some View {
        @Bindable var model = model

        ZStack {
            ToluBackground()
            VStack(spacing: 0) {
                ScreenHeader(title: "tag records", accent: accent) { router.pop() }
                content(model: model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if model.state == .locked { model.unlock() }
            else { model.refreshIfUnlocked() }
        }
        .sheet(isPresented: $model.sharePresented) { ActivityView(items: model.shareItems) }
        .alert("name this card", isPresented: $model.labelEditorPresented) {
            TextField("label", text: $model.labelDraft)
            Button("save") { model.saveCardLabel() }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("give this card a friendly name so you can tell it apart from your other tags.")
        }
    }

    @ViewBuilder
    private func content(model: TagRecordsViewModel) -> some View {
        switch model.state {
        case .locked, .unlocking, .failed:
            lockedView(model: model)
        case .unlocked:
            unlockedView(model: model)
        }
    }

    // MARK: - Locked

    private func lockedView(model: TagRecordsViewModel) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "faceid").font(.system(size: 44, weight: .light)).foregroundStyle(accent)
            Text("your records are locked").font(.toluTitle(20)).foregroundStyle(Tolu.Palette.text)
            Text("unlock with face id to view your saved keys and strings.")
                .font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).frame(maxWidth: 280)
            if model.state == .unlocking {
                ProgressView().tint(accent).padding(.top, 4)
            } else {
                PrimaryButton("unlock", systemImage: "faceid", accent: accent) { model.unlock() }
                    .frame(maxWidth: 220).padding(.top, 4)
            }
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity).padding(.horizontal, Tolu.Spacing.screen)
    }

    // MARK: - Unlocked

    @ViewBuilder
    private func unlockedView(model: TagRecordsViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            if model.tab != .collections { cardFilterBar(model: model) }
            tabBar(model: model)
            ScrollView {
                VStack(spacing: 12) {
                    switch model.tab {
                    case .keys:
                        if model.filteredKeys.isEmpty {
                            emptyState("no keys here", model.selectedCard == nil
                                       ? "create a key from write → create key."
                                       : "this card has no saved keys.")
                        } else {
                            ForEach(model.filteredKeys) { keyCard($0, model: model) }
                        }
                    case .strings:
                        if model.filteredStrings.isEmpty {
                            emptyState("no strings here", model.selectedCard == nil
                                       ? "store text from write → write text."
                                       : "this card has no saved strings.")
                        } else {
                            ForEach(model.filteredStrings) { stringCard($0) }
                        }
                    case .collections:
                        if model.collections.isEmpty {
                            emptyState("no collections yet", "build one from read → collect tags.")
                        } else {
                            ForEach(model.collections) { collectionCard($0, model: model) }
                        }
                    }
                }
                .padding(.horizontal, Tolu.Spacing.screen)
                .padding(.vertical, 16)
            }
            if model.tab != .collections { scanBar(model: model) }
        }
    }

    // MARK: - Card filter

    private func cardFilterBar(model: TagRecordsViewModel) -> some View {
        HStack(spacing: 10) {
            Menu {
                Button { model.selectCard(nil) } label: {
                    if model.selectedCard == nil { Label("all cards", systemImage: "checkmark") }
                    else { Text("all cards") }
                }
                if !model.cards.isEmpty { Divider() }
                ForEach(model.cards) { card in
                    Button { model.selectCard(card.uid) } label: {
                        if model.selectedCard == card.uid {
                            Label("\(card.title)  (\(card.count))", systemImage: "checkmark")
                        } else {
                            Text("\(card.title)  (\(card.count))")
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "creditcard").font(.system(size: 13)).foregroundStyle(accent)
                    Text(model.selectedCardOption?.title ?? "all cards")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Tolu.Palette.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Tolu.Palette.dim)
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tolu.Palette.ink3)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
                )
            }

            if model.selectedCard != nil {
                Button { model.beginEditLabel() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Tolu.Palette.ink3)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 12)
    }

    private func tabBar(model: TagRecordsViewModel) -> some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            tabButton("keys", count: model.filteredKeys.count, selected: model.tab == .keys) { model.tab = .keys }
            tabButton("strings", count: model.filteredStrings.count, selected: model.tab == .strings) { model.tab = .strings }
            tabButton("collections", count: model.collections.count, selected: model.tab == .collections) { model.tab = .collections }
        }
        .padding(4)
        .background(Tolu.Palette.ink2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 10)
    }

    // MARK: - Scan bar

    private func scanBar(model: TagRecordsViewModel) -> some View {
        VStack(spacing: 6) {
            if let error = model.scanError {
                Text(error).font(.system(size: 12)).foregroundStyle(Tolu.Palette.coral)
                    .multilineTextAlignment(.center)
            }
            Button { model.scanCard() } label: {
                HStack(spacing: 9) {
                    if model.scanning { ProgressView().tint(Tolu.Palette.ink) }
                    else { Image(systemName: "wave.3.forward").font(.system(size: 16, weight: .medium)) }
                    Text(model.scanning ? "Hold the card…" : "Scan a card to filter")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Tolu.Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(model.isNfcAvailable && !model.scanning ? 1 : 0.5)
            }
            .buttonStyle(PressableCardStyle())
            .disabled(!model.isNfcAvailable || model.scanning)
        }
        .padding(.horizontal, Tolu.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func tabButton(_ title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 13, weight: .medium))
                MonoLabel("\(count)", size: 9, color: selected ? Tolu.Palette.ink : Tolu.Palette.dim, tracking: 1)
            }
            .foregroundStyle(selected ? Tolu.Palette.ink : Tolu.Palette.mute)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(selected ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 10) {
            MonoLabel(title, color: Tolu.Palette.dim, tracking: 2)
            Text(detail).font(.system(size: 13)).foregroundStyle(Tolu.Palette.mute)
                .multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Cards

    private func keyCard(_ record: KeyRecord, model: TagRecordsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(title: record.label, date: record.createdAt)
            InfoRow(label: "key object id", value: "0x" + record.keyObjectID)
            if let uniqueId = record.uniqueId {
                InfoRow(label: "card id", value: "0x" + uniqueId, valueColor: Tolu.Palette.dim)
            }
            if let address = record.address {
                InfoRow(label: "ethereum address", value: address, valueColor: accent)
            }
            if let pinObjectID = record.pinObjectID {
                InfoRow(label: "pin object id", value: "0x" + pinObjectID)
            }
            if let phoneKeyObjectID = record.phoneKeyObjectID {
                InfoRow(label: "phone key object id", value: "0x" + phoneKeyObjectID)
                InfoRow(label: "unlocks with", value: "this iphone · face id (eckey)", valueColor: accent)
            }
            if let pin = record.pin {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("pin", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                        Text(model.isPinRevealed(record.id) ? pin : "••••••")
                            .font(.toluMono(14)).foregroundStyle(Tolu.Palette.text)
                    }
                    Spacer()
                    Button { model.togglePin(record.id) } label: {
                        Image(systemName: model.isPinRevealed(record.id) ? "eye.slash" : "eye")
                            .font(.system(size: 15)).foregroundStyle(Tolu.Palette.mute)
                    }
                    .buttonStyle(.plain)
                }
            }
            protectionFooter(deletable: record.deletable, objectID: record.keyObjectID,
                             pinObjectID: record.pinObjectID, pin: record.pin)
        }
        .padding(16)
        .background(cardBackground)
    }

    private func stringCard(_ record: StringRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(title: record.label, date: record.createdAt)
            InfoRow(label: "object id", value: "0x" + record.objectID)
            if let uniqueId = record.uniqueId {
                InfoRow(label: "card id", value: "0x" + uniqueId, valueColor: Tolu.Palette.dim)
            }
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("text", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                Text(record.text)
                    .font(.system(size: 14)).foregroundStyle(Tolu.Palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            protectionFooter(deletable: record.deletable, objectID: record.objectID)
        }
        .padding(16)
        .background(cardBackground)
    }

    /// A card footer showing whether the object can be removed. When deletable,
    /// it offers a "delete" button that jumps straight into the delete scan.
    @ViewBuilder
    private func protectionFooter(deletable: Bool, objectID: String,
                                  pinObjectID: String? = nil, pin: String? = nil) -> some View {
        Rectangle().fill(Tolu.Palette.line).frame(height: 1).padding(.top, 2)
        HStack {
            if deletable {
                HStack(spacing: 5) {
                    Image(systemName: "lock.open").font(.system(size: 10))
                    Text("deletable").font(.toluMono(9)).tracking(1)
                }
                .foregroundStyle(Tolu.Palette.mute)
                Spacer()
                Button {
                    router.push(.deleteObject(DeletePrefill(objectID: objectID,
                                                            pinObjectID: pinObjectID, pin: pin)))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash").font(.system(size: 12))
                        Text("delete").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Tolu.Palette.coral)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Tolu.Palette.coral.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Tolu.Palette.coral.opacity(0.35), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text("protected · can't be deleted").font(.toluMono(9)).tracking(1)
                }
                .foregroundStyle(Tolu.Palette.dim)
                Spacer()
            }
        }
    }

    private func collectionCard(_ record: TagCollection, model: TagRecordsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(title: record.label, date: record.createdAt)
            InfoRow(label: "object id", value: "0x" + record.objectID)
            InfoRow(label: "format", value: record.format, valueColor: Tolu.Palette.violet)
            InfoRow(label: "tags", value: "\(record.count)", valueColor: accent)

            if !record.entries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel("addresses", size: 9, color: Tolu.Palette.dim, tracking: 1.6)
                    ForEach(record.entries.prefix(6)) { entry in
                        Text("\(entry.index)  \(entry.address)")
                            .font(.toluMono(10)).foregroundStyle(Tolu.Palette.mute).lineLimit(1)
                    }
                    if record.entries.count > 6 {
                        Text("+ \(record.entries.count - 6) more")
                            .font(.toluMono(9)).foregroundStyle(Tolu.Palette.dim)
                    }
                }
            }

            Rectangle().fill(Tolu.Palette.line).frame(height: 1).padding(.top, 2)
            HStack(spacing: 10) {
                Button { model.exportCollection(record) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                        Text("export json").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Tolu.Palette.ink)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { UIPasteboard.general.string = record.exportJSON() } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundStyle(Tolu.Palette.mute)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button { model.deleteCollection(record.id) } label: {
                    Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(Tolu.Palette.coral)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Tolu.Palette.coral.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func cardHeader(title: String, date: Date) -> some View {
        HStack {
            Text(title.isEmpty ? "record" : title)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Tolu.Palette.text)
            Spacer()
            MonoLabel(date.formatted(date: .abbreviated, time: .omitted), size: 9, color: Tolu.Palette.dim, tracking: 1)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous)
            .fill(Tolu.Palette.ink3)
            .overlay(RoundedRectangle(cornerRadius: Tolu.Radius.card, style: .continuous).stroke(Tolu.Palette.line, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { TagRecordsView().environment(Router()) }
        .preferredColorScheme(.dark)
}
