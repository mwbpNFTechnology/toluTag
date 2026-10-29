//
//  Se05xNfcRunner.swift
//  toluTag
//
//  Runs one SE05x operation over a CoreNFC session: begins the session, connects
//  to the tag (completion-based, like the proven tolu reader), selects the
//  applet, then invokes a caller-supplied body with a connected `Se05xTag`.
//

import CoreNFC
import Foundation

final class Se05xNfcRunner: NSObject {

    private var session: NFCTagReaderSession?
    private var perform: ((NFCISO7816Tag, NFCTagReaderSession) async -> Void)?
    private var onInvalidate: ((Error) -> Void)?
    private var didFinish = false
    private let lock = NSLock()

    /// Begins an NFC session and runs `body` against the connected tag.
    func run<T>(
        alertMessage: String,
        _ body: @escaping (Se05xTag) async throws -> T
    ) async throws -> T {
        guard NFCTagReaderSession.readingAvailable else { throw Se05xError.nfcUnavailable }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            didFinish = false

            perform = { [weak self] iso7816, session in
                guard let self else { return }
                do {
                    let tag = Se05xTag(iso7816)
                    try await tag.selectApplet()
                    let result = try await body(tag)
                    session.alertMessage = "Done."
                    self.finish { continuation.resume(returning: result) }
                    session.invalidate()
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? "Operation failed."
                    self.finish { continuation.resume(throwing: error) }
                    session.invalidate(errorMessage: message)
                }
            }

            onInvalidate = { error in
                self.finish { continuation.resume(throwing: error) }
            }

            guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main) else {
                finish { continuation.resume(throwing: Se05xError.nfcUnavailable) }
                return
            }
            session.alertMessage = alertMessage
            self.session = session
            session.begin()
        }
    }

    private func finish(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        action()
        perform = nil
        onInvalidate = nil
    }
}

extension Se05xNfcRunner: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        onInvalidate?(error)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            let error = Se05xError.notSupportedTag
            session.invalidate(errorMessage: error.localizedDescription)
            onInvalidate?(error)
            return
        }
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Couldn't connect to the tag.")
                self.onInvalidate?(error)
                return
            }
            guard case let .iso7816(iso7816) = tag else {
                let unsupported = Se05xError.notSupportedTag
                session.invalidate(errorMessage: unsupported.localizedDescription)
                self.onInvalidate?(unsupported)
                return
            }
            Task { await self.perform?(iso7816, session) }
        }
    }
}
