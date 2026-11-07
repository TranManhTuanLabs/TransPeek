import Foundation

/// Autoswitch voice by detected language (SPEC §4.2).
///
/// Develop feature, OFF by default (`Defaults[.ttsAutoswitchEnabled]`):
/// `LanguageDetector` mis-detects short text, and a confidently wrong voice
/// is worse than the voice for the language the user asked for. When it is
/// on, the detected language wins for *voice selection only* — the text
/// itself is unchanged. Pure logic, covered by Swift Testing.
enum TTSAutoswitch {
    /// Effective language to hand to the TTS provider.
    /// - Parameters:
    ///   - requested: language the caller asked for (e.g. source/target language).
    ///   - detected: language `LanguageDetector` guessed for the text, if any.
    ///   - enabled: whether the develop toggle is on.
    /// - Returns: `detected` when enabled and detection produced a different
    ///   language, otherwise `requested`.
    static func effectiveLanguage(requested: String, detected: String?, enabled: Bool) -> String {
        guard enabled,
              let detected, !detected.isEmpty,
              detected != requested
        else { return requested }
        return detected
    }

    /// Voice fallback chain for a language: the language itself, then
    /// English as the last resort (SPEC §4.2: engine voice for the language
    /// -> System voice for the language -> EN voice).
    static func fallbackLanguages(for language: String) -> [String] {
        var chain = [language]
        if language != "en" { chain.append("en") }
        return chain
    }
}
