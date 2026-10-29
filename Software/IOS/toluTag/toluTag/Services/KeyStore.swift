//
//  KeyStore.swift
//  toluTag
//
//  Stores created keys and stored strings ("tag records") in the Keychain
//  (encrypted at rest). Viewing them is gated behind Face ID. Ported from the
//  tolu KeySetStore.
//

import Foundation
import LocalAuthentication
import Security

@Observable
@MainActor
final class KeyStore {
    static let shared = KeyStore()

    private(set) var revision = 0

    @ObservationIgnored private let service = "io.mwbp.toluTag.records"
    @ObservationIgnored private let keysAccount = "toluTag.keys"
    @ObservationIgnored private let stringsAccount = "toluTag.strings"
    @ObservationIgnored private let cardsAccount = "toluTag.cards"
    @ObservationIgnored private let collectionsAccount = "toluTag.collections"

    private init() {}

    // MARK: - Keys

    func all() -> [KeyRecord] {
        guard let data = read(account: keysAccount),
              let list = try? JSONDecoder().decode([KeyRecord].self, from: data) else { return [] }
        return list
    }

    var count: Int { all().count }

    func add(_ record: KeyRecord) {
        var list = all()
        list.insert(record, at: 0)
        if let data = try? JSONEncoder().encode(list) { write(data, account: keysAccount) }
        revision += 1
    }

    func remove(_ id: KeyRecord.ID) {
        var list = all()
        list.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(list) { write(data, account: keysAccount) }
        revision += 1
    }

    // MARK: - Strings

    func allStrings() -> [StringRecord] {
        guard let data = read(account: stringsAccount),
              let list = try? JSONDecoder().decode([StringRecord].self, from: data) else { return [] }
        return list
    }

    var stringsCount: Int { allStrings().count }

    func addString(_ record: StringRecord) {
        var list = allStrings()
        list.insert(record, at: 0)
        if let data = try? JSONEncoder().encode(list) { write(data, account: stringsAccount) }
        revision += 1
    }

    func removeString(_ id: StringRecord.ID) {
        var list = allStrings()
        list.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(list) { write(data, account: stringsAccount) }
        revision += 1
    }

    var totalCount: Int { count + stringsCount }

    // MARK: - Collections

    func allCollections() -> [TagCollection] {
        guard let data = read(account: collectionsAccount),
              let list = try? JSONDecoder().decode([TagCollection].self, from: data) else { return [] }
        return list
    }

    var collectionsCount: Int { allCollections().count }

    func addCollection(_ collection: TagCollection) {
        var list = allCollections()
        list.insert(collection, at: 0)
        if let data = try? JSONEncoder().encode(list) { write(data, account: collectionsAccount) }
        revision += 1
    }

    /// Adds `entries` to the end of a saved collection — or, if it was deleted
    /// meanwhile, saves it again with them.
    func appendToCollection(_ collection: TagCollection, entries: [TagCollectionEntry]) {
        var list = allCollections()
        if let i = list.firstIndex(where: { $0.id == collection.id }) {
            list[i] = list[i].appending(entries)
        } else {
            list.insert(collection.appending(entries), at: 0)
        }
        if let data = try? JSONEncoder().encode(list) { write(data, account: collectionsAccount) }
        revision += 1
    }

    func removeCollection(_ id: TagCollection.ID) {
        var list = allCollections()
        list.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(list) { write(data, account: collectionsAccount) }
        revision += 1
    }

    // MARK: - Card labels

    func allCards() -> [CardTag] {
        guard let data = read(account: cardsAccount),
              let list = try? JSONDecoder().decode([CardTag].self, from: data) else { return [] }
        return list
    }

    func cardLabel(for uniqueId: String) -> String? {
        let target = CardUid.normalize(uniqueId)
        return allCards().first { CardUid.normalize($0.uniqueId) == target }?.label
    }

    /// Upserts a card's label. An empty label removes the entry.
    func setCardLabel(_ uniqueId: String, label: String) {
        guard let uid = CardUid.normalize(uniqueId) else { return }
        var list = allCards().filter { CardUid.normalize($0.uniqueId) != uid }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            list.insert(CardTag(uniqueId: uid, label: trimmed), at: 0)
        }
        if let data = try? JSONEncoder().encode(list) { write(data, account: cardsAccount) }
        revision += 1
    }

    // MARK: - Face ID gate

    /// Prompts for Face ID / device auth. Calls back on the main actor.
    func authenticate(reason: String = "Unlock your tag records", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: - Keychain

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    private func write(_ data: Data, account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }
}
