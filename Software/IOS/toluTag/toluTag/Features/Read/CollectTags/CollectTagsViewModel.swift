//
//  CollectTagsViewModel.swift
//  toluTag
//
//  Two-stage collect tags: configure, then scan tags one by one — read each
//  address + unique id, reject duplicates, build a phrase per tag — and save
//  the list as a record to export anytime. Setup either starts a new list
//  (object id + phrase format + a label, and where {count} starts) or picks a
//  saved list to carry on, numbering included. Mirrors the Java collectTags tool.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class CollectTagsViewModel {

    enum Stage { case setup, run }

    enum PhraseFormat: String, CaseIterable, Identifiable {
        case timestamp, zero, count
        var id: String { rawValue }

        /// The format a saved collection was made with, from its stored label.
        init?(label: String) {
            guard let match = Self.allCases.first(where: { $0.label == label }) else { return nil }
            self = match
        }

        /// The stored format label (Java parity).
        var label: String {
            switch self {
            case .timestamp: return "address_tagId_timestamp"
            case .zero: return "address_tagId_0"
            case .count: return "address_tagId_count"
            }
        }

        var menuTitle: String {
            switch self {
            case .timestamp: return "{address}_{tagId}_{timestamp}"
            case .zero: return "{address}_{tagId}_0"
            case .count: return "{address}_{tagId}_{count}"
            }
        }
    }

    var stage: Stage = .setup

    // Setup
    var mode: CollectMode = .newList
    var objectIdText: String = "00000001"
    var label: String = ""
    var format: PhraseFormat = .timestamp
    var startCountText: String = "0"
    private(set) var collections: [TagCollection] = []
    private(set) var chosenID: TagCollection.ID?
    var nextCountText: String = ""
    var setupError: String?

    // Run
    private(set) var run: CollectRun?
    private(set) var entries: [TagCollectionEntry] = []
    private var seen = Set<String>()
    private(set) var scanning = false
    private(set) var scanError: String?
    private(set) var lastAdded: String?
    private(set) var didSave = false

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var count: Int { entries.count }
    /// Every tag in the list: the saved ones a run continues, plus this run's.
    var totalCount: Int { (run?.base?.count ?? 0) + entries.count }
    var canSave: Bool { !entries.isEmpty && !didSave }

    /// The saved list picked to continue.
    var chosen: TagCollection? { collections.first { $0.id == chosenID } }

    /// The chosen list's format. Lists saved before formats were stored count
    /// as timestamps.
    var chosenFormat: PhraseFormat { chosen.flatMap { PhraseFormat(label: $0.format) } ?? .timestamp }

    /// Whether the typed next count goes back into numbers the chosen list has.
    var nextCountOverlaps: Bool {
        guard let chosen, let next = Self.parseCount(nextCountText) else { return false }
        return next < chosen.nextCount
    }

    var canContinue: Bool {
        switch mode {
        case .newList:
            return objectIdText.count == 8 && !trimmedLabel.isEmpty
                && Self.firstCount(format, text: startCountText) != nil
        case .savedList:
            return chosen != nil && Self.firstCount(chosenFormat, text: nextCountText) != nil
        }
    }

    /// The `{count}` the next scanned tag gets: one past this run's highest,
    /// so removing the last tag frees its number again.
    var nextCount: Int {
        let start = run?.firstCount ?? 0
        return (entries.compactMap { Int($0.value) }.max() ?? (start - 1)) + 1
    }

    /// "12 saved · 3 new · next 15" — what a continued or counted run has so far.
    var runDetail: String? {
        guard let run else { return nil }
        var parts: [String] = []
        if let base = run.base { parts += ["\(base.count) saved", "\(entries.count) new"] }
        if run.format == .count { parts.append("next \(nextCount)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var trimmedLabel: String { label.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nextIndex: Int {
        let first = run?.firstIndex ?? 0
        return (entries.map(\.index).max() ?? (first - 1)) + 1
    }

    // MARK: - Setup

    func loadCollections() {
        collections = KeyStore.shared.allCollections()
        if chosen == nil { chosenID = nil }
        if collections.isEmpty { mode = .newList }
    }

    /// Picks a saved list to continue; its numbering carries on after its highest count.
    func choose(_ collection: TagCollection) {
        chosenID = collection.id
        nextCountText = String(collection.nextCount)
        setupError = nil
    }

    // MARK: - Stage navigation

    func goToRun() {
        let run: CollectRun
        switch mode {
        case .newList:
            guard objectIdText.count == 8 else { setupError = "object id must be 8 hex digits"; return }
            guard !trimmedLabel.isEmpty else { setupError = "add a label for this collection"; return }
            guard let start = Self.firstCount(format, text: startCountText) else {
                setupError = "start count must be a whole number"; return
            }
            run = CollectRun(label: trimmedLabel, objectId: objectIdText, format: format,
                             firstCount: start, base: nil)
        case .savedList:
            guard let chosen else { setupError = "choose a list to continue"; return }
            guard let next = Self.firstCount(chosenFormat, text: nextCountText) else {
                setupError = "next count must be a whole number"; return
            }
            run = CollectRun(label: chosen.label, objectId: chosen.objectID, format: chosenFormat,
                             firstCount: next, base: chosen)
        }
        self.run = run
        setupError = nil
        entries = []
        seen = Set(run.base?.entries.map { $0.tagId.uppercased() } ?? [])
        scanError = nil
        lastAdded = nil
        didSave = false
        stage = .run
    }

    func backToSetup() {
        stage = .setup
    }

    // MARK: - Collect

    func scanOne() {
        guard !scanning, let run else { return }
        guard let key = ObjectId.parse(run.objectId) else { scanError = "invalid object id"; return }
        let index = nextIndex
        let number = nextCount
        let format = run.format

        scanning = true
        scanError = nil

        Task {
            do {
                let entry: TagCollectionEntry? = try await runner.run(alertMessage: "Place a tag on your phone") { tag in
                    let point = try await tag.readPublicKeyPoint(objectId: key.bytes)
                    let address = EthereumAddress.from(publicKeyPoint: point) ?? "0x"
                    let uidLower = (try? await tag.readUniqueId()) ?? "0x"
                    let tagId = "0x" + uidLower.dropFirst(2).uppercased()

                    let value: String
                    switch format {
                    case .timestamp: value = String(Int(Date().timeIntervalSince1970))
                    case .zero: value = "0"
                    case .count: value = String(number)
                    }
                    let phrase = "\(address)_\(tagId)_\(value)"
                    return TagCollectionEntry(index: index, tagId: tagId, address: address, value: value, phrase: phrase)
                }
                scanning = false
                guard let entry else { return }
                let key = entry.tagId.uppercased()
                if seen.contains(key) {
                    scanError = "that tag (\(entry.tagId.prefix(10))…) is already in the list — place a different tag."
                    return
                }
                seen.insert(key)
                entries.append(entry)
                lastAdded = "[\(entry.index)] \(entry.phrase)"
            } catch {
                scanning = false
                scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func removeEntry(_ id: TagCollectionEntry.ID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        seen.remove(entry.tagId.uppercased())
        entries.removeAll { $0.id == id }
    }

    /// Saves a new list, or adds this run's tags to the end of the saved one.
    func saveCollection() {
        guard canSave, let run else { return }
        if let base = run.base {
            KeyStore.shared.appendToCollection(base, entries: entries)
        } else {
            KeyStore.shared.addCollection(TagCollection(
                label: run.label,
                objectID: run.objectId,
                format: run.format.label,
                entries: entries,
                createdAt: Date()
            ))
        }
        didSave = true
        loadCollections()
        if let chosen { choose(chosen) }
    }

    /// The count a run starts from. Only `{count}` lists need a valid one.
    private static func firstCount(_ format: PhraseFormat, text: String) -> Int? {
        format == .count ? parseCount(text) : 0
    }

    private static func parseCount(_ text: String) -> Int? {
        guard let count = Int(text.trimmingCharacters(in: .whitespaces)), count >= 0 else { return nil }
        return count
    }
}
