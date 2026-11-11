import Foundation
import Testing
@testable import TransPeek

/// URL building and JSON persistence for `DictionaryLink` (SPEC §3.2).
/// Pure logic only — no `Defaults` writes, so these tests are hermetic.
@Suite
struct DictionaryLinkTests {
    @Test func wordPlaceholderUsesFirstWordOnly() {
        let link = DictionaryLink(
            name: "Oxford",
            urlTemplate: "https://www.oxfordlearnersdictionaries.com/definition/english/{word}"
        )
        #expect(link.url(for: "hello world")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/hello")
        #expect(link.url(for: "  spaced   out words  ")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/spaced")
        #expect(link.url(for: "café")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/caf%C3%A9")
        // Word-dictionary sites match the path case-sensitively, so the
        // word is lowercased: "Word" must open .../word, not .../Word.
        #expect(link.url(for: "Word")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/word")
        #expect(link.url(for: "HELLO WORLD")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/hello")
    }

    @Test func textPlaceholderUsesWholeTextEncoded() {
        let link = DictionaryLink(
            name: "Google",
            urlTemplate: "https://www.google.com/search?q=define+{text}"
        )
        #expect(link.url(for: "hello world")?.absoluteString
            == "https://www.google.com/search?q=define+hello%20world")
        // "&" must be encoded, or it would split the query string.
        #expect(link.url(for: "fish & chips")?.absoluteString
            == "https://www.google.com/search?q=define+fish%20%26%20chips")
    }

    @Test func templateWithoutPlaceholderReturnsNil() {
        let link = DictionaryLink(name: "No placeholder", urlTemplate: "https://example.com/definition")
        #expect(link.url(for: "hello") == nil)
    }

    @Test func invalidTemplateReturnsNil() {
        let noScheme = DictionaryLink(name: "Bad", urlTemplate: "not a url {word}")
        #expect(noScheme.url(for: "hello") == nil)

        let nonHTTP = DictionaryLink(name: "FTP", urlTemplate: "ftp://example.com/{word}")
        #expect(nonHTTP.url(for: "hello") == nil)

        let emptyText = DictionaryLink(name: "Oxford", urlTemplate: "https://example.com/{word}")
        #expect(emptyText.url(for: "") == nil)
        #expect(emptyText.url(for: "   ") == nil)
    }

    @Test func defaultsRoundTripThroughJSON() throws {
        let encoded = try JSONEncoder().encode(DictionaryLink.defaults)
        let decoded = try JSONDecoder().decode([DictionaryLink].self, from: encoded)
        #expect(decoded == DictionaryLink.defaults)
        #expect(decoded.count == 5)
        #expect(decoded.map(\.name) == ["Oxford", "Cambridge", "Google", "YouGlish", "Cambridge Vi"])
        #expect(decoded[0].url(for: "hello world")?.absoluteString
            == "https://www.oxfordlearnersdictionaries.com/definition/english/hello?q=hello")
        #expect(decoded[2].url(for: "hello world")?.absoluteString
            == "https://www.google.com/search?q=define+hello%20world")
        #expect(decoded[3].url(for: "hello world")?.absoluteString
            == "https://youglish.com/pronounce/hello%20world/english")
        #expect(decoded[4].url(for: "hello world")?.absoluteString
            == "https://dictionary.cambridge.org/dictionary/english-vietnamese/hello")
    }

    @Test func validationRejectsBadLinks() {
        #expect(DictionaryLink.validationError(name: "", urlTemplate: "https://example.com/{word}") != nil)
        #expect(DictionaryLink.validationError(name: "X", urlTemplate: "https://example.com/no-placeholder") != nil)
        #expect(DictionaryLink.validationError(name: "X", urlTemplate: "not a url {word}") != nil)
        #expect(DictionaryLink.validationError(name: "Oxford", urlTemplate: "https://example.com/{word}") == nil)
        #expect(DictionaryLink.validationError(name: "Google", urlTemplate: "https://example.com/?q={text}") == nil)
    }
}
