import Defaults
import Foundation
import SwiftUI

// MARK: - TTS Accent

enum TTSAccent: String, CaseIterable, Defaults.Serializable {
    case american
    case british

    var displayName: String {
        switch self {
        case .american: String(localized: "American English")
        case .british: String(localized: "British English")
        }
    }

    var shortLabel: String {
        switch self {
        case .american: "US"
        case .british: "UK"
        }
    }
}

// MARK: - TTS Provider Protocol

/// Plugin protocol for text-to-speech backends. Each provider is self-contained:
/// owns its playback logic, settings UI, and configuration storage.
protocol TTSProvider: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var iconSystemName: String { get }
    var isAvailable: Bool { get }
    @MainActor var isConfigured: Bool { get }

    /// Speak the given text. Provider manages its own playback internally
    /// (AVSpeechSynthesizer for system TTS, AVPlayer for URL-based services).
    /// This method returns when playback finishes or is cancelled.
    @MainActor func speak(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float
    ) async throws

    /// Speak the text and report each word's range as it is spoken
    /// (Manh 2026-11-21, Option B — natural reading): the range is the
    /// word about to be spoken, in the utterance string's UTF-16
    /// coordinates. The caller maps it to the current slide/line, so the
    /// text follows the voice. Still returns when the whole utterance
    /// finishes or is cancelled. The default implementation just speaks
    /// (no word tracking) — a provider that cannot track words uses it,
    /// and the caller then gets no per-word updates. The callback is
    /// main-actor-isolated, so the caller may update UI state directly.
    @MainActor func speakWithWordTracking(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float,
        onWordRange: @escaping @MainActor (NSRange) -> Void
    ) async throws

    /// Stop any in-progress playback immediately.
    @MainActor func stop()

    /// Return a settings view for this provider.
    @MainActor func makeSettingsView() -> AnyView
}

// MARK: - TTS Provider Defaults

extension TTSProvider {
    /// Default word tracking: no per-word updates, just speak the text.
    /// A provider that can track words (Apple TTS) overrides this.
    @MainActor func speakWithWordTracking(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float,
        onWordRange: @escaping @MainActor (NSRange) -> Void
    ) async throws {
        // No word tracking — the callback is never invoked, and the
        // caller advances only when the whole utterance finishes.
        _ = onWordRange
        try await speak(text, language: language, accent: accent, rate: rate)
    }
}

// MARK: - TTS Errors

enum TTSError: LocalizedError {
    case unsupportedLanguage(String)
    case networkError(String)
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedLanguage(lang):
            return String(localized: "Language not supported for TTS: \(lang)")
        case let .networkError(message):
            return String(localized: "TTS network error: \(message)")
        case let .playbackFailed(message):
            return String(localized: "TTS playback failed: \(message)")
        }
    }
}

// MARK: - Environment Key

private struct TTSCoordinatorKey: EnvironmentKey {
    static let defaultValue: TTSCoordinator? = nil
}

extension EnvironmentValues {
    var ttsCoordinator: TTSCoordinator? {
        get { self[TTSCoordinatorKey.self] }
        set { self[TTSCoordinatorKey.self] = newValue }
    }
}
