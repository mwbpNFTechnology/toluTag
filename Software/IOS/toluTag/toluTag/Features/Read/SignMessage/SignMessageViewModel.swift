//
//  SignMessageViewModel.swift
//  toluTag
//
//  Two-stage EIP-191 sign: configure (object id + optional pin, custom message
//  or the toluTag template), then sign on the tag and show r/s/v + hash. Mirrors
//  the Java ethereumSign tool.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class SignMessageViewModel {

    enum Stage { case setup, run }
    enum Mode: Equatable { case template, custom }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let hint: String
    }

    struct Option: Identifiable {
        let id = UUID()
        let label: String
        let objectID: String
        let pinObjectID: String?
        let pin: String?
    }

    struct Result {
        let mode: Mode
        let chipAddress: String
        let addressUsed: String?
        let customSender: String?
        let message: String
        let timestamp: String?
        let uniqueId: String?
        let publicKey: String
        let r: String
        let s: String
        let v: Int
        let messageHash: String
        let recovered: Bool
    }

    var stage: Stage = .setup

    // Setup
    var objectIdText: String = "00000001"
    var mode: Mode = .template
    var walletAddress: String = ""     // template: empty → chip's own address
    var customMessage: String = ""     // custom mode
    var setupError: String?

    // Optional PIN
    var pinOn: Bool = false
    var userObjectIdText: String = ""
    var pinText: String = ""
    var pinVisible: Bool = false

    // Picker (keys only)
    var pickerPresented = false
    private(set) var options: [Option] = []
    private(set) var unlocking = false

    // Run
    private(set) var currentStep: Int = -1
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var result: Result?
    private(set) var runError: String?

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { result != nil }

    var steps: [Step] {
        if pinOn {
            return [
                Step(title: "Authenticate", hint: "open a pin session"),
                Step(title: "Sign", hint: "hash the message & sign on the tag")
            ]
        }
        return [Step(title: "Sign", hint: "hash the message & sign on the tag")]
    }

    var canContinue: Bool {
        guard objectIdText.count == 8 else { return false }
        if pinOn {
            guard userObjectIdText.count == 8, pinText.count == 6, userObjectIdText != objectIdText else { return false }
        }
        if mode == .custom, customMessage.isEmpty { return false }
        return true
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return "Scan to sign"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if isComplete || index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    // MARK: - Picker (keys only, Face ID gated)

    func openPicker() {
        guard !unlocking else { return }
        unlocking = true
        KeyStore.shared.authenticate(reason: "Unlock to pick a key") { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                self.unlocking = false
                guard success else { return }
                self.options = KeyStore.shared.all().map {
                    Option(label: $0.label, objectID: $0.keyObjectID, pinObjectID: $0.pinObjectID, pin: $0.pin)
                }
                self.pickerPresented = true
            }
        }
    }

    func select(_ option: Option) {
        objectIdText = option.objectID
        if let pinObjectID = option.pinObjectID, let pin = option.pin, !pin.isEmpty {
            pinOn = true
            userObjectIdText = pinObjectID
            pinText = pin
        } else {
            pinOn = false
            userObjectIdText = ""
            pinText = ""
        }
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
        if mode == .custom, customMessage.isEmpty { setupError = "enter a message to sign"; return }
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
        let mode = self.mode
        let sender = walletAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = customMessage

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

                    let point = try await tag.readPublicKeyPoint(objectId: key.bytes)
                    let chipAddressLower = EthereumAddress.from(publicKeyPoint: point) ?? "0x"
                    let chipAddress = "0x" + chipAddressLower.dropFirst(2).uppercased()
                    let publicKey = "0x" + Hex.string(point).uppercased()

                    var message: String
                    var addressUsed: String?
                    var customSender: String?
                    var timestamp: String?
                    var uniqueId: String?

                    switch mode {
                    case .custom:
                        message = custom
                    case .template:
                        let uidLower = (try? await tag.readUniqueId()) ?? "0x"
                        let uid = "0x" + uidLower.dropFirst(2).uppercased()
                        let ts = String(Int(Date().timeIntervalSince1970))
                        let used = sender.isEmpty ? chipAddress : sender
                        message = "\(used)_\(uid)_\(ts)"
                        addressUsed = used
                        customSender = sender.isEmpty ? nil : sender
                        timestamp = ts
                        uniqueId = uid
                    }

                    let hash = Eip191.personalMessageHash(message)
                    let der = try await tag.signDigest(objectId: key.bytes, digest: hash)
                    guard let sig = EthereumSigner.makeSignature(der: der, hash: hash, publicKey: point) else {
                        throw Se05xError.apdu("parse signature", 0, 0)
                    }

                    return Result(
                        mode: mode, chipAddress: chipAddress, addressUsed: addressUsed,
                        customSender: customSender, message: message, timestamp: timestamp,
                        uniqueId: uniqueId, publicKey: publicKey,
                        r: sig.r, s: sig.s, v: sig.v, messageHash: sig.messageHash, recovered: sig.recovered
                    )
                }
                running = false
                result = outcome
                currentStep = steps.count
            } catch {
                running = false
                failedStep = max(currentStep, 0)
                runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func advance(to step: Int) {
        currentStep = max(currentStep, step)
    }

    private func resetRun() {
        currentStep = -1
        running = false
        failedStep = -1
        result = nil
        runError = nil
    }
}
