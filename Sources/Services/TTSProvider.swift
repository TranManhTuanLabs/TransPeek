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

// MARK: - TTS Quality

/// Rough voice quality tier, shown in Settings so the user can tell the
/// free offline System voices apart from neural cloud voices (SPEC §4.3).
enum TTSQuality: String, Sendable {
    case standard
    case neural
    case premium

    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .neural: String(localized: "Neural")
        case .premium: String(localized: "Premium")
        }
    }
}

// MARK: - TTS Provider Protocol

/// Plugin protocol for text-to-speech backends. Each provider is self-contained:
/// owns its playback logic, settings UI, and configuration storage.
///
/// Metadata (SPEC §4.3) mirrors `TranslationProvider` / `OcrProvider`:
/// `id`, `displayName`, `needsNetwork` / `needsAPIKey`, `supportedLanguages`,
/// `quality`, `status`. Defaults describe an offline system voice so existing
/// providers only override what differs.
protocol TTSProvider: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var iconSystemName: String { get }
    var isAvailable: Bool { get }
    @MainActor var isConfigured: Bool { get }

    /// Whether speaking needs network access (Edge TTS: yes, System: no).
    var needsNetwork: Bool { get }
    /// Whether speaking needs a user-supplied API key (none of the M2 providers do).
    var needsAPIKey: Bool { get }
    /// Language codes the provider can speak (2-letter prefixes, e.g. "en", "vi").
    /// Empty means "unknown / unrestricted" — the provider decides at speak time.
    var supportedLanguages: [String] { get }
    /// Voice quality tier, for display only.
    var quality: TTSQuality { get }
    /// Short user-visible status, e.g. "Ready".
    var status: String { get }

    /// Speak the given text. Provider manages its own playback internally
    /// (AVSpeechSynthesizer for system TTS, AVPlayer for URL-based services).
    /// This method returns when playback finishes or is cancelled.
    @MainActor func speak(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float
    ) async throws

    /// Stop any in-progress playback immediately.
    @MainActor func stop()

    /// Return a settings view for this provider.
    @MainActor func makeSettingsView() -> AnyView
}

extension TTSProvider {
    var needsNetwork: Bool { false }
    var needsAPIKey: Bool { false }
    var supportedLanguages: [String] { [] }
    var quality: TTSQuality { .standard }
    var status: String {
        isAvailable ? String(localized: "Ready") : String(localized: "Unavailable")
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
