//
//  ScanViewModel.swift
//  toluTag
//
//  Two-stage scan tag: configure what to read (an object id + optional PIN, or
//  nothing for a general card scan), then run the read and show the details.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class ScanViewModel {

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
        let kind: String            // "key" or "string"
        let pinObjectID: String?
        let pin: String?
        var phoneKeyObjectID: String? = nil
    }

    var stage: Stage = .setup

    // Setup
    var objectIdText: String = ""
    var setupError: String?

    // Optional protection — needed to read a protected object: a PIN
    // (UserID) session, or this iPhone's key (an encrypted ECKey session).
    var protectOn: Bool = false
    var method: ProtectionMethod = .pin
    var userObjectIdText: String = ""
    var pinText: String = ""
    var pinVisible: Bool = false
    var phoneKeyObjectIdText: String = ""

    var pinOn: Bool { protectOn && method == .pin && !cardOnly }
    var ecKeyOn: Bool { protectOn && method == .ecKey && !cardOnly }

    // Picker
    var pickerPresented = false
    private(set) var options: [Option] = []
    private(set) var unlocking = false

    // Run
    private(set) var currentStep: Int = -1
    private(set) var running: Bool = false
    private(set) var failedStep: Int = -1
    private(set) var result: ScanResult?
    private(set) var runError: String?

    // Import: offer to save an object that isn't in the records yet.
    var saveLabel: String = ""
    private(set) var didSave = false

    private let runner = Se05xNfcRunner()

    var isNfcAvailable: Bool { NFCTagReaderSession.readingAvailable }
    var isComplete: Bool { result != nil }
    var cardOnly: Bool { objectIdText.isEmpty }

    var steps: [Step] {
        if cardOnly {
            return [Step(title: "Read card", hint: "read the tag's general details")]
        }
        if pinOn || ecKeyOn {
            return [
                Step(title: "Authenticate",
                     hint: ecKeyOn ? "face id, then this iphone's encrypted session" : "open a pin session"),
                Step(title: "Read object", hint: "read its type, details & value")
            ]
        }
        return [Step(title: "Read object", hint: "read its type, details & value")]
    }

    var canContinue: Bool {
        if !cardOnly, objectIdText.count != 8 { return false }
        if pinOn {
            return userObjectIdText.count == 8 && pinText.count == 6 && userObjectIdText != objectIdText
        }
        if ecKeyOn {
            return phoneKeyObjectIdText.count == 8 && phoneKeyObjectIdText != objectIdText
        }
        return true
    }

    var actionTitle: String {
        if isComplete { return "Done" }
        if running { return "Hold the tag…" }
        return cardOnly ? "Scan card" : "Scan tag"
    }

    func state(for index: Int) -> StepState {
        if failedStep == index { return .error }
        if isComplete || index < currentStep { return .done }
        if index == currentStep { return running ? .active : .pending }
        return .pending
    }

    // MARK: - Import / save

    enum SaveKind: Equatable { case key, string }

    /// What could be saved from this scan — a key or a string — if the object
    /// exists, carries a value, and isn't already in the records.
    var saveKind: SaveKind? {
        guard let object = result?.object, object.exists, result?.matchedLabel == nil else { return nil }
        if object.publicKey != nil { return .key }
        if object.text != nil { return .string }
        return nil
    }

    var canOfferSave: Bool { saveKind != nil && !didSave }
    var canSave: Bool { !saveLabel.trimmingCharacters(in: .whitespaces).isEmpty }

    func saveRecord() {
        guard let object = result?.object, let kind = saveKind, canSave else { return }
        let label = saveLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = CardUid.normalize(result?.chip.uniqueId)
        switch kind {
        case .key:
            KeyStore.shared.add(KeyRecord(
                label: label,
                keyObjectID: object.objectId,
                pinObjectID: pinOn ? userObjectIdText : nil,
                publicKey: object.publicKey,
                address: object.address,
                pin: pinOn ? pinText : nil,
                phoneKeyObjectID: ecKeyOn ? phoneKeyObjectIdText : nil,
                deletable: object.deletable ?? false,
                uniqueId: uid,
                createdAt: Date()
            ))
        case .string:
            KeyStore.shared.addString(StringRecord(
                label: label,
                objectID: object.objectId,
                text: object.text ?? "",
                deletable: object.deletable ?? true,
                uniqueId: uid,
                createdAt: Date()
            ))
        }
        didSave = true
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
                    Option(label: $0.label, objectID: $0.keyObjectID, kind: "key",
                           pinObjectID: $0.pinObjectID, pin: $0.pin, phoneKeyObjectID: $0.phoneKeyObjectID)
                } + KeyStore.shared.allStrings().map {
                    Option(label: $0.label, objectID: $0.objectID, kind: "string",
                           pinObjectID: nil, pin: nil)
                }
                self.pickerPresented = true
            }
        }
    }

    func select(_ option: Option) {
        objectIdText = option.objectID
        userObjectIdText = ""
        pinText = ""
        phoneKeyObjectIdText = ""
        if let phoneKeyObjectID = option.phoneKeyObjectID {
            protectOn = true
            method = .ecKey
            phoneKeyObjectIdText = phoneKeyObjectID
        } else if let pinObjectID = option.pinObjectID, let pin = option.pin, !pin.isEmpty {
            protectOn = true
            method = .pin
            userObjectIdText = pinObjectID
            pinText = pin
        } else {
            protectOn = false
        }
        pickerPresented = false
    }

    // MARK: - Stage navigation

    func goToRun() {
        if !cardOnly {
            guard objectIdText.count == 8 else { setupError = "object id must be 8 hex digits"; return }
        }
        if pinOn {
            guard userObjectIdText.count == 8 else { setupError = "pin object id must be 8 hex digits"; return }
            guard pinText.count == 6 else { setupError = "pin must be 6 digits"; return }
            guard userObjectIdText != objectIdText else {
                setupError = "the pin object id must differ from the object id"; return
            }
        }
        if ecKeyOn {
            guard phoneKeyObjectIdText.count == 8 else { setupError = "phone key object id must be 8 hex digits"; return }
            guard phoneKeyObjectIdText != objectIdText else {
                setupError = "the phone key object id must differ from the object id"; return
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
        let key = cardOnly ? nil : ObjectId.parse(objectIdText)
        if !cardOnly, key == nil { runError = "invalid object id"; return }
        let user = pinOn ? ObjectId.parse(userObjectIdText) : nil
        let pinBytes = pinOn ? Array(pinText.utf8) : nil
        let phoneKeySlot = ecKeyOn ? ObjectId.parse(phoneKeyObjectIdText) : nil
        let useECKey = ecKeyOn

        resetRun()
        running = true
        currentStep = 0

        Task {
            do {
                // Face ID before the NFC sheet, so the two prompts never overlap.
                let signer = useECKey ? try await DeviceKey.unlock(reason: "Unlock this iPhone's key to read the tag") : nil
                let scanned: ScanResult = try await runner.run(alertMessage: "Hold your iPhone near the tolu tag") { [weak self] tag in
                    // --- Chip details (best-effort, before any session) ---
                    var chip = ScanResult.ChipDetails()
                    chip.uniqueId = try? await tag.readUniqueId()
                    if let version = try? await tag.getVersion() {
                        chip.appletVersionRaw = version.rawHex
                        chip.appletVersion = version.versionString
                        chip.secureBoxVersion = version.secureBoxVersion
                        chip.features = version.features
                    }
                    chip.persistentFreeMemory = try? await tag.getFreeMemory(Se05x.memPersistent)
                    chip.transientResetFreeMemory = try? await tag.getFreeMemory(Se05x.memTransientReset)
                    chip.transientDeselectFreeMemory = try? await tag.getFreeMemory(Se05x.memTransientDeselect)

                    if let user, let pinBytes {
                        try await tag.openUserIdSession(userObjectId: user.bytes, pin: pinBytes)
                        self?.advance(to: 1)
                    } else if let phoneKeySlot, let signer {
                        try await tag.openECKeySession(authObjectId: phoneKeySlot.bytes, signer: signer)
                        self?.advance(to: 1)
                    }

                    guard let key else {
                        return ScanResult(chip: chip, object: nil, matchedLabel: nil)
                    }

                    // --- Object details (best-effort) ---
                    let exists = (try? await tag.exists(objectId: key.bytes)) ?? false
                    var object = ScanResult.ObjectDetails(objectId: key.hex, exists: exists)

                    if exists {
                        object.typeByte = try? await tag.readTypeByte(objectId: key.bytes)
                        if let typeByte = object.typeByte {
                            object.type = SecureObjectType.describe(typeByte)
                        }
                        object.sizeBytes = try? await tag.readSize(objectId: key.bytes)

                        if let attributes = try? await tag.readAttributes(objectId: key.bytes) {
                            object.origin = attributes.origin
                            object.isAuthenticationObject = attributes.isAuthenticationObject
                            object.versionAttribute = attributes.version
                            object.policyRaw = attributes.policyHex
                            object.attributesRaw = attributes.rawHex
                            object.deletable = attributes.allowsDelete
                        }

                        let lower = (object.type ?? "").lowercased()
                        if lower.contains("binary") {
                            if let bytes = try? await tag.readBinary(objectId: key.bytes) {
                                object.text = Self.decodeText(bytes)
                            }
                        } else if let point = try? await tag.readPublicKeyPoint(objectId: key.bytes) {
                            object.publicKey = "0x" + Hex.string(point)
                            object.address = EthereumAddress.from(publicKeyPoint: point)
                        }
                    }

                    return ScanResult(chip: chip, object: object, matchedLabel: nil)
                }
                running = false
                result = scanned
                if let object = scanned.object {
                    result?.matchedLabel = Self.matchedLabel(objectHex: object.objectId,
                                                             uid: scanned.chip.uniqueId)
                }
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

    /// Looks up a saved record's label matching this object id *and* card. A
    /// record with no stored uid matches on object id alone (backward compat);
    /// one with a uid matches only its own card. Keychain read, no prompt.
    @MainActor
    private static func matchedLabel(objectHex: String, uid: String?) -> String? {
        let target = objectHex.uppercased()
        for record in KeyStore.shared.all()
        where record.keyObjectID.uppercased() == target && cardMatches(record.uniqueId, uid) {
            return record.label.isEmpty ? nil : record.label
        }
        for record in KeyStore.shared.allStrings()
        where record.objectID.uppercased() == target && cardMatches(record.uniqueId, uid) {
            return record.label.isEmpty ? nil : record.label
        }
        return nil
    }

    /// A record matches the scanned card when it has no stored uid, or its uid
    /// equals the scanned one.
    private static func cardMatches(_ recordUid: String?, _ scannedUid: String?) -> Bool {
        recordUid == nil || CardUid.sameCard(recordUid, scannedUid)
    }

    /// Decodes bytes to text, trimming trailing NULs; falls back to hex if it
    /// isn't valid UTF-8.
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
