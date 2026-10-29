//
//  WriteTextViewModel.swift
//  toluTag
//
//  Two-stage write text: configure (label + object id + text) then run — write
//  the string to a BinaryFile and read it back to validate. Saves a record.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class WriteTextViewModel {

    enum Stage {
        case setup
        case run
    }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let hint: String
    }

    static let maxBytes = 200

    var stage: Stage = .setup

    // Setup
    var label: String = ""
    var objectIdText: String = "00000010"
    var text: String = ""
    /// Text is created deletable by default so it can be overwritten or removed
    /// later. Turn this off to permanently lock the object on the tag.
    var allowDelete: Bool = true
    var setupError: String?

    // Run
    let steps: [Step] = [
        Step(title: "Write text", hint: "store the string on the tag"),
        Step(title: "Validate", hint: "read it back and compare")
    ]
    private(set) var currentStep: Int = 0
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var writtenBytes: Int = 0
    private(set) var cardUniqueId: String?
    private(set) var runError: String?
    private var saved = false

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { currentStep >= steps.count }
    var byteCount: Int { Array(text.utf8).count }

    var canContinue: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && objectIdText.count == 8
            && byteCount > 0 && byteCount <= Self.maxBytes
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return "Scan to write"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    // MARK: - Stage navigation

    func goToRun() {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { setupError = "add a label"; return }
        guard objectIdText.count == 8 else { setupError = "object id must be 8 hex digits"; return }
        guard byteCount > 0 else { setupError = "enter some text to write"; return }
        guard byteCount <= Self.maxBytes else { setupError = "text too long (max \(Self.maxBytes) bytes)"; return }
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
        let bytes = Array(text.utf8)
        let deletable = allowDelete
        running = true
        runError = nil
        failedStep = -1

        Task {
            do {
                let (readBack, uid) = try await runner.run(alertMessage: "Hold the tag to write.") { tag -> ([UInt8], String?) in
                    if try await tag.exists(objectId: key.bytes) {
                        try await tag.writeBinaryUpdate(objectId: key.bytes, bytes: bytes)
                    } else {
                        try await tag.writeBinaryCreate(objectId: key.bytes, bytes: bytes,
                                                        policy: .binaryFile(deletable: deletable))
                    }
                    let data = try await tag.readBinary(objectId: key.bytes)
                    let uid = try? await tag.readUniqueId()
                    return (data, uid)
                }
                running = false
                cardUniqueId = CardUid.normalize(uid)
                if Array(readBack.prefix(bytes.count)) == bytes {
                    writtenBytes = bytes.count
                    currentStep = 2
                    saveIfComplete()
                } else {
                    failedStep = 1
                    runError = "verification mismatch — read back didn't match what was written"
                }
            } catch {
                running = false
                failedStep = currentStep
                runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func saveIfComplete() {
        guard isComplete, !saved else { return }
        saved = true
        KeyStore.shared.addString(StringRecord(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            objectID: objectIdText,
            text: text,
            deletable: allowDelete,
            uniqueId: cardUniqueId,
            createdAt: Date()
        ))
    }

    private func resetRun() {
        currentStep = 0
        running = false
        failedStep = -1
        writtenBytes = 0
        cardUniqueId = nil
        runError = nil
        saved = false
    }
}
