//
//  ReadTextViewModel.swift
//  toluTag
//
//  Two-stage read text: configure (object id + optional pin, or pick a saved
//  string), then read the BinaryFile back and decode it to text.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class ReadTextViewModel {

    enum Stage {
        case setup
        case run
    }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let hint: String
    }

    struct Option: Identifiable {
        let id = UUID()
        let label: String
        let objectID: String
    }

    struct Result {
        let objectId: String
        let text: String
        let sizeBytes: Int?
        let deletable: Bool
        let uniqueId: String?
        var matchedLabel: String?
    }

    var stage: Stage = .setup

    // Setup
    var objectIdText: String = "00000010"
    var setupError: String?

    // Optional PIN/UserID (for a pin-protected object).
    var pinOn: Bool = false
    var userObjectIdText: String = ""
    var pinText: String = ""
    var pinVisible: Bool = false

    // Picker
    var pickerPresented = false
    private(set) var options: [Option] = []
    private(set) var unlocking = false

    // Run
    private(set) var currentStep: Int = -1
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var result: Result?
    private(set) var runError: String?

    // Import: offer to save a text that isn't in the records yet.
    var saveLabel: String = ""
    private(set) var didSave = false

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { result != nil }

    var steps: [Step] {
        if pinOn {
            return [
                Step(title: "Authenticate", hint: "open a pin session"),
                Step(title: "Read text", hint: "read the string & decode it")
            ]
        }
        return [Step(title: "Read text", hint: "read the string & decode it")]
    }

    var canContinue: Bool {
        guard objectIdText.count == 8 else { return false }
        if pinOn {
            return userObjectIdText.count == 8 && pinText.count == 6 && userObjectIdText != objectIdText
        }
        return true
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return "Scan to read"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if isComplete || index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    // MARK: - Import / save

    /// Offer to save when a text was read that isn't already in the records.
    var canOfferSave: Bool { result != nil && result?.matchedLabel == nil && !didSave }
    var canSave: Bool { !saveLabel.trimmingCharacters(in: .whitespaces).isEmpty }

    func saveRecord() {
        guard let result, canSave else { return }
        KeyStore.shared.addString(StringRecord(
            label: saveLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            objectID: result.objectId,
            text: result.text,
            deletable: result.deletable,
            uniqueId: result.uniqueId,
            createdAt: Date()
        ))
        didSave = true
    }

    // MARK: - Picker (Face ID gated) — strings only

    func openPicker() {
        guard !unlocking else { return }
        unlocking = true
        KeyStore.shared.authenticate(reason: "Unlock to pick a saved text") { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                self.unlocking = false
                guard success else { return }
                self.options = KeyStore.shared.allStrings().map {
                    Option(label: $0.label, objectID: $0.objectID)
                }
                self.pickerPresented = true
            }
        }
    }

    func select(_ option: Option) {
        objectIdText = option.objectID
        pickerPresented = false
    }

    // MARK: - Stage navigation

    func goToRun() {
        guard objectIdText.count == 8 else { setupError = "object id must be 8 hex digits"; return }
        if pinOn {
            guard userObjectIdText.count == 8 else { setupError = "pin object id must be 8 hex digits"; return }
            guard pinText.count == 6 else { setupError = "pin must be 6 digits"; return }
            guard userObjectIdText != objectIdText else {
                setupError = "the pin object id must differ from the object id"; return
            }
        }
        setupError = nil
        resetRun()
        stage = .run
    }

    func backToSetup() {
        stage = .setup
        resetRun()
    }

    // MARK: - Run

    func scan() {
        guard !running, !isComplete else { return }
        guard let key = ObjectId.parse(objectIdText) else { runError = "invalid object id"; return }
        let user = pinOn ? ObjectId.parse(userObjectIdText) : nil
        let pinBytes = pinOn ? Array(pinText.utf8) : nil

        resetRun()
        running = true
        currentStep = 0

        Task {
            do {
                let outcome: Result = try await runner.run(alertMessage: "Hold your iPhone near the tolu tag") { [weak self] tag in
                    if let user, let pinBytes {
                        try await tag.openUserIdSession(userObjectId: user.bytes, pin: pinBytes)
                        self?.advance(to: 1)
                    }
                    guard try await tag.exists(objectId: key.bytes) else { throw Se05xError.noKey }
                    let bytes = try await tag.readBinary(objectId: key.bytes)
                    let deletable = (try? await tag.readAttributes(objectId: key.bytes))?.allowsDelete ?? true
                    let uid = try? await tag.readUniqueId()
                    return Result(objectId: key.hex, text: Self.decodeText(bytes),
                                  sizeBytes: bytes.count, deletable: deletable,
                                  uniqueId: CardUid.normalize(uid), matchedLabel: nil)
                }
                running = false
                result = outcome
                result?.matchedLabel = Self.matchedLabel(objectHex: outcome.objectId, uid: outcome.uniqueId)
                currentStep = steps.count
            } catch {
                running = false
                failedStep = max(currentStep, 0)
                if let se = error as? Se05xError, case .noKey = se {
                    runError = "no object with that id exists on the tag."
                } else {
                    runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func advance(to step: Int) {
        currentStep = max(currentStep, step)
    }

    /// Matches a saved string on object id *and* card. A record with no stored
    /// uid matches on object id alone (backward compat); one with a uid matches
    /// only its own card.
    @MainActor
    private static func matchedLabel(objectHex: String, uid: String?) -> String? {
        let target = objectHex.uppercased()
        for record in KeyStore.shared.allStrings()
        where record.objectID.uppercased() == target
            && (record.uniqueId == nil || CardUid.sameCard(record.uniqueId, uid)) {
            return record.label.isEmpty ? nil : record.label
        }
        return nil
    }

    private static func decodeText(_ bytes: [UInt8]) -> String {
        let trimmed = Array(bytes.reversed().drop { $0 == 0 }.reversed())
        if let string = String(bytes: trimmed, encoding: .utf8), !string.isEmpty {
            return string
        }
        return trimmed.isEmpty ? "" : "0x" + Hex.string(trimmed)
    }

    private func resetRun() {
        currentStep = -1
        running = false
        failedStep = -1
        result = nil
        runError = nil
        saveLabel = ""
        didSave = false
    }
}
