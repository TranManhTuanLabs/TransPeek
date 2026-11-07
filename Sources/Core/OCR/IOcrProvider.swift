import CoreGraphics
import Foundation

/// Identifies an OCR engine. New providers (e.g. Tesseract, Phase 2) add a case here.
enum OcrProviderID: String, Sendable, CaseIterable {
    case vision
}

/// A screenshot-OCR engine behind the common provider interface (SPEC v0.1 §3.3).
/// Providers are value types so callers can hold them without actor isolation;
/// recognition itself is async and runs off the main actor.
protocol OcrProvider: Sendable {
    /// Stable identifier, e.g. `OcrProviderID.vision.rawValue`.
    var id: String { get }
    /// User-visible name shown in Settings.
    var displayName: String { get }
    /// Whether recognition needs network access.
    var needsNetwork: Bool { get }
    /// Whether recognition needs a user-supplied API key.
    var needsAPIKey: Bool { get }
    /// BCP 47 language codes the provider can recognise (e.g. `["vi-VN", "en-US"]`).
    var supportedLanguages: [String] { get }
    /// Short user-visible status, e.g. "Ready".
    var status: String { get }

    /// Recognize text in an image. Throws `OCRError.noTextRecognized` when nothing is found.
    func recognizeText(in cgImage: CGImage) async throws -> String
}
