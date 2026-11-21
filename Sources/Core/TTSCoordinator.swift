import Defaults
import Foundation
import Observation

@MainActor @Observable
final class TTSCoordinator {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing(providerID: String)
        case error(String)
    }

    private(set) var playbackState: PlaybackState = .idle
    /// The text currently being spoken, used to scope UI state per-button.
    private(set) var currentText: String?
    /// Called when a speak request ends on its own (finished or failed), but
    /// not when it is cancelled via `stop()` — the stop path already clears
    /// any UI that was waiting on playback. TransPeek Phase 1 uses this to
    /// clear the trigger icon's speaking state.
    @ObservationIgnored var onPlaybackEnded: (() -> Void)?
    private var speakTask: Task<Void, Never>?
    private var activePlaybackProvider: (any TTSProvider)?
    /// Generation counter for read-along chunk speech (Manh 2026-11-21,
    /// CI314 fix): incremented by `stop()`, so a chunk can tell whether
    /// its utterance was cut short from outside (e.g. another speech
    /// started elsewhere) instead of finishing on its own. The Fast Read
    /// read-along stops advancing when a chunk is interrupted this way.
    private var speechGeneration = 0

    private let registry: TTSProviderRegistry

    init(registry: TTSProviderRegistry) {
        self.registry = registry
    }

    func speak(_ text: String, language: String) {
        stop()
        currentText = text

        speakTask = Task { [weak self] in
            guard let self else { return }
            let provider = registry.activeProvider
            activePlaybackProvider = provider
            playbackState = .loading

            do {
                try await performSpeak(provider, text: text, language: language)
            } catch {
                guard !Task.isCancelled else { return }

                // Fallback to Apple TTS if the current provider isn't Apple
                if provider.id != AppleTTSProvider.providerID,
                   let apple = registry.provider(withID: AppleTTSProvider.providerID)
                {
                    print("[TTS] \(provider.displayName) failed: \(error.localizedDescription), falling back to Apple TTS")
                    do {
                        try await performSpeak(apple, text: text, language: language)
                    } catch {
                        if !Task.isCancelled {
                            playbackState = .error(error.localizedDescription)
                        }
                    }
                } else {
                    playbackState = .error(error.localizedDescription)
                }
            }

            if !Task.isCancelled {
                self.onPlaybackEnded?()
            }
            self.speakTask = nil
        }
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        activePlaybackProvider?.stop()
        activePlaybackProvider = nil
        currentText = nil
        playbackState = .idle
        // Any in-flight read-along speech is interrupted by this stop,
        // so its caller must not treat it as finished (see
        // speakContinuous — it returns false when the generation moved).
        speechGeneration += 1
    }

    /// Speak the whole text in ONE continuous utterance and report each
    /// word's range as it is spoken (Manh 2026-11-21, Option B — natural
    /// reading): no gap between words, so the voice never stutters, and
    /// the caller maps each range to the current slide/line, so the text
    /// follows the voice. Returns true when the utterance finished on its
    /// own, false when it was cut short by a `stop()` from elsewhere.
    /// Deliberately does NOT touch `onPlaybackEnded`, `currentText` or
    /// `playbackState` — those belong to the trigger icon's whole-text
    /// speech, and a read-along utterance must not trip its "speech
    /// ended" cleanup. The `onWordRange` callback is main-actor-isolated,
    /// so the caller may update UI state directly. If the active provider
    /// cannot track words (its default implementation), no ranges are
    /// reported and the caller advances only when the utterance finishes.
    @MainActor func speakContinuous(_ text: String, language: String, onWordRange: @escaping @MainActor (NSRange) -> Void) async -> Bool {
        let generation = speechGeneration
        let provider = registry.activeProvider
        activePlaybackProvider = provider
        do {
            try await provider.speakWithWordTracking(text, language: language, accent: Defaults[.ttsAccent], rate: effectiveRate(for: language), onWordRange: onWordRange)
        } catch {
            // Same Apple fallback as speak(): a cloud provider failing
            // must not stall the read — try Apple TTS, and if that fails
            // too the utterance is skipped (the caller still advances, so
            // one bad utterance never stalls the read).
            if provider.id != AppleTTSProvider.providerID,
               let apple = registry.provider(withID: AppleTTSProvider.providerID) {
                try? await apple.speakWithWordTracking(text, language: language, accent: Defaults[.ttsAccent], rate: effectiveRate(for: language), onWordRange: onWordRange)
            }
        }
        return generation == speechGeneration
    }

    var isPlaying: Bool {
        if case .playing = playbackState { return true }
        if case .loading = playbackState { return true }
        return false
    }

    func isPlaying(_ text: String) -> Bool {
        isPlaying && currentText == text
    }

    private func performSpeak(_ provider: any TTSProvider, text: String, language: String) async throws {
        playbackState = .playing(providerID: provider.id)
        let rate = effectiveRate(for: language)
        try await provider.speak(text, language: language, accent: Defaults[.ttsAccent], rate: rate)
        if !Task.isCancelled {
            playbackState = .idle
        }
    }

    private func effectiveRate(for language: String) -> Float {
        if let override = Defaults[.ttsLanguageRates][language] {
            return Float(override)
        }
        return Float(Defaults[.ttsSpeechRate])
    }
}
