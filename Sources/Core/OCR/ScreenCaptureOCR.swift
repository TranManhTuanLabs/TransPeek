import AppKit
import Defaults
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

    /// Run `/usr/sbin/screencapture` with the given arguments (interactive
    /// selection). Throws `OCRError.captureCancelled` when the user cancels
    /// (Esc) or the tool exits non-zero. Shared by the image, OCR, and
    /// clipboard capture paths so the Process + cancellation behaviour stays
    /// identical everywhere.
    private static func runScreencapture(arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

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
    }

    /// Launch interactive screen capture and return the captured image.
    /// The temp file is deleted before returning.
    static func captureImage() async throws -> CGImage {
        // Generate a unique temp file path to avoid concurrency conflicts
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transpeek_ocr_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Run screencapture -i <tmpPath> (interactive selection → temp file, clipboard untouched)
        try await runScreencapture(arguments: ["-i", tmpURL.path])

        // Read image from temp file inside autoreleasepool to ensure large
        // screenshot images are freed promptly.
        let cgImage: CGImage = try autoreleasepool {
            guard let image = NSImage(contentsOf: tmpURL),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                throw OCRError.captureReadFailed
            }
            return cg
        }
        return cgImage
    }

    /// Launch interactive screen capture and copy the captured image straight
    /// to the clipboard via the system `-c` flag. No OCR, no temp file, no panel.
    static func captureImageToClipboard() async throws {
        try await runScreencapture(arguments: ["-i", "-c"])
    }

    /// Launch interactive screen capture, OCR the captured image, and return recognized text.
    static func captureAndRecognize() async throws -> String {
        let cgImage = try await captureImage()
        return try await recognizeText(in: cgImage)
    }

    /// Whether to skip Vision and go straight to Tesseract: true when
    /// Vision supports NONE of the requested languages. Without this
    /// check Vision would silently fall back to en-US and misread the
    /// requested language (e.g. Vietnamese as English) instead of
    /// failing, so the fallback would never trigger. Pure logic, so it
    /// is tested directly (no Vision calls).
    static func shouldSkipVision(requested: [String], visionSupported: [String]) -> Bool {
        Set(visionSupported).isDisjoint(with: requested)
    }

    /// Recognition: Vision first (primary), Tesseract as fallback
    /// (Manh 2026-11-20). Tesseract runs when Vision can't handle the
    /// request — either Vision supports none of the requested languages
    /// (skip straight to Tesseract), or Vision throws (e.g. no text
    /// found — Tesseract gets a chance before giving up). The capture
    /// flow (temp file, `screencapture -i`, cancellation) is unchanged.
    private static func recognizeText(in image: CGImage) async throws -> String {
        let vision = VisionOCRProvider()
        let requested = Defaults[.ocrLanguages]
        if !shouldSkipVision(requested: requested, visionSupported: vision.supportedLanguages) {
            do {
                return try await vision.recognizeText(in: image)
            } catch {
                // Vision failed — try Tesseract before giving up.
                // Tesseract is Apple Silicon only (Manh 2026-11-21,
                // option B): on Intel there is no fallback engine,
                // so the Vision error is rethrown as-is.
                #if arch(arm64)
                return try await TesseractOCRProvider().recognizeText(in: image)
                #else
                throw error
                #endif
            }
        }
        #if arch(arm64)
        return try await TesseractOCRProvider().recognizeText(in: image)
        #else
        // Intel (x86_64): Tesseract is arm64-only, so there is no
        // fallback engine. Vision supports none of the requested
        // languages here, so nothing can read the image.
        throw OCRError.noTextRecognized
        #endif
    }
}

enum OCRError: LocalizedError {
    case captureCancelled
    case captureReadFailed
    case noTextRecognized

    var errorDescription: String? {
        switch self {
        case .captureCancelled:  String(localized: "Screen capture was cancelled")
        case .captureReadFailed: String(localized: "Failed to read the captured image")
        case .noTextRecognized:  String(localized: "No text was recognized in the captured image")
        }
    }
}
