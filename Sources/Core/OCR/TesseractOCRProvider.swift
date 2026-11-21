// Tesseract is Apple Silicon only (Manh 2026-11-21, option B): the
// tesseract-Apple XCFramework ships arm64 slices only, so the Intel
// (x86_64) build has no Tesseract code at all — Intel uses Vision
// only (see ScreenCaptureOCR). Without this guard the universal
// Release build fails to link for x86_64 (CI #307: hundreds of
// undefined Tesseract symbols).
#if arch(arm64)
import AppKit
import CoreGraphics
import Defaults
import Foundation
import TesseractSwift

/// On-device OCR via Tesseract (fallback when Vision can't do it, Manh
/// 2026-11-20). Uses the community XCFramework through the
/// `TesseractSwift` SPM overlay. No network for recognition itself (a
/// language download only happens when a requested language is not
/// bundled and not yet installed — see
/// `TesseractLanguageDataManager`), no API key.
///
/// Vision stays the primary engine; this provider only runs when
/// Vision can't handle the request (see `ScreenCaptureOCR`).
struct TesseractOCRProvider: OcrProvider {
    let id = OcrProviderID.tesseract.rawValue
    let displayName = String(localized: "Tesseract (on-device fallback)")
    let needsNetwork = false
    let needsAPIKey = false

    /// All 34 OCR languages the app offers (`OCRSettingsView.availableLanguages`).
    /// Tesseract can recognise 31 of them: eng + vie are bundled, the
    /// other 29 download on demand. Arabic (Najdi) and the two Cantonese
    /// variants are Vision-only (no Tesseract model for them — `tessCode`
    /// returns nil and the provider skips them).
    var supportedLanguages: [String] {
        ["vi-VN", "en-US", "ar-SA", "ars-SA", "bg-BG", "cs-CZ", "da-DK",
         "de-DE", "el-GR", "es-ES", "fi-FI", "fr-FR", "he-IL", "hi-IN",
         "hu-HU", "id-ID", "it-IT", "ja-JP", "ko-KR", "ms-MY", "nb-NO",
         "nl-NL", "pl-PL", "pt-BR", "ro-RO", "ru-RU", "sv-SE", "th-TH",
         "tr-TR", "uk-UA", "yue-Hans", "yue-Hant", "zh-Hans", "zh-Hant"]
    }

    var status: String { String(localized: "Ready") }

    /// Map the requested BCP 47 languages to Tesseract codes, ensuring
    /// each one is available (bundled copy or download). A language
    /// that cannot be made available is dropped. Falls back to `eng`
    /// (bundled, always available) when nothing else remains.
    private func effectiveTessCodes() async -> [String] {
        let requested = Defaults[.ocrLanguages]
        var codes: [String] = []
        for bcp47 in requested {
            guard let code = TesseractLanguageDataManager.tessCode(forBCP47: bcp47) else { continue }
            // Skip duplicates (e.g. "en-US" and "en" both map to "eng").
            guard !codes.contains(code) else { continue }
            do {
                try await TesseractLanguageDataManager.ensureLanguageAvailable(code)
                codes.append(code)
            } catch {
                // Language unavailable (e.g. download failed offline) —
                // drop it and keep the rest instead of failing the OCR.
                continue
            }
        }
        return codes.isEmpty ? ["eng"] : codes
    }

    func recognizeText(in cgImage: CGImage) async throws -> String {
        let codes = await effectiveTessCodes()
        let language = codes.joined(separator: "+")

        // The datapath is the directory that DIRECTLY holds the
        // .traineddata files — NOT its parent. The tesseract-Apple
        // demo proves this: it passes Bundle.main.resourcePath as the
        // datapath with eng.traineddata sitting flat in Resources
        // (no "tessdata" subfolder), and Tesseract finds it there.
        // The earlier code passed the PARENT of the tessdata folder
        // (assuming Tesseract appends "tessdata" itself) — that is
        // why init failed even though the files were present
        // (CI #304/#306: `.initializationFailed(-1)`).
        let dataPath = TesseractLanguageDataManager.tessdataDirectory.path

        let nsImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        let config = OCRConfig(language: language, dataPath: dataPath)
        let result = try await TesseractSwiftClient.recognize(image: nsImage, config: config)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw OCRError.noTextRecognized
        }
        return result.text
    }
}

#endif
