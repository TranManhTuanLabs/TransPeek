import AVFoundation
import Defaults
import SwiftUI

final class AppleTTSProvider: TTSProvider, @unchecked Sendable {
    static let providerID = "apple"

    let id = providerID
    let displayName = "Apple TTS"
    let iconSystemName = "apple.logo"
    let isAvailable = true
    @MainActor var isConfigured: Bool { true }

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

    /// Speak the text and report each word's range as it is spoken
    /// (Manh 2026-11-21, Option B — natural reading): one continuous
    /// utterance, so there is no gap between words, and the delegate's
    /// `willSpeakRangeOfSpeechString` fires for each word about to be
    /// spoken. The range is in the utterance string's UTF-16 coordinates.
    /// The callback is main-actor-isolated, so the caller may update UI
    /// state directly. Still returns when the whole utterance finishes
    /// or is cancelled.
    @MainActor func speakWithWordTracking(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float,
        onWordRange: @escaping @MainActor (NSRange) -> Void
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
            let delegate = SpeechDelegate(continuation: continuation, onWordRange: onWordRange)
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

    /// User-chosen voice for English/Vietnamese (TransPeek Phase 1).
    /// Returns nil when no voice is stored for the language, or when the
    /// stored identifier no longer matches an installed voice — callers then
    /// fall back to the existing best-voice selection.
    private func preferredVoice(for voiceLang: String) -> AVSpeechSynthesisVoice? {
        let storedID: String
        switch voiceLang.lowercased().prefix(2) {
        case "en": storedID = Defaults[.ttsVoiceEN]
        case "vi": storedID = Defaults[.ttsVoiceVI]
        default: return nil
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
    /// Called for each word about to be spoken, with its range in the
    /// utterance string. Nil for plain `speak` (no word tracking).
    /// Main-actor-isolated, so the caller may update UI state. The
    /// delegate itself is not main-actor-isolated, so the call hops to
    /// the main actor via a Task.
    private let onWordRange: (@MainActor (NSRange) -> Void)?

    init(continuation: CheckedContinuation<Void, Never>, onWordRange: (@MainActor (NSRange) -> Void)? = nil) {
        self.continuation = continuation
        self.onWordRange = onWordRange
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        resumeOnce()
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        resumeOnce()
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance _: AVSpeechUtterance) {
        guard let onWordRange else { return }
        // Hop to the main actor — the caller updates UI state here.
        // One small Task per word; the main actor runs them in order,
        // so the focus advances word by word as the voice speaks.
        Task { @MainActor in
            onWordRange(characterRange)
        }
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
