//
//  TagRecordsViewModel.swift
//  toluTag
//
//  Loads stored keys and strings after a Face ID unlock, and lets them be
//  filtered by physical card (unique id) — pick one from a dropdown or scan a
//  card to select it. Cards can be given a friendly label.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class TagRecordsViewModel {

    enum State {
        case locked
        case unlocking
        case unlocked
        case failed
    }

    enum Tab {
        case keys
        case strings
        case collections
    }

    struct CardOption: Identifiable {
        var id: String { uid }
        let uid: String
        let label: String?
        let count: Int

        /// A friendly title: the label, else a shortened hex id.
        var title: String {
            if let label, !label.isEmpty { return label }
            return "0x" + uid.prefix(6) + "…" + uid.suffix(4)
        }
    }

    var state: State = .locked
    var tab: Tab = .keys

    /// The selected card's normalized uid, or nil for "all cards".
    var selectedCard: String?

    private(set) var keys: [KeyRecord] = []
    private(set) var strings: [StringRecord] = []
    private(set) var collections: [TagCollection] = []
    private(set) var revealedPins: Set<UUID> = []

    // Export share sheet
    var sharePresented = false
    private(set) var shareItems: [Any] = []

    // Scan-to-filter
    private(set) var scanning = false
    private(set) var scanError: String?
    private let runner = Se05xNfcRunner()

    // Label editor
    var labelEditorPresented = false
    var labelDraft = ""

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func unlock() {
        guard state != .unlocking else { return }
        state = .unlocking
        KeyStore.shared.authenticate(reason: "Unlock your tag records") { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.reload()
                    self.state = .unlocked
                } else {
                    self.state = .failed
                }
            }
        }
    }

    private func reload() {
        keys = KeyStore.shared.all()
        strings = KeyStore.shared.allStrings()
        collections = KeyStore.shared.allCollections()
    }

    func deleteCollection(_ id: TagCollection.ID) {
        KeyStore.shared.removeCollection(id)
        reload()
    }

    /// Writes the collection's JSON to a temp file and opens the share sheet so
    /// it can be saved (e.g. to Files) or sent anywhere.
    func exportCollection(_ collection: TagCollection) {
        let safeName = collection.label.isEmpty ? "tags"
            : collection.label.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).json")
        do {
            try collection.exportJSON().data(using: .utf8)?.write(to: url)
            shareItems = [url]
        } catch {
            shareItems = [collection.exportJSON()]
        }
        sharePresented = true
    }

    func refreshIfUnlocked() {
        guard state == .unlocked else { return }
        reload()
    }

    // MARK: - Cards

    /// Every card that has records or a saved label, plus the current selection.
    var cards: [CardOption] {
        var counts: [String: Int] = [:]
        for record in keys { if let uid = CardUid.normalize(record.uniqueId) { counts[uid, default: 0] += 1 } }
        for record in strings { if let uid = CardUid.normalize(record.uniqueId) { counts[uid, default: 0] += 1 } }

        let labels = KeyStore.shared.allCards()
        var uids = Set(counts.keys)
        for card in labels { if let uid = CardUid.normalize(card.uniqueId) { uids.insert(uid) } }
        if let selectedCard { uids.insert(selectedCard) }

        return uids.sorted().map { uid in
            CardOption(
                uid: uid,
                label: labels.first { CardUid.normalize($0.uniqueId) == uid }?.label,
                count: counts[uid] ?? 0
            )
        }
    }

    /// True when some records predate card tracking (no stored uid).
    var hasUnlabeledRecords: Bool {
        keys.contains { $0.uniqueId == nil } || strings.contains { $0.uniqueId == nil }
    }

    var selectedCardOption: CardOption? {
        guard let selectedCard else { return nil }
        return cards.first { $0.uid == selectedCard }
    }

    func selectCard(_ uid: String?) {
        selectedCard = uid
    }

    var filteredKeys: [KeyRecord] {
        guard let selectedCard else { return keys }
        return keys.filter { CardUid.normalize($0.uniqueId) == selectedCard }
    }

    var filteredStrings: [StringRecord] {
        guard let selectedCard else { return strings }
        return strings.filter { CardUid.normalize($0.uniqueId) == selectedCard }
    }

    // MARK: - Scan to filter

    func scanCard() {
        guard !scanning else { return }
        scanning = true
        scanError = nil
        Task {
            do {
                let uid = try await runner.run(alertMessage: "Hold your iPhone near the card") { tag in
                    try await tag.readUniqueId()
                }
                scanning = false
                if let normalized = CardUid.normalize(uid) {
                    selectedCard = normalized
                } else {
                    scanError = "couldn't read the card id."
                }
            } catch {
                scanning = false
                scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Label editing

    func beginEditLabel() {
        guard let option = selectedCardOption else { return }
        labelDraft = option.label ?? ""
        labelEditorPresented = true
    }

    func saveCardLabel() {
        guard let selectedCard else { return }
        KeyStore.shared.setCardLabel(selectedCard, label: labelDraft)
        labelEditorPresented = false
        reload() // refresh so the new label is reflected
    }

    // MARK: - Pins

    func togglePin(_ id: UUID) {
        if revealedPins.contains(id) { revealedPins.remove(id) } else { revealedPins.insert(id) }
    }

    func isPinRevealed(_ id: UUID) -> Bool { revealedPins.contains(id) }

    func deleteKey(_ id: UUID) {
        KeyStore.shared.remove(id)
        reload()
    }

    func deleteString(_ id: UUID) {
        KeyStore.shared.removeString(id)
        reload()
    }
}
