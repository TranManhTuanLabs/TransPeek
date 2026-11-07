import AppKit
import os

enum ScreenCaptureOCR {
    /// Atomically claim a one-shot flag. Returns `true` on first call, `false` thereafter.
    private static func claimOnce(_ lock: OSAllocatedUnfairLock<Bool>) -> Bool {
        lock.withLock { val in
            if val { return false }
            val = true
            return true
        }
    }
    /// Launch interactive screen capture, OCR the captured image, and return recognized text.
    static func captureAndRecognize() async throws -> String {
        // Generate a unique temp file path to avoid concurrency conflicts
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transpeek_ocr_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Run screencapture -i <tmpPath> (interactive selection → temp file, clipboard untouched)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tmpURL.path]

        let status = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                let resumed = OSAllocatedUnfairLock(initialState: false)

                process.terminationHandler = { proc in
                    guard claimOnce(resumed) else { return }
                    continuation.resume(returning: proc.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    guard claimOnce(resumed) else { return }
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }

        guard status == 0 else {
            throw OCRError.captureCancelled
        }

        // Read image from temp file and perform OCR inside autoreleasepool
        // to ensure large screenshot images are freed promptly.
        let cgImage: CGImage = try autoreleasepool {
            guard let image = NSImage(contentsOf: tmpURL),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                throw OCRError.captureReadFailed
            }
            return cg
        }

        return try await recognizeText(in: cgImage)
    }

    /// Recognition is routed through `OcrProviderRegistry` (M2+M3): Vision
    /// by default, Tesseract when selected. On failure the other engine gets
    /// one try (Vision -> Tesseract when fallback is enabled, Tesseract ->
    /// Vision otherwise); the original error is reported if both fail.
    private static func recognizeText(in image: CGImage) async throws -> String {
        let primary = OcrProviderRegistry.activeProvider()
        do {
            return try await primary.recognizeText(in: image)
        } catch {
            let fallback: (any OcrProvider)?
            if primary.id == OcrProviderID.vision.rawValue {
                fallback = OcrProviderRegistry.tesseractFallbackAvailable
                    ? TesseractOCRProvider() : nil
            } else {
                fallback = VisionOCRProvider()
            }
            guard let fallback else { throw error }
            do {
                return try await fallback.recognizeText(in: image)
            } catch {
                throw error
            }
        }
    }
}

enum OCRError: LocalizedError {
    case captureCancelled
    case captureReadFailed
    case noTextRecognized
    /// Tesseract engine or its language data is missing (M2+M3).
    case tesseractNotInstalled
    /// An OCR engine ran but failed (e.g. tesseract stderr).
    case engineFailed(String)

    var errorDescription: String? {
        switch self {
        case .captureCancelled:  String(localized: "Screen capture was cancelled")
        case .captureReadFailed: String(localized: "Failed to read the captured image")
        case .noTextRecognized:  String(localized: "No text was recognized in the captured image")
        case .tesseractNotInstalled:
            String(localized: "Tesseract is not installed or its language data is missing. Install it with: brew install tesseract tesseract-lang, or download languages in Settings → OCR.")
        case let .engineFailed(detail):
            String(localized: "OCR engine failed: \(detail)")
        }
    }
}
