import Foundation

/// RSVP (Rapid Serial Visual Presentation) engine — pure logic, no UI.
///
/// Port of the SwiftRead legacy engine's timing model (see
/// `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`, §1/§4):
/// one slide = a chunk of 1–6 words shown at a fixed focal point, the
/// reader's eye never moves. The delay of each slide is the base time
/// (`60000 / WPM × wordCount`) stretched by micro-pause multipliers for
/// numbers, punctuation, sentence ends, long words and new paragraphs.
/// The ORP (Optimal Recognition Point) is the middle character of the
/// slide's middle word (`floor(n / 2)`), highlighted in the view so the
/// eye always lands on the same spot.
struct RSVPEngine {
    /// One slide: the words shown together, how long they stay, and where
    /// the ORP highlight goes.
    struct Slide {
        /// Words in this slide, in reading order.
        let words: [String]
        /// Index of the first word of this slide in the full word list.
        let startWordIndex: Int
        /// How long the slide stays on screen, in milliseconds.
        let delayMs: Double
        /// Index of the word carrying the ORP highlight, within `words`.
        let pivotWordIndex: Int
        /// Character index of the ORP highlight within that word.
        let pivotCharIndex: Int

        /// The slide's words joined with single spaces, as shown on screen.
        var joinedText: String { words.joined(separator: " ") }

        /// Character offset of the ORP highlight within `joinedText`.
        var pivotOffset: Int {
            var offset = 0
            for i in 0..<pivotWordIndex {
                offset += words[i].count + 1 // word + the space after it
            }
            return offset + pivotCharIndex
        }
    }

    /// All words of the source text, in reading order.
    let words: [String]
    /// Slides built from `words` at the given chunk size.
    let slides: [Slide]

    let wpm: Int
    let chunkSize: Int

    /// Default reading speed (Manh 2026-11-18, round 7: 500, was the
    /// SwiftRead legacy default 275).
    static let defaultWPM = 500
    /// Hard maximum (SwiftRead legacy hard cap).
    static let maxWPM = 2000
    /// WPM step used by the stepper / arrow keys (Manh 2026-11-18,
    /// round 7: 50, was 25 — the speed picker moves in 50s too).
    static let wpmStep = 50
    /// Chunk size range: 1–6 words per slide.
    static let chunkRange = 1...6
    /// Words shown around the current slide in the pause context.
    static let contextRadius = 150

    /// Micro-pause extras, added to the base multiplier 1.0 (SwiftRead
    /// legacy values; the user-facing slider 0.1–3 scales them, v1 keeps
    /// the legacy 1.0 scale).
    private enum MicroPause {
        /// A word containing a digit.
        static let number = 0.5
        /// A word ending in `,` `;` `:`.
        static let punctuation = 0.9
        /// A word ending in `.` `!` `?`.
        static let sentenceEnd = 1.1
        /// A word longer than `8 × chunkSize` characters.
        static let longWord = 0.5
        /// A slide starting a new paragraph.
        static let newParagraph = 1.1
    }

    /// Execution overhead subtracted from every slide's delay (SwiftRead
    /// legacy: 30 ms per slide).
    private static let executionOverheadMs = 30.0
    /// Shortest delay allowed, so a very high WPM never spins the timer.
    private static let minimumDelayMs = 50.0

    init(text: String, wpm: Int = defaultWPM, chunkSize: Int = 1) {
        self.wpm = max(50, min(Self.maxWPM, wpm))
        self.chunkSize = max(Self.chunkRange.lowerBound, min(Self.chunkRange.upperBound, chunkSize))
        let tokenized = Self.tokenize(text)
        self.words = tokenized.map(\.word)
        self.slides = Self.buildSlides(
            tokenized: tokenized,
            wpm: self.wpm,
            chunkSize: self.chunkSize
        )
    }

    // MARK: - Tokenizing

    /// A word plus whether it starts a new paragraph (preceded by a blank
    /// line in the source text).
    private struct Token {
        let word: String
        let startsParagraph: Bool
    }

