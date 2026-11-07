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

    private let registry: TTSProviderRegistry

    init(registry: TTSProviderRegistry) {
        self.registry = registry
    }

    /// Speak `text`, walking the fallback chain (SPEC §4.3, M2+M3):
    /// chosen engine -> EdgeTTS (if online) -> System -> dictionary audio
    /// (single word only) -> clear error. Never fails silently: when every
    /// step fails, `playbackState` carries the last error's message.
    ///
    /// When autoswitch is enabled (develop, OFF by default), the language
    /// actually spoken is the detected language, not the requested one.
    func speak(_ text: String, language: String) {
        stop()
        currentText = text

        speakTask = Task { [weak self] in
            guard let self else { return }
            let detected = Defaults[.ttsAutoswitchEnabled] ? LanguageDetector.detect(text) : nil
            let effectiveLanguage = TTSAutoswitch.effectiveLanguage(
                requested: language,
                detected: detected,
                enabled: Defaults[.ttsAutoswitchEnabled]
            )
            let steps = TTSFallbackChain.steps(
                chosenID: registry.activeProvider.id,
                availableIDs: registry.providers.map(\.id)
            )
            playbackState = .loading

            var lastError: Error?
            for step in steps {
                guard !Task.isCancelled else { return }
                do {
                    switch step {
                    case let .provider(id):
                        guard let provider = registry.provider(withID: id) else { continue }
                        activePlaybackProvider = provider
                        try await performSpeak(provider, text: text, language: effectiveLanguage)
                    case .dictionaryAudio:
                        guard DictionaryAudioService.isSingleWord(text) else { continue }
                        activePlaybackProvider = nil
                        playbackState = .playing(providerID: "dictionary")
                        try await DictionaryAudioService.speak(
                            word: text,
                            rate: effectiveRate(for: effectiveLanguage)
                        )
                        playbackState = .idle
                    }
                    // A step succeeded: done, no further fallback.
                    if !Task.isCancelled {
                        self.onPlaybackEnded?()
                    }
                    self.speakTask = nil
                    return
                } catch {
                    // User pressed stop: do not fall through to the next engine.
                    if Task.isCancelled { return }
                    lastError = error
                    print("[TTS] step \(step) failed: \(error.localizedDescription), trying next fallback")
                }
            }

            if !Task.isCancelled {
                playbackState = .error(
                    lastError?.localizedDescription
                        ?? String(localized: "Text-to-speech failed")
                )
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
        DictionaryAudioService.stop()
        currentText = nil
        playbackState = .idle
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
