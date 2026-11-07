import Foundation
import Testing
@testable import MoePeek

/// M2+M3: `TTSFallbackChain.steps` ordering — chosen engine first, then
/// EdgeTTS, then System, then dictionary audio; never duplicated, never
/// includes a provider that isn't registered.
@Suite struct TTSFallbackChainTests {
    @Test func chosenEdgeThenSystemThenDictionary() {
        let steps = TTSFallbackChain.steps(chosenID: "edge", availableIDs: ["apple", "edge"])
        #expect(steps == [.provider("edge"), .provider("apple"), .dictionaryAudio])
    }

    @Test func chosenSystemStillTriesEdgeNext() {
        let steps = TTSFallbackChain.steps(chosenID: "apple", availableIDs: ["apple", "edge"])
        #expect(steps == [.provider("apple"), .provider("edge"), .dictionaryAudio])
    }

    @Test func unknownChosenProviderFallsBackToEdgeThenSystem() {
        let steps = TTSFallbackChain.steps(chosenID: "elevenlabs", availableIDs: ["apple", "edge"])
        #expect(steps == [.provider("edge"), .provider("apple"), .dictionaryAudio])
    }

    @Test func missingEdgeIsSkippedNotDuplicated() {
        // Registry with only System (e.g. a minimal build): no Edge step.
        let steps = TTSFallbackChain.steps(chosenID: "apple", availableIDs: ["apple"])
        #expect(steps == [.provider("apple"), .dictionaryAudio])
    }

    @Test func dictionaryAudioIsAlwaysLast() {
        let steps = TTSFallbackChain.steps(chosenID: "edge", availableIDs: ["apple", "edge"])
        #expect(steps.last == .dictionaryAudio)
    }
}
