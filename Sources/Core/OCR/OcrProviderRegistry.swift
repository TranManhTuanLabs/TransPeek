import CoreGraphics
import Defaults
import Foundation

/// Selects which OCR provider runs a capture (SPEC §3.3, M2+M3).
/// Vision is always the default; Tesseract only runs when the user picked it
/// (or enabled it as fallback) AND the engine is actually installed.
/// Pure selection logic, covered by Swift Testing.
enum OcrProviderRegistry {
    /// Resolve the provider id to use.
    /// - Parameters:
    ///   - selectedID: `Defaults[.ocrProvider]` — `"vision"` or `"tesseract"`.
    ///   - tesseractAvailable: engine installed AND fallback enabled.
    /// - Returns: `.tesseract` only when explicitly selected and available;
    ///   anything else (unknown id, engine missing, not enabled) is Vision.
    static func resolve(selectedID: String, tesseractAvailable: Bool) -> OcrProviderID {
        if selectedID == OcrProviderID.tesseract.rawValue, tesseractAvailable {
            return .tesseract
        }
        return .vision
    }

    /// The provider for the next capture, from current Settings + install state.
    static func activeProvider() -> any OcrProvider {
        switch resolve(
            selectedID: Defaults[.ocrProvider],
            tesseractAvailable: Defaults[.ocrTesseractEnabled] && TesseractOCRProvider.isEngineAvailable
        ) {
        case .vision: return VisionOCRProvider()
        case .tesseract: return TesseractOCRProvider()
        }
    }

    /// Whether the Vision -> Tesseract automatic fallback may run after a
    /// Vision failure (SPEC §3.3: Vision -> Tesseract (if installed/enabled)).
    static var tesseractFallbackAvailable: Bool {
        Defaults[.ocrTesseractEnabled] && TesseractOCRProvider.isEngineAvailable
    }
}
