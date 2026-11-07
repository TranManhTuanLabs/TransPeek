import Foundation
import Testing
@testable import TransPeek

/// Pure-logic tests for `VisionOCRProvider.effectiveLanguages`.
/// No Vision calls, no screenshots: the runtime language check is injected
/// via the `supported` parameter.
@Suite struct VisionOCRProviderTests {
    @Test func vietnameseSupportedKeepsVietnameseAndEnablesCorrection() {
        let result = VisionOCRProvider.effectiveLanguages(
            requested: ["vi-VN", "en-US"],
            supported: ["vi-VN", "en-US", "zh-Hans"]
        )
        #expect(result.languages == ["vi-VN", "en-US"])
        #expect(result.useCorrection == true)
    }

    @Test func vietnameseUnsupportedDropsVietnameseAndDisablesCorrection() {
        // Without Vietnamese support, English correction would "fix" Vietnamese
        // words into English ones, so correction must be off.
        let result = VisionOCRProvider.effectiveLanguages(
            requested: ["vi-VN", "en-US"],
            supported: ["en-US"]
        )
        #expect(result.languages == ["en-US"])
        #expect(result.useCorrection == false)
    }

    @Test func emptyRequestFallsBackToEnglish() {
        let result = VisionOCRProvider.effectiveLanguages(
            requested: [],
            supported: ["vi-VN", "en-US"]
        )
        #expect(result.languages == ["en-US"])
        #expect(result.useCorrection == false)
    }

    @Test func unsupportedLanguagesAreDroppedPreservingOrder() {
        let result = VisionOCRProvider.effectiveLanguages(
            requested: ["vi-VN", "ja-JP", "en-US"],
            supported: ["en-US", "ja-JP"]
        )
        #expect(result.languages == ["ja-JP", "en-US"])
        #expect(result.useCorrection == false)
    }

    @Test func nothingSupportedFallsBackToEnglish() {
        let result = VisionOCRProvider.effectiveLanguages(
            requested: ["vi-VN"],
            supported: []
        )
        #expect(result.languages == ["en-US"])
        #expect(result.useCorrection == false)
    }
}
