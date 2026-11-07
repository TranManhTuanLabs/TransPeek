import Foundation
import Testing
@testable import TransPeek

/// M2+M3: dictionary-audio fallback — single-word gate and audio-URL parsing.
/// No network: `fetchAudioURL` is only exercised live on a Mac.
@Suite struct DictionaryAudioTests {
    @Test func singleWordsPass() {
        #expect(DictionaryAudioService.isSingleWord("hello") == true)
        #expect(DictionaryAudioService.isSingleWord("l'amour") == true)
        #expect(DictionaryAudioService.isSingleWord("well-known") == true)
    }

    @Test func phrasesNumbersAndEmptyFail() {
        #expect(DictionaryAudioService.isSingleWord("hello world") == false)
        #expect(DictionaryAudioService.isSingleWord("hello, world") == false)
        #expect(DictionaryAudioService.isSingleWord("") == false)
        #expect(DictionaryAudioService.isSingleWord("   ") == false)
        #expect(DictionaryAudioService.isSingleWord("abc123") == false)
        #expect(DictionaryAudioService.isSingleWord("hello!") == false)
    }

    @Test func trimsSurroundingWhitespace() {
        // Leading/trailing space is fine — the word itself is still single.
        #expect(DictionaryAudioService.isSingleWord("  hello  ") == true)
    }

    @Test func picksFirstNonEmptyAudioURL() {
        let json = """
            [{"word":"hello","phonetics":[
              {"text":"/həˈloʊ/","audio":""},
              {"text":"/həˈloʊ/","audio":"https://example.com/hello.mp3"},
              {"text":"/həˈloʊ/","audio":"https://example.com/other.mp3"}
            ]}]
            """.data(using: .utf8)!
        #expect(DictionaryAudioService.audioURL(from: json)?.absoluteString == "https://example.com/hello.mp3")
    }

    @Test func returnsNilWhenNoAudio() {
        let json = """
            [{"word":"hello","phonetics":[{"text":"/həˈloʊ/","audio":""}]}]
            """.data(using: .utf8)!
        #expect(DictionaryAudioService.audioURL(from: json) == nil)
        #expect(DictionaryAudioService.audioURL(from: Data("not json".utf8)) == nil)
        #expect(DictionaryAudioService.audioURL(from: Data("[]".utf8)) == nil)
    }
}