    /// Split the text into words. Paragraphs are separated by a blank line
    /// (two or more newlines); the first word after a blank line is marked
    /// so the engine can add the new-paragraph micro-pause.
    private static func tokenize(_ text: String) -> [Token] {
        // Split on runs of 2+ newlines = paragraph breaks, keeping the
        // break positions. A single newline inside a paragraph is just
        // whitespace.
        let paragraphSeparator = try? NSRegularExpression(pattern: "\\n\\s*\\n")
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var tokens: [Token] = []
        var lastEnd = 0
        let matches = paragraphSeparator?.matches(in: text, range: fullRange) ?? []
        var paragraphStarts: [Int] = [0]
        for match in matches {
            paragraphStarts.append(match.range.upperBound)
        }
        paragraphStarts.append(nsText.length)

        for i in 0..<paragraphStarts.count - 1 {
            let start = paragraphStarts[i]
            let end = paragraphStarts[i + 1]
            let paragraph = nsText.substring(with: NSRange(location: start, length: end - start))
            let words = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            for (wordIndex, word) in words.enumerated() {
                tokens.append(Token(
                    word: word,
                    startsParagraph: i > 0 && wordIndex == 0
                ))
            }
            lastEnd = end
        }
        _ = lastEnd
        return tokens
    }

    // MARK: - Slides

    private static func buildSlides(tokenized: [Token], wpm: Int, chunkSize: Int) -> [Slide] {
        guard !tokenized.isEmpty else { return [] }
        // Micro-pauses are off when chunk × WPM ≤ 100 (SwiftRead legacy).
        let pausesEnabled = chunkSize * wpm > 100
        var slides: [Slide] = []
        var index = 0
        while index < tokenized.count {
            let end = min(index + chunkSize, tokenized.count)
            let chunk = Array(tokenized[index..<end])
            let delay = delayMs(for: chunk, wpm: wpm, chunkSize: chunkSize, pausesEnabled: pausesEnabled)
            let pivotWordIndex = chunk.count / 2
            let pivotWord = chunk[pivotWordIndex].word
            slides.append(Slide(
                words: chunk.map(\.word),
                startWordIndex: index,
                delayMs: delay,
                pivotWordIndex: pivotWordIndex,
                pivotCharIndex: pivotWord.count / 2
            ))
            index = end
        }
        return slides
    }

    /// Delay for one slide: base time stretched by the micro-pause
    /// multipliers of its words, minus the 30 ms execution overhead.
    private static func delayMs(for chunk: [Token], wpm: Int, chunkSize: Int, pausesEnabled: Bool) -> Double {
        let baseMs = 60000.0 / Double(wpm) * Double(chunk.count)
        guard pausesEnabled else {
            return max(baseMs - executionOverheadMs, minimumDelayMs)
        }
        var multiplier = 1.0
        for token in chunk {
            let word = token.word
            if token.startsParagraph {
                multiplier += MicroPause.newParagraph
            }
            if word.contains(where: \.isNumber) {
                multiplier += MicroPause.number
            }
            if word.count > 8 * chunkSize {
                multiplier += MicroPause.longWord
            }
            if let last = word.last {
                if last == "." || last == "!" || last == "?" {
                    multiplier += MicroPause.sentenceEnd
                } else if last == "," || last == ";" || last == ":" {
                    multiplier += MicroPause.punctuation
                }
            }
        }
        return max(baseMs * multiplier - executionOverheadMs, minimumDelayMs)
    }

    // MARK: - Context

    /// Words around the slide at `slideIndex`, for the pause context view:
    /// up to 150 words before and after, with the slide's own words marked
    /// by their range. Returns `nil` for an out-of-range slide.
    func context(for slideIndex: Int) -> (before: [String], current: [String], after: [String])? {
        guard slides.indices.contains(slideIndex) else { return nil }
        let slide = slides[slideIndex]
        let beforeStart = max(0, slide.startWordIndex - Self.contextRadius)
        let afterEnd = min(words.count, slide.startWordIndex + slide.words.count + Self.contextRadius)
        return (
            before: Array(words[beforeStart..<slide.startWordIndex]),
            current: slide.words,
            after: Array(words[(slide.startWordIndex + slide.words.count)..<afterEnd])
        )
    }

    /// Total reading time at the current settings, in seconds.
    var totalSeconds: Double {
        slides.reduce(0) { $0 + $1.delayMs } / 1000
    }

    /// Effective words-per-minute the reader actually sees (the WPM
    /// setting × chunk size, as SwiftRead displays it).
    var effectiveWPM: Int { wpm * chunkSize }
}
