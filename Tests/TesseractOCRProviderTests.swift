import AppKit
import CoreGraphics
import Defaults
import Foundation
import Testing
@testable import TransPeek

/// Spike + unit tests for the Tesseract OCR fallback (Manh 2026-11-20).
///
/// The recognition test is the spike: it proves the XCFramework engine
/// links, loads its language data, and recognises real text on Apple
/// Silicon. It draws a clean test image (no committed binary image)
/// and runs the real provider against the bundled eng data.
///
/// Apple Silicon only (Manh 2026-11-21, option B): the provider does
/// not exist on Intel, so these tests are skipped there.
#if arch(arm64)
@Suite struct TesseractOCRProviderTests {
    /// Draw `text` in large black type on a white image. Big, clean
    /// type so the engine is tested on loading + recognition, not on
    /// reading tiny or noisy glyphs. Throws (instead of crashing) if
    /// the image cannot be rendered, so a rendering problem fails the
    /// test instead of crashing the runner.
    private func makeTestImage(text: String) throws -> CGImage {
        let size = NSSize(width: 800, height: 200)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .regular),
            .foregroundColor: NSColor.black,
        ]
        NSAttributedString(string: text, attributes: attributes)
            .draw(at: NSPoint(x: 20, y: 55))
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TestImageError.couldNotRender
        }
        return cgImage
    }

    /// Error rendering the test image (not an OCR failure).
    private enum TestImageError: Error {
        case couldNotRender
    }

    /// SPIKE: the engine recognises English text from a generated image.
    /// This is the test that proves the XCFramework approach works —
    /// if it fails, the engine (not the app code) is the problem.
    @Test func recognizesEnglishText() async throws {
        // Pin the requested languages to English so the test does not
        // depend on whatever the user has selected; restore afterwards.
        let saved = Defaults[.ocrLanguages]
        Defaults[.ocrLanguages] = ["en-US"]
        defer { Defaults[.ocrLanguages] = saved }

        let image = try makeTestImage(text: "Hello World")
        let provider = TesseractOCRProvider()
        let text = try await provider.recognizeText(in: image)
        #expect(text.localizedCaseInsensitiveContains("Hello"))
        #expect(text.localizedCaseInsensitiveContains("World"))
    }

    /// SPIKE: the engine recognises Vietnamese text (the other bundled language).
    @Test func recognizesVietnameseText() async throws {
        let saved = Defaults[.ocrLanguages]
        Defaults[.ocrLanguages] = ["vi-VN"]
        defer { Defaults[.ocrLanguages] = saved }

        let image = try makeTestImage(text: "Xin chào Việt Nam")
        let provider = TesseractOCRProvider()
        let text = try await provider.recognizeText(in: image)
        #expect(text.localizedCaseInsensitiveContains("Xin"))
        #expect(text.localizedCaseInsensitiveContains("Việt"))
    }

    /// The provider supports the full 8-language OCR list.
    @Test func supportsFullLanguageList() {
        let provider = TesseractOCRProvider()
        #expect(provider.id == OcrProviderID.tesseract.rawValue)
        #expect(provider.needsNetwork == false)
        #expect(provider.needsAPIKey == false)
        #expect(Set(provider.supportedLanguages) == Set([
            "vi-VN", "en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE",
        ]))
    }
}
#endif

/// Pure-logic tests for `TesseractLanguageDataManager` (no engine, no network).
@Suite struct TesseractLanguageDataManagerTests {
    /// All 8 OCR languages map to a tessdata code that exists in tessdata_best.
    @Test func allEightLanguagesMapToTessCodes() {
        let mapping: [String: String] = [
            "vi-VN": "vie", "en-US": "eng",
            "zh-Hans": "chi_sim", "zh-Hant": "chi_tra",
            "ja-JP": "jpn", "ko-KR": "kor",
            "fr-FR": "fra", "de-DE": "deu",
        ]
        for (bcp47, tess) in mapping {
            #expect(TesseractLanguageDataManager.tessCode(forBCP47: bcp47) == tess)
        }
    }

    /// Unknown codes return nil (the caller drops them).
    @Test func unknownLanguageMapsToNil() {
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "xx-YY") == nil)
    }

    /// Download URLs point at the tessdata_best raw files.
    @Test func downloadURLPointsAtTessdataBest() {
        let url = TesseractLanguageDataManager.downloadURL(for: "vie")
        #expect(url.absoluteString == "https://github.com/tesseract-ocr/tessdata_best/raw/main/vie.traineddata")
    }

    /// The bundled eng + vie files are in the test bundle (added as a
    /// test-target resource), so the manager sees them without a download.
    @Test func bundledCodesIncludeEngAndVie() {
        let codes = TesseractLanguageDataManager.bundledCodes()
        #expect(codes.contains("eng"))
        #expect(codes.contains("vie"))
    }
}

/// Pure-logic tests for the fallback trigger in `ScreenCaptureOCR`
/// (no Vision calls, no Tesseract calls — the decision is injected).
@Suite struct ScreenCaptureOCRFallbackTests {
    /// Vision supports none of the requested languages → skip Vision.
    @Test func skipsVisionWhenItSupportsNoneRequested() {
        #expect(ScreenCaptureOCR.shouldSkipVision(
            requested: ["vi-VN"], visionSupported: ["en-US"]
        ) == true)
    }

    /// Vision supports at least one requested language → try Vision first.
    @Test func triesVisionWhenItSupportsOneRequested() {
        #expect(ScreenCaptureOCR.shouldSkipVision(
            requested: ["vi-VN", "en-US"], visionSupported: ["en-US"]
        ) == false)
    }

    /// No requested languages → nothing for Vision to cover → skip it.
    @Test func skipsVisionWhenNothingRequested() {
        #expect(ScreenCaptureOCR.shouldSkipVision(
            requested: [], visionSupported: ["en-US", "vi-VN"]
        ) == true)
    }
}
