import CoreGraphics
import Foundation
import os
import Vision

/// Barcode / QR code detection via Vision (`VNDetectBarcodesRequest`).
/// Returns the payload strings of the detected codes, in detection order.
/// Detection is on-device; no network, no API key. Callers decide what to do
/// with a payload (open a URL, copy text, ...).
enum BarcodeScanner {
    static func detectPayloads(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)

            let request = VNDetectBarcodesRequest { request, error in
                guard Self.claimOnce(resumed) else { return }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let payloads = (request.results as? [VNBarcodeObservation] ?? [])
                    .compactMap { $0.payloadStringValue }
                    .filter { !$0.isEmpty }
                continuation.resume(returning: payloads)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard Self.claimOnce(resumed) else { return }
                continuation.resume(throwing: error)
            }
        }
    }

    /// Atomically claim a one-shot flag. Returns `true` on first call, `false` thereafter.
    private static func claimOnce(_ lock: OSAllocatedUnfairLock<Bool>) -> Bool {
        lock.withLock { val in
            if val { return false }
            val = true
            return true
        }
    }
}
