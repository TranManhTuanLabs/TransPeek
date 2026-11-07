import CoreGraphics
import Defaults
import Foundation
import os
import Vision

/// On-device OCR via Vision (`VNRecognizeTextRequest`). Default provider on macOS (SPEC v0.1 §3.3).
/// No network, no API key. Vietnamese support depends on the macOS version and is
/// checked at runtime against `VNRecognizeTextRequest.supportedRecognitionLanguages`.
struct VisionOCRProvider: OcrProvider {
    let id = OcrProviderID.vision.rawValue
    let displayName = String(localized: "Vision (on-device)")
    let needsNetwork = false
    let needsAPIKey = false

    /// Languages Vision reports as supported on this Mac.
    var supportedLanguages: [String] {
        Array(VNRecognizeTextRequest.supportedRecognitionLanguages)
    }

    var status: String { String(localized: "Ready") }

    /// Filter the requested languages down to what Vision supports on this Mac.
    /// - Parameters:
    ///   - requested: Languages the user asked for, in preference order.
    ///   - supported: Languages Vision reports as supported on this Mac.
    /// - Returns: The languages to pass to Vision, plus whether language correction
    ///   is safe to enable. Correction is only enabled when Vietnamese survived
    ///   filtering: without Vietnamese support, English correction would "fix"
    ///   Vietnamese words into English ones. An empty request falls back to `["en-US"]`.
    static func effectiveLanguages(
        requested: [String],
        supported: [String]
    ) -> (languages: [String], useCorrection: Bool) {
        let supportedSet = Set(supported)
        var languages = requested.filter { supportedSet.contains($0) }
        if languages.isEmpty {
            languages = ["en-US"]
        }
        return (languages, languages.contains("vi-VN"))
    }

    func recognizeText(in cgImage: CGImage) async throws -> String {
        let effective = Self.effectiveLanguages(
            requested: Defaults[.ocrLanguages],
            supported: supportedLanguages
        )

        return try await withCheckedThrowingContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)

            let request = VNRecognizeTextRequest { request, error in
                guard Self.claimOnce(resumed) else { return }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextRecognized)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            // Explicit language list, not auto-detection: the user picks OCR languages in Settings.
            request.automaticallyDetectsLanguage = false
            request.recognitionLanguages = effective.languages
            request.usesLanguageCorrection = effective.useCorrection

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
