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
            .appendingPathComponent("peektrans_ocr_\(UUID().uuidString).png")
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

    /// Recognition is owned by `VisionOCRProvider`; this keeps the capture flow
    /// (temp file, `screencapture -i`, cancellation) unchanged.
    private static func recognizeText(in image: CGImage) async throws -> String {
        try await VisionOCRProvider().recognizeText(in: image)
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
