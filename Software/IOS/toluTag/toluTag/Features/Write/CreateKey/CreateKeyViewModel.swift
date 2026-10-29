//
//  CreateKeyViewModel.swift
//  toluTag
//
//  Two-stage create: configure the slots (PIN optional), then run it as taps.
//  With a PIN: create tap, then verify tap (session read). Without a PIN: a
//  single create tap that also reads the key back.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class CreateKeyViewModel {

    enum Stage {
        case setup
        case run
    }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let hint: String
    }

    var stage: Stage = .setup

    // Setup
    var label: String = ""
    var keyObjectIdText: String = "00000001"
    var protectOn: Bool = true
    var method: ProtectionMethod = .pin
    var userObjectIdText: String = "00000002"
    var phoneKeyObjectIdText: String = "00000002"
    var pinText: String = ""
    var pinVisible: Bool = false
    var allowDelete: Bool = false
    var setupError: String?

    var pinOn: Bool { protectOn && method == .pin }
    var ecKeyOn: Bool { protectOn && method == .ecKey }

    // Run
    var steps: [Step] {
        if ecKeyOn {
            return [Step(title: "Create the key", hint: "face id, then one tap: made & bound to this iphone")]
        }
        if pinOn {
            return [
                Step(title: "Create the key", hint: "write secp256k1 + pin to the tag"),
                Step(title: "Verify", hint: "tap again to read the public key")
            ]
        } else {
            return [Step(title: "Create the key", hint: "write secp256k1 & read it back")]
        }
    }
    private(set) var currentStep: Int = 0
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var verifiedAddress: String?
    private(set) var verifiedPublicKey: String?
    private(set) var cardUniqueId: String?
    private(set) var runError: String?

    private let writer = SE050ProtectedKeyPairWriter()
    private let reader = SE050ProtectedKeyReader()
    private let runner = Se05xNfcRunner()
    /// An ECKey tap of this run got as far as writing the key, so a retry
    /// reads the slot instead of refusing it as taken.
    private var keyWriteStarted = false

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { currentStep >= steps.count }

    private var saved = false

    var canContinue: Bool {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard keyObjectIdText.count == 8 else { return false }
        if pinOn {
            return userObjectIdText.count == 8 && pinText.count == 6 && keyObjectIdText != userObjectIdText
        }
        if ecKeyOn {
            return phoneKeyObjectIdText.count == 8 && keyObjectIdText != phoneKeyObjectIdText
        }
        return true
    }

    var runHint: String {
        if ecKeyOn { return "face id, then one tap: the key is made inside an encrypted session and read back." }
        return pinOn ? "tap once to create, then tap again to read back and verify." : "one tap creates the key and reads it back."
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return currentStep == 0 ? "Scan to create" : "Scan to verify"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    // MARK: - Stage navigation

    func goToRun() {
        guard keyObjectIdText.count == 8 else { setupError = "key object id must be 8 hex digits"; return }
        if pinOn {
            guard userObjectIdText.count == 8 else { setupError = "pin object id must be 8 hex digits"; return }
            guard pinText.count == 6 else { setupError = "pin must be 6 digits"; return }
            guard keyObjectIdText != userObjectIdText else {
                setupError = "the pin object id must differ from the key object id"; return
            }
        }
        if ecKeyOn {
            guard phoneKeyObjectIdText.count == 8 else { setupError = "phone key object id must be 8 hex digits"; return }
            guard keyObjectIdText != phoneKeyObjectIdText else {
                setupError = "the phone key object id must differ from the key object id"; return
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

    // MARK: - Run steps

    func runCurrentStep() {
        guard !running, !isComplete else { return }
        guard let key = ObjectId.parse(keyObjectIdText) else { runError = "invalid key object id"; return }
        let user = ObjectId.parse(userObjectIdText)
        running = true
        runError = nil
        failedStep = -1

        if ecKeyOn {
            guard let slot = ObjectId.parse(phoneKeyObjectIdText) else {
                running = false; runError = "invalid phone key object id"; return
            }
            Task { await createWithPhoneKey(key: key, slot: slot) }
            return
        }

        if currentStep == 0 {
            writer.onFinish = { [weak self] outcome in
                Task { @MainActor in self?.handleCreate(outcome) }
            }
            writer.createProtectedKeyPair(
                userID: pinText,
                userIDObjectID: user?.hex ?? "00000000",
                keyObjectID: key.hex,
                deletable: allowDelete,
                usePin: pinOn,
                alert: "Hold the tag to create the key."
            )
        } else {
            reader.onFinish = { [weak self] outcome in
                Task { @MainActor in self?.handleVerify(outcome) }
            }
            reader.read(userIDObjectID: user?.hex ?? "00000000", keyObjectID: key.hex, pin: pinText,
                        alert: "Hold the tag again to verify.")
        }
    }

    private func handleCreate(_ outcome: Result<ProtectedKeyConfiguration, Error>) {
        running = false
        switch outcome {
        case let .success(config):
            cardUniqueId = CardUid.normalize(config.uniqueId)
            if !pinOn, let responseHex = config.publicKey, let parsed = point(fromResponseHex: responseHex) {
                verifiedPublicKey = parsed.point
                verifiedAddress = parsed.address
            }
            currentStep = 1
            saveIfComplete()
        case let .failure(error):
            failedStep = 0
            runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleVerify(_ outcome: Result<String, Error>) {
        running = false
        switch outcome {
        case let .success(publicKeyHex):
            verifiedPublicKey = "0x" + publicKeyHex
            verifiedAddress = Hex.bytes(publicKeyHex).flatMap { EthereumAddress.from(publicKeyPoint: $0) }
            currentStep = 2
            saveIfComplete()
        case let .failure(error):
            failedStep = 1
            runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Face ID, then one tap: the curves, this iPhone's public key as an ECKey
    /// authentication object (or the one already there), an encrypted session
    /// opened with it, the key generated inside that session with a policy
    /// naming only that object, and the public key read back.
    private func createWithPhoneKey(key: ObjectId, slot: ObjectId) async {
        do {
            let signer = try await DeviceKey.unlock(reason: "Bind the new key to this iPhone")
            let resuming = keyWriteStarted
            var mask = EcKeyPolicy.sign | EcKeyPolicy.verify | EcKeyPolicy.read
            if allowDelete { mask |= EcKeyPolicy.delete }
            let policy = EcKeyPolicy(authId: slot.authId, mask: mask)

            let (point, uid) = try await runner.run(alertMessage: "Hold the tag to create the key.") { tag in
                let uid = try? await tag.readUniqueId()
                let keyExists = try await tag.exists(objectId: key.bytes)
                if keyExists && !resuming { throw Se05xError.keySlotInUse }
                let phoneSlot = try await tag.phoneKeySlot(slot.bytes, publicKey: signer.publicKey)
                if phoneSlot == .taken { throw Se05xError.phoneKeySlotTaken }

                if !keyExists { await tag.initializeSecp256k1Curve() }
                if phoneSlot == .free {
                    try await tag.initializeNistP256Curve()
                    try await tag.writePhoneKey(slot.bytes, publicKey: signer.publicKey)
                }
                try await tag.openECKeySession(authObjectId: slot.bytes, signer: signer)
                if !keyExists {
                    self.keyWriteStarted = true
                    try await tag.createSecp256k1KeyPair(objectId: key.bytes, policy: policy)
                }
                return (try await tag.readPublicKeyPoint(objectId: key.bytes), uid)
            }

            cardUniqueId = CardUid.normalize(uid)
            verifiedPublicKey = "0x" + Hex.string(point)
            verifiedAddress = EthereumAddress.from(publicKeyPoint: point)
            running = false
            currentStep = steps.count
            saveIfComplete()
        } catch {
            running = false
            failedStep = 0
            runError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Finds the 65-byte uncompressed point inside a raw read response and
    /// derives its address.
    private func point(fromResponseHex hex: String) -> (point: String, address: String?)? {
        guard let bytes = Hex.bytes(hex) else { return nil }
        var i = 0
        while i + 65 <= bytes.count {
            if bytes[i] == 0x04 {
                let pointBytes = Array(bytes[i..<i + 65])
                return ("0x" + Hex.string(pointBytes), EthereumAddress.from(publicKeyPoint: pointBytes))
            }
            i += 1
        }
        return nil
    }

    private func saveIfComplete() {
        guard isComplete, !saved else { return }
        saved = true
        KeyStore.shared.add(KeyRecord(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            keyObjectID: keyObjectIdText,
            pinObjectID: pinOn ? userObjectIdText : nil,
            publicKey: verifiedPublicKey,
            address: verifiedAddress,
            pin: pinOn ? pinText : nil,
            phoneKeyObjectID: ecKeyOn ? phoneKeyObjectIdText : nil,
            deletable: allowDelete,
            uniqueId: cardUniqueId,
            createdAt: Date()
        ))
    }

    private func resetRun() {
        currentStep = 0
        running = false
        failedStep = -1
        verifiedAddress = nil
        verifiedPublicKey = nil
        cardUniqueId = nil
        runError = nil
        saved = false
        keyWriteStarted = false
    }
}
