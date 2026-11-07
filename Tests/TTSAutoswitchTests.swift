import Foundation
import Testing
@testable import TransPeek

/// M2+M3: autoswitch voice by detected language (develop, OFF by default).
@Suite struct TTSAutoswitchTests {
    @Test func disabledKeepsRequestedLanguage() {
        #expect(TTSAutoswitch.effectiveLanguage(requested: "en", detected: "vi", enabled: false) == "en")
    }

    @Test func enabledUsesDetectedLanguageWhenDifferent() {
        #expect(TTSAutoswitch.effectiveLanguage(requested: "en", detected: "vi", enabled: true) == "vi")
    }

    @Test func enabledKeepsRequestedWhenDetectionIsNil() {
        #expect(TTSAutoswitch.effectiveLanguage(requested: "vi", detected: nil, enabled: true) == "vi")
    }

    @Test func enabledKeepsRequestedWhenDetectionAgrees() {
        #expect(TTSAutoswitch.effectiveLanguage(requested: "vi", detected: "vi", enabled: true) == "vi")
    }

    @Test func fallbackChainEndsWithEnglish() {
        #expect(TTSAutoswitch.fallbackLanguages(for: "vi") == ["vi", "en"])
        #expect(TTSAutoswitch.fallbackLanguages(for: "en") == ["en"])
    }
}
