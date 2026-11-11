import Defaults
import Foundation

/// A dictionary lookup link shown at the bottom of the float panel (SPEC §3.2).
///
/// The `urlTemplate` contains either `{word}` (first word of the selected text,
/// for word dictionaries such as Oxford / Cambridge / YouGlish) or `{text}`
/// (the whole selected text, for search-style lookups such as Google).
/// Links are persisted as JSON in `Defaults[.dictionaryLinksJSON]`; an empty or
/// unreadable stored value means "use the built-in defaults".
struct DictionaryLink: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var urlTemplate: String
    /// Optional SF Symbol shown when no favicon has been fetched yet.
    /// `nil` (the case for the built-in links) falls back to the first letter
    /// of the name in a rounded tile — see `DictionaryBarView`.
    var iconSystemName: String? = nil

    // MARK: - Built-in defaults

    static let defaults: [DictionaryLink] = [
        DictionaryLink(
            name: "Oxford",
            urlTemplate: "https://www.oxfordlearnersdictionaries.com/definition/english/{word}?q={word}"
        ),
        DictionaryLink(
            name: "Cambridge",
            urlTemplate: "https://dictionary.cambridge.org/dictionary/english/{word}"
        ),
        DictionaryLink(
            name: "Google",
            urlTemplate: "https://www.google.com/search?q=define+{text}"
        ),
        DictionaryLink(
            name: "YouGlish",
            urlTemplate: "https://youglish.com/pronounce/{text}/english"
        ),
        DictionaryLink(
            name: "Cambridge Vi",
            urlTemplate: "https://dictionary.cambridge.org/dictionary/english-vietnamese/{word}"
        ),
    ]

    // MARK: - Persistence

    /// Loads the user's links. Empty / missing / undecodable stored JSON
    /// returns the built-in defaults. An explicitly stored empty array (`[]`)
    /// is honoured as "no links" — it only arises when the user deletes every
    /// link in Settings.
    static func load() -> [DictionaryLink] {
        let raw = Defaults[.dictionaryLinksJSON]
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return defaults }
        guard let decoded = try? JSONDecoder().decode([DictionaryLink].self, from: data) else {
            return defaults
        }
        return decoded
    }

    /// Persists links as JSON. Encoding a plain struct array cannot fail in
    /// practice; a failure leaves the previous stored value untouched.
    static func save(_ links: [DictionaryLink]) {
        guard let data = try? JSONEncoder().encode(links),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        Defaults[.dictionaryLinksJSON] = raw
    }

    // MARK: - URL building

    /// Host of the link's site, used as the favicon cache key.
    /// Derived by substituting a dummy word so the template parses as a URL.
    var host: String? {
        url(for: "test")?.host?.lowercased()
    }

    /// Builds the URL to open for `text`, or `nil` when the template has
    /// neither placeholder, the text is empty, or substitution does not yield
    /// a valid http(s) URL.
    func url(for text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasWord = urlTemplate.contains("{word}")
        let hasText = urlTemplate.contains("{text}")
        guard hasWord || hasText else { return nil }

        var substituted = urlTemplate
        if hasWord {
            // Dictionary headwords are lowercase and the word-dictionary
            // sites match the path case-sensitively: "Word" must open
            // .../word, not .../Word ("Word not found in the dictionary").
            guard let firstWord = trimmed.split(whereSeparator: \.isWhitespace).first,
                  let encoded = Self.percentEncode(String(firstWord).lowercased())
            else { return nil }
            substituted = substituted.replacingOccurrences(of: "{word}", with: encoded)
        }
        if hasText {
            guard let encoded = Self.percentEncode(trimmed) else { return nil }
            substituted = substituted.replacingOccurrences(of: "{text}", with: encoded)
        }

        guard let url = URL(string: substituted),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// Validates a user-entered link (Settings add/edit). Returns a localized
    /// error message, or `nil` when the link is usable. The template is
    /// checked by substituting a sample two-word text, so both placeholders
    /// and URL validity are exercised.
    static func validationError(name: String, urlTemplate: String) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter a name for the link.")
        }
        let template = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !template.contains("{word}") && !template.contains("{text}") {
            return String(localized: "The URL template must contain {word} or {text}.")
        }
        let probe = DictionaryLink(name: name, urlTemplate: template)
        if probe.url(for: "hello world") == nil {
            return String(localized: "The URL template is not a valid web address.")
        }
        return nil
    }

    // MARK: - Private

    /// Percent-encodes a substituted value.
    ///
    /// Deliberately stricter than `.urlQueryAllowed`: that set leaves `&`,
    /// `+` and `=` unescaped, which would corrupt query templates such as
    /// Google's `define+{text}` when the text contains those characters.
    /// Only RFC 3986 unreserved characters pass through; everything else
    /// (including spaces) is `%XX`-encoded, which is valid in both path
    /// segments and query values.
    private static func percentEncode(_ value: String) -> String? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
