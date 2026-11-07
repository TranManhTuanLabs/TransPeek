import Foundation
import Testing
@testable import MoePeek

/// M2+M3: OCR provider selection + Tesseract language mapping.
/// No engine calls: availability is injected via the `tesseractAvailable`
/// parameter, and the CLI is only exercised live on a Mac.
@Suite struct OcrProviderRegistryTests {
    @Test func visionIsDefaultForAnythingElse() {
        #expect(OcrProviderRegistry.resolve(selectedID: "vision", tesseractAvailable: true) == .vision)
        #expect(OcrProviderRegistry.resolve(selectedID: "", tesseractAvailable: true) == .vision)
        #expect(OcrProviderRegistry.resolve(selectedID: "no-such-engine", tesseractAvailable: true) == .vision)
    }

    @Test func tesseractNeedsSelectionAndAvailability() {
        #expect(OcrProviderRegistry.resolve(selectedID: "tesseract", tesseractAvailable: true) == .tesseract)
        #expect(OcrProviderRegistry.resolve(selectedID: "tesseract", tesseractAvailable: false) == .vision)
    }

    @Test func bcp47MapsToTessCodes() {
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "vi-VN") == "vie")
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "en-US") == "eng")
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "zh-Hans") == "chi_sim")
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "zh-Hant") == "chi_tra")
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "ja-JP") == "jpn")
        #expect(TesseractLanguageDataManager.tessCode(forBCP47: "xx-YY") == nil)
    }

    @Test func tessCodesMapBackToBcp47() {
        #expect(TesseractLanguageDataManager.bcp47(forTessCode: "vie") == "vi-VN")
        #expect(TesseractLanguageDataManager.bcp47(forTessCode: "eng") == "en-US")
        #expect(TesseractLanguageDataManager.bcp47(forTessCode: "chi_sim") == "zh-Hans")
    }

    @Test func downloadURLsPointAtTessdataBest() {
        #expect(TesseractLanguageDataManager.downloadURL(for: "vie").absoluteString
            == "https://github.com/tesseract-ocr/tessdata_best/raw/main/vie.traineddata")
        #expect(TesseractLanguageDataManager.downloadURL(for: "eng").absoluteString
            == "https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata")
    }

    @Test func effectiveLanguagesKeepsOrderAndDedupes() {
        let result = TesseractOCRProvider.effectiveLanguages(
            requested: ["vi-VN", "en-US", "vi-VN", "ja-JP"],
            installed: ["vie", "eng"]
        )
        #expect(result == ["vie", "eng"])
    }

    @Test func effectiveLanguagesDropsUninstalled() {
        let result = TesseractOCRProvider.effectiveLanguages(
            requested: ["vi-VN", "ja-JP"],
            installed: ["eng"]
        )
        #expect(result == ["eng"])
    }

    @Test func effectiveLanguagesFallsBackToEnglishWhenNothingInstalled() {
        let result = TesseractOCRProvider.effectiveLanguages(
            requested: ["vi-VN"],
            installed: []
        )
        #expect(result == ["eng"])
    }
}
