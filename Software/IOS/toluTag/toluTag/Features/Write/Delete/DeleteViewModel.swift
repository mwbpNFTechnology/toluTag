//
//  DeleteViewModel.swift
//  toluTag
//
//  Two-stage delete: choose an object (type an id, or pick one of your saved
//  records behind Face ID) and confirm, then run the delete + verify.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class DeleteViewModel {

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
        let kind: String   // "key" or "string"
    }

    var stage: Stage = .setup

    // Setup
    var objectIdText: String = ""
    var confirmed: Bool = false
    var setupError: String?

    // Optional PIN/UserID auth — required when the object's policy binds delete
    // to a UserID (e.g. a pin-protected key). The session is opened before the
    // delete so the card authorises it.
    var pinOn: Bool = false
    var userObjectIdText: String = ""
    var pinText: String = ""
    var pinVisible: Bool = false

    // Picker
    var pickerPresented = false
    private(set) var options: [Option] = []
    private(set) var unlocking = false

    // Run
    let steps: [Step] = [
        Step(title: "Delete object", hint: "remove it from the tag"),
        Step(title: "Verify removed", hint: "check it's gone")
    ]
    private(set) var currentStep: Int = 0
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var runError: String?

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { currentStep >= steps.count }
    var canContinue: Bool {
        guard objectIdText.count == 8, confirmed else { return false }
        if pinOn {
            return userObjectIdText.count == 8 && pinText.count == 6 && userObjectIdText != objectIdText
        }
        return true
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return "Scan to delete"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    private var didPrefill = false

    /// Seed the flow from a saved record's "delete" button: fill the id, mark it
    /// confirmed, and jump straight to the scan step. When the record carries a
    /// PIN/UserID (a pin-protected key) those are filled too so the session can
    /// authorise the delete.
    func prefill(objectID: String, pinObjectID: String? = nil, pin: String? = nil) {
        guard !didPrefill else { return }
        didPrefill = true
        objectIdText = objectID
        if let pinObjectID, let pin, !pin.isEmpty {
            pinOn = true
            userObjectIdText = pinObjectID
            pinText = pin
        }
        confirmed = true
        resetRun()
        stage = .run
    }

    // MARK: - Picker (Face ID gated)

    func openPicker() {
        guard !unlocking else { return }
        unlocking = true
        KeyStore.shared.authenticate(reason: "Unlock to pick a record") { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                self.unlocking = false
                guard success else { return }
                self.options = KeyStore.shared.all().map {
                    Option(label: $0.label, objectID: $0.keyObjectID, kind: "key")
                } + KeyStore.shared.allStrings().map {
                    Option(label: $0.label, objectID: $0.objectID, kind: "string")
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
        guard confirmed else { setupError = "confirm this is irreversible"; return }
        setupError = nil
        resetRun()
        stage = .run
    }

    func backToSetup() {
        stage = .setup
        resetRun()
    }

    // MARK: - Run

    func runCurrentStep() {
        guard !running, !isComplete else { return }
        guard let key = ObjectId.parse(objectIdText) else { runError = "invalid object id"; return }
        let user = pinOn ? ObjectId.parse(userObjectIdText) : nil
        let pinBytes = pinOn ? Array(pinText.utf8) : nil
        running = true
        runError = nil
        failedStep = -1

        Task {
            do {
                let outcome: DeleteOutcome = try await runner.run(alertMessage: "Hold the tag to delete.") { tag in
                    if let user, let pinBytes {
                        try await tag.openUserIdSession(userObjectId: user.bytes, pin: pinBytes)
                    }
                    if !(try await tag.exists(objectId: key.bytes)) { return .notFound }
                    let deleted = try await tag.deleteObject(objectId: key.bytes)
                    if !deleted { return .blocked }
                    let stillThere = (try? await tag.exists(objectId: key.bytes)) ?? false
                    return stillThere ? .blocked : .deleted
                }
                running = false
                switch outcome {
                case .deleted:
                    currentStep = 2
                    removeFromStore(objectHex: key.hex)
                case .blocked:
                    failedStep = 0
                    runError = pinOn
                        ? "delete refused — check the pin and pin object id, or the object may be deletion-protected."
                        : "delete refused — the object is deletion-protected, or it needs a pin (turn on \"requires pin\")."
                case .notFound:
                    failedStep = 0
                    runError = "no object with that id exists on the tag."
                }
            } catch {
                running = false
                failedStep = currentStep
                runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func removeFromStore(objectHex: String) {
        for record in KeyStore.shared.all() where record.keyObjectID.uppercased() == objectHex {
            KeyStore.shared.remove(record.id)
        }
        for record in KeyStore.shared.allStrings() where record.objectID.uppercased() == objectHex {
            KeyStore.shared.removeString(record.id)
        }
    }

    private func resetRun() {
        currentStep = 0
        running = false
        failedStep = -1
        runError = nil
    }
}
