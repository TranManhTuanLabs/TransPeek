import Foundation

/// Dictionary pronunciation audio (SPEC §4.3): the last step of the TTS
/// fallback chain, single word only.
///
/// Source: the free, key-free dictionaryapi.dev (`api.dictionaryapi.dev`,
/// data largely from Google's pronunciation clips). No scraping of
/// Oxford/Cambridge pages — their audio URLs are page-embedded and break
/// often. English only in practice: the API has no Vietnamese audio, so a
/// Vietnamese single word 404s here and the chain ends with a clear error.
enum DictionaryAudioService {
    static let endpointBase = "https://api.dictionaryapi.dev/api/v2/entries/en/"

    /// True only for one bare word (letters, hyphen, apostrophe). Phrases,
    /// numbers and punctuation are not dictionary lookups.
    static func isSingleWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
        return trimmed.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" }
    }

    private struct DictionaryEntry: Decodable {
        let phonetics: [Phonetic]?
        struct Phonetic: Decodable {
            let audio: String?
        }
    }

    /// First non-empty pronunciation audio URL in a dictionaryapi.dev response.
    /// Pure parsing, covered by Swift Testing.
    static func audioURL(from data: Data) -> URL? {
        guard let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
            return nil
        }
        for entry in entries {
            for phonetic in entry.phonetics ?? [] {
                if let audio = phonetic.audio, !audio.isEmpty, let url = URL(string: audio) {
                    return url
                }
            }
        }
        return nil
    }

    /// Resolve the pronunciation clip URL for a word. Throws `TTSError` so
    /// the coordinator can surface the reason instead of failing silently.
    static func fetchAudioURL(for word: String) async throws -> URL {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: endpointBase + encoded)
        else { throw TTSError.unsupportedLanguage(word) }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw TTSError.networkError(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TTSError.networkError(
                String(localized: "No dictionary audio for \"\(word)\"")
            )
        }
        guard let audio = audioURL(from: data) else {
            throw TTSError.playbackFailed(
                String(localized: "No pronunciation audio for \"\(word)\"")
            )
        }
        return audio
    }

    /// Download the clip and play it to completion. Callers must ensure
    /// `isSingleWord(word)` first; this method re-checks and throws otherwise.
    @MainActor static func speak(word: String, rate: Float) async throws {
        guard isSingleWord(word) else {
            throw TTSError.unsupportedLanguage(word)
        }
        let audioURL = try await fetchAudioURL(for: word)
        let (data, _) = try await URLSession.shared.data(from: audioURL)
        guard !data.isEmpty else {
            throw TTSError.playbackFailed(String(localized: "Dictionary audio clip was empty"))
        }
        try await AudioPlayback.play(data: data, rate: rate)
    }

    @MainActor static func stop() {
        AudioPlayback.stop()
    }
}
