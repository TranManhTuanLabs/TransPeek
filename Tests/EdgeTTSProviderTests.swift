import Foundation
import Testing
@testable import MoePeek

/// M2+M3: Edge TTS voice resolution, SSML building, and audio-frame parsing.
/// No network: the WebSocket itself is only exercised live on a Mac.
@Suite struct EdgeTTSProviderTests {
    @Test func englishDefaultIsAria() {
        let voice = EdgeTTSVoiceResolver.voice(for: "en", accent: .american, overrides: [:])
        #expect(voice == EdgeVoiceSelection(name: "en-US-AriaNeural", locale: "en-US"))
    }

    @Test func vietnameseDefaultIsHoaiMy() {
        let voice = EdgeTTSVoiceResolver.voice(for: "vi", accent: .american, overrides: [:])
        #expect(voice == EdgeVoiceSelection(name: "vi-VN-HoaiMyNeural", locale: "vi-VN"))
    }

    @Test func britishAccentPicksSonia() {
        let voice = EdgeTTSVoiceResolver.voice(for: "en", accent: .british, overrides: [:])
        #expect(voice == EdgeVoiceSelection(name: "en-GB-SoniaNeural", locale: "en-GB"))
    }

    @Test func userOverrideWinsOverAccentAndDefault() {
        let voice = EdgeTTSVoiceResolver.voice(
            for: "en", accent: .british, overrides: ["en": "en-US-GuyNeural"]
        )
        #expect(voice == EdgeVoiceSelection(name: "en-US-GuyNeural", locale: "en-US"))
    }

    @Test func unknownOverrideFallsBackToDefault() {
        // A stored voice name that is no longer in the catalog is ignored,
        // not spoken as a literal that Edge would reject.
        let voice = EdgeTTSVoiceResolver.voice(
            for: "vi", accent: .american, overrides: ["vi": "vi-VN-NoSuchVoiceNeural"]
        )
        #expect(voice == EdgeVoiceSelection(name: "vi-VN-HoaiMyNeural", locale: "vi-VN"))
    }

    @Test func unknownLanguageFallsBackToEnglish() {
        let voice = EdgeTTSVoiceResolver.voice(for: "xx", accent: .american, overrides: [:])
        #expect(voice.name == "en-US-AriaNeural")
    }

    @Test func bcp47CodesResolveByPrefix() {
        #expect(EdgeTTSVoiceResolver.voice(for: "vi-VN", accent: .american, overrides: [:]).name == "vi-VN-HoaiMyNeural")
        #expect(EdgeTTSVoiceResolver.voice(for: "en-US", accent: .american, overrides: [:]).name == "en-US-AriaNeural")
        #expect(EdgeTTSVoiceResolver.voice(for: "zh-Hans", accent: .american, overrides: [:]).name == "zh-CN-XiaoxiaoNeural")
    }

    @Test func ssmlEscapesUserTextAndCarriesRate() {
        let voice = EdgeVoiceSelection(name: "en-US-AriaNeural", locale: "en-US")
        let ssml = EdgeTTSVoiceResolver.ssml(text: "Fish & Chips <b>\"quoted\"</b>", voice: voice, rate: 1.25)
        #expect(ssml.contains("Fish &amp; Chips &lt;b&gt;&quot;quoted&quot;&lt;/b&gt;"))
        #expect(ssml.contains("rate=\"+25%\""))
        #expect(ssml.contains("name=\"en-US-AriaNeural\""))
        #expect(ssml.contains("xml:lang=\"en-US\""))
    }

    @Test func ssmlRateFormatsNegativeAndZero() {
        let voice = EdgeVoiceSelection(name: "vi-VN-HoaiMyNeural", locale: "vi-VN")
        #expect(EdgeTTSVoiceResolver.ssml(text: "x", voice: voice, rate: 1.0).contains("rate=\"+0%\""))
        #expect(EdgeTTSVoiceResolver.ssml(text: "x", voice: voice, rate: 0.5).contains("rate=\"-50%\""))
    }

    @Test func audioChunkExtractsMp3Bytes() {
        var frame = Data("Path:audio\r\nX-RequestId:abc\r\nContent-Type: audio/mpeg\r\n\r\n".utf8)
        frame.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])
        let chunk = EdgeTTSProvider.audioChunk(from: frame)
        #expect(chunk == Data([0xFF, 0xFB, 0x90, 0x00]))
    }

    @Test func audioChunkRejectsNonAudioFrames() {
        let frame = Data("Path:turn.end\r\nX-RequestId:abc\r\n\r\n".utf8)
        #expect(EdgeTTSProvider.audioChunk(from: frame) == nil)
        #expect(EdgeTTSProvider.audioChunk(from: Data("not a frame".utf8)) == nil)
    }

    @Test func catalogCoversBothV1Languages() {
        let locales = Set(EdgeTTSVoiceResolver.catalog.map(\.locale))
        #expect(locales.contains("vi-VN"))
        #expect(locales.contains("en-US"))
        #expect(EdgeTTSVoiceResolver.catalog.contains { $0.name == "vi-VN-NamMinhNeural" })
    }
}
