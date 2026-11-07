import AVFoundation
import Defaults
import SwiftUI

final class AppleTTSProvider: TTSProvider, @unchecked Sendable {
    static let providerID = "apple"

    let id = providerID
    /// The System provider (SPEC §4.3): offline, free, the default and the
    /// last-resort fallback in the TTS chain. Never remove it from the registry.
    let displayName = "System (Apple TTS)"
    let iconSystemName = "apple.logo"
    let isAvailable = true
    @MainActor var isConfigured: Bool { true }

    var needsNetwork: Bool { false }
    var needsAPIKey: Bool { false }
    var quality: TTSQuality { .standard }

    /// 2-letter prefixes of the voices installed on this Mac (e.g. "en", "vi").
    var supportedLanguages: [String] {
        Array(Set(
            AVSpeechSynthesisVoice.speechVoices().map { String($0.language.prefix(2)).lowercased() }
        )).sorted()
    }

    private let synthesizer = AVSpeechSynthesizer()
    private lazy var cachedVoices = AVSpeechSynthesisVoice.speechVoices()

    @MainActor func speak(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float
    ) async throws {
        let voiceLang = resolveVoiceLanguage(language: language, accent: accent)
        let utterance = AVSpeechUtterance(string: text)

        if let voice = preferredVoice(for: voiceLang) {
            utterance.voice = voice
        } else if let voice = bestVoice(for: voiceLang) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: voiceLang) {
            utterance.voice = voice
        }

        // Map rate 0.5–2.0 to AVSpeechUtterance rate range.
        // AVSpeechUtteranceDefaultSpeechRate is 0.5, min is 0.0, max is 1.0.
        let normalizedRate = AVSpeechUtteranceDefaultSpeechRate * rate
        utterance.rate = min(max(normalizedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = SpeechDelegate(continuation: continuation)
            // Retain delegate until speech finishes
            objc_setAssociatedObject(self.synthesizer, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN)
            self.synthesizer.delegate = delegate
            self.synthesizer.speak(utterance)
        }
    }

    @MainActor func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    @MainActor func makeSettingsView() -> AnyView {
        AnyView(
            Label(
                String(localized: "System built-in, no configuration needed."),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        )
    }

    // MARK: - Voice Selection

    private func resolveVoiceLanguage(language: String, accent: TTSAccent) -> String {
        if language == "en" {
            return accent == .british ? "en-GB" : "en-US"
        }
        let mapping: [String: String] = [
            "zh-Hans": "zh-CN",
            "zh-Hant": "zh-TW",
        ]
        return mapping[language] ?? language
    }

    /// User-chosen voice for a language (TransPeek Phase 1 EN/VI, M2+M3 any
    /// other installed language via `Defaults[.ttsVoiceByLanguage]`).
    /// Returns nil when no voice is stored for the language, or when the
    /// stored identifier no longer matches an installed voice — callers then
    /// fall back to the existing best-voice selection.
    private func preferredVoice(for voiceLang: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(voiceLang.lowercased().prefix(2))
        let storedID: String
        switch prefix {
        case "en": storedID = Defaults[.ttsVoiceEN]
        case "vi": storedID = Defaults[.ttsVoiceVI]
        default: storedID = Defaults[.ttsVoiceByLanguage][prefix] ?? ""
        }
        guard !storedID.isEmpty else { return nil }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == storedID }
    }

    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let langPrefix = language.lowercased().prefix(2)
        let voices = cachedVoices
            .filter { $0.language.lowercased().hasPrefix(String(langPrefix)) }
            .sorted { voiceQuality($0) > voiceQuality($1) }

        if let exact = voices.first(where: { $0.language.lowercased() == language.lowercased() }) {
            return exact
        }
        return voices.first
    }

    private func voiceQuality(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }
}

// MARK: - Speech Delegate

private enum AssociatedKeys {
    static var delegate: UInt8 = 0
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    private let continuation: CheckedContinuation<Void, Never>
    private let resumed = LockedAtomic(false)

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        resumeOnce()
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        resumeOnce()
    }

    private func resumeOnce() {
        if resumed.exchange(true) == false {
            continuation.resume()
        }
    }
}

private final class LockedAtomic<T: Equatable>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func exchange(_ newValue: T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let old = value
        value = newValue
        return old
    }
}
