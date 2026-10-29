//
//  SignTypedDataViewModel.swift
//  toluTag
//
//  Two-stage EIP-712 sign: paste an eth_signTypedData_v4 document (+ optional
//  pin), then compute its digest and sign on the tag, recovering v. `{{signer}}`
//  in the JSON is replaced with the chip's own address. Mirrors the Java
//  eip712Sign tool.
//

import CoreNFC
import SwiftUI

@MainActor
@Observable
final class SignTypedDataViewModel {

    enum Stage { case setup, run }

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
        let signer: String
        let primaryType: String
        let digest: String
        let r: String
        let s: String
        let v: Int
        let recovered: Bool
        let envelope: String
    }

    var stage: Stage = .setup

    // Setup
    var objectIdText: String = "00000001"
    var json: String = ""
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
                Step(title: "Sign", hint: "encode the digest & sign on the tag")
            ]
        }
        return [Step(title: "Sign", hint: "encode the digest & sign on the tag")]
    }

    var canContinue: Bool {
        guard objectIdText.count == 8 else { return false }
        if pinOn {
            guard userObjectIdText.count == 8, pinText.count == 6, userObjectIdText != objectIdText else { return false }
        }
        return !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func loadMailExample() { json = Self.mailExample }

    // MARK: - Picker (keys only)

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
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setupError = "paste some eip-712 json"; return
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
        let document = json

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
                    let lower = EthereumAddress.from(publicKeyPoint: point) ?? "0x"
                    let upper = "0x" + lower.dropFirst(2).uppercased()

                    let filled = document.replacingOccurrences(of: "{{signer}}", with: lower)
                    let typedData = try Eip712TypedData.parse(filled)
                    let digest = try Eip712Encoder.digest(typedData)

                    let der = try await tag.signDigest(objectId: key.bytes, digest: digest)
                    guard let sig = EthereumSigner.makeSignature(der: der, hash: digest, publicKey: point) else {
                        throw Se05xError.apdu("parse signature", 0, 0)
                    }

                    let digestHex = "0x" + Hex.string(digest)
                    let envelope = "{\"signer\":\"\(upper)\",\"digest\":\"\(digestHex)\","
                        + "\"signature\":{\"r\":\"\(sig.r)\",\"s\":\"\(sig.s)\",\"v\":\(sig.v)}}"

                    return Result(
                        signer: upper, primaryType: typedData.primaryType, digest: digestHex,
                        r: sig.r, s: sig.s, v: sig.v, recovered: sig.recovered, envelope: envelope
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

    /// The canonical EIP-712 "Mail" example (nested Person structs). Its digest
    /// is 0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2.
    static let mailExample = """
    {
      "types": {
        "EIP712Domain": [
          {"name":"name","type":"string"},
          {"name":"version","type":"string"},
          {"name":"chainId","type":"uint256"},
          {"name":"verifyingContract","type":"address"}
        ],
        "Person": [
          {"name":"name","type":"string"},
          {"name":"wallet","type":"address"}
        ],
        "Mail": [
          {"name":"from","type":"Person"},
          {"name":"to","type":"Person"},
          {"name":"contents","type":"string"}
        ]
      },
      "primaryType": "Mail",
      "domain": {
        "name": "Ether Mail",
        "version": "1",
        "chainId": 1,
        "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      },
      "message": {
        "from": {"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
        "to": {"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
        "contents": "Hello, Bob!"
      }
    }
    """
}
