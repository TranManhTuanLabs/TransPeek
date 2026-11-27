import ApplicationServices
import Foundation

// MARK: - ContinuousSpeakController

/// Step 2 — "đọc nối tiếp" (Manh 2026-11-24): when the user clicks Speak
/// on the HOVER icon, read the hovered block, then automatically find and
/// read the next block below it, until no more blocks or the user stops.
/// Listening stays ON the page (no web extraction, no Reader) — this is
/// the Speechify-style continuous audio, not RSVP reading.
/// The speaker law (Manh 2026-11-26, SPEECH_PLAYER.md §1) applies here
/// too: click = pause (keep position), click again = resume, no Esc and
/// no Stop — the pause/resume control lives on the SEPARATE speak
/// indicator (Manh 2026-11-26), not on the float icon: while paused the
/// indicator auto-hides after 5s, and when it hides the session ends
/// silently. The indicator shows pause/play glyphs instead of a plain
/// speaker.
@MainActor
final class ContinuousSpeakController {
    /// How far below the current block to probe for the next one (AX
    /// coordinates, y grows downward). Several offsets because the gap
    /// between blocks varies (tight paragraphs vs. wide spacing) — the
    /// first probe that lands on a different block wins.
    private static let nextBlockProbeOffsets: [CGFloat] = [4, 24, 48, 80]

    /// The separate speak indicator (Manh 2026-11-26): the floating ⏸/▶
    /// button that owns pause/resume for this session. It is NOT the
    /// float icon — the icon keeps its own lifecycle and never shows
    /// playback state.
    private let indicator: SpeakIndicatorController
    private let overlay: ReadingIndicatorOverlay
    /// The play/pause/resume player for the current block (Manh
    /// 2026-11-26): one unit at a time, word-tracked, so pause can keep
    /// the position and resume can continue from it. The chain drives
    /// it block by block; a single (non-chained) speak uses it too.
    private let player: SpeechPlayer

    /// Whether a chain is running (a hovered block being read + the
    /// blocks below it). False for a single speak (selection) and when
    /// idle. The player's onEnded advances the chain; onStopped ends it.
    private var isChaining = false
    /// Whether a new session is replacing the current one (Manh
    /// 2026-11-27, 19:38 — the reminder auto-show hook): `start()`
    /// stops the old session first, and that stop fires `onStopped`
    /// synchronously — without this flag the hook would pop the
    /// reminder mid-flow and cut the new listen short. Set before
    /// `stop()` in `start()`, cleared once the new play has started.
    private var isReplacingSession = false
    /// Fires when a listen session ends — naturally (the last unit
    /// finished) or stopped (the indicator hid while paused, or
    /// another surface cut it short). NOT fired while a new session
    /// is replacing this one (see `isReplacingSession`). Set by
    /// AppDelegate: the focus timer store shows a pending reminder
    /// from it (Manh 2026-11-27, 19:38 — "Nghe hết unit → reminder
    /// chờ tự hiện"). Never fires on pause (the session is suspended,
    /// not ended).
    var onSessionEnded: (() -> Void)?
    /// The block being read right now (the controller's OWN copy — the
    /// hover detector may forget its block while speaking, so the chain
    /// must never depend on the detector after start).
    private var currentBlock: HoverBlock?
    /// The single (non-chained) text being read, if any — a selection
    /// has no block frame, so it has no overlay and no chaining; it is
    /// still a unit under the speaker law (pause/resume apply).
    private var currentSingleText: String?
    /// Sentence ranges (NSRange, UTF-16 offsets in the current block's
    /// text) precomputed at each block start, so the word callback can
    /// map a spoken word to its sentence without re-splitting.
    private var sentenceRanges: [NSRange] = []
    /// Paragraph (cluster) ranges (NSRange, UTF-16 offsets in the
    /// current block's text) precomputed at each block start — a
    /// cluster is a run of sentences separated from the next by a blank
    /// line, so the word callback can map a spoken word to the cluster
    /// around its sentence without re-splitting. A block with no blank
    /// line yields a single range (the whole block), which is NOT a
    /// cluster for highlighting (Manh 2026-11-27 — see
    /// `paragraph(containing:in:)`).
    private var clusterRanges: [NSRange] = []
    /// The sentence currently highlighted (cached so its frame is only
    /// re-read from AX when the sentence actually changes, not on
    /// every word).
    private var currentSentenceRange: NSRange?
    /// The cached frame (AX coordinates) of `currentSentenceRange`, or
    /// nil when the app did not return one — the sentence level is
    /// simply not drawn then (the block + line still show).
    private var currentSentenceFrame: CGRect?
    /// The cluster currently highlighted (cached like the sentence:
    /// its frame is only re-read from AX when the cluster actually
    /// changes, not on every word).
    private var currentClusterRange: NSRange?
    /// The cached frame (AX coordinates) of `currentClusterRange`, or
    /// nil when the app did not return one — the cluster level is
    /// simply not drawn then (the other levels still show).
    private var currentClusterFrame: CGRect?

    init(ttsCoordinator: TTSCoordinator, indicator: SpeakIndicatorController, overlay: ReadingIndicatorOverlay) {
        self.indicator = indicator
        self.overlay = overlay
        // The player owns the per-unit playback (word tracking +
        // pause/resume). The controller wires its callbacks: word ranges
        // update the overlay, a natural end advances the chain, and a
        // stop ends the chain (or the single speak).
        self.player = SpeechPlayer(ttsCoordinator: ttsCoordinator)
        self.player.onWordRange = { [weak self] range in
            self?.handleWordRange(range)
        }
        self.player.onEnded = { [weak self] in
            self?.handleUnitEnded()
        }
        self.player.onStopped = { [weak self] in
            self?.handleSessionStopped()
        }
    }

    /// Whether a session is live (playing OR paused). Used by
    /// AppDelegate: when the indicator hides while a session is live,
    /// the session ends silently (no Esc, no Stop button).
    var isActive: Bool { player.isActive }
    /// Whether the current session is paused (the indicator shows ▶).
    var isPaused: Bool { player.state == .paused }

    /// Start a chain from a hovered block: stop any existing speech,
    /// show the reading indicator for this block, and read it — when it
    /// finishes on its own, the next block below is read, and so on.
    /// The indicator state is managed here (not via `onPlaybackEnded`):
    /// the player deliberately does not touch it, so a chain that ends
    /// naturally must clear it itself. `indicatorFrame` is the float
    /// icon's frame (the place the user clicked Speak) — the indicator
    /// takes the icon's place; nil centres it on the mouse.
    func start(from block: HoverBlock, indicatorFrame: CGRect?) {
        // A new chain replaces the old one — mark it BEFORE stopping,
        // so the stop's synchronous onStopped does not fire the
        // session-ended hook (the reminder must not pop mid-flow and
        // cut this new listen short — Manh 2026-11-27, 19:38). The
        // stop itself still runs first, so no two utterances overlap
        // (same "stop before speak" rule as `TTSCoordinator.speak`).
        isReplacingSession = true
        stop()
        currentBlock = block
        currentSingleText = nil
        sentenceRanges = Self.sentenceRanges(for: block.text)
        clusterRanges = Self.paragraphRanges(for: block.text, sentences: sentenceRanges)
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        isChaining = true
        indicator.show(at: indicatorFrame)
        overlay.show(block: block)
        // The player stops any speech from elsewhere (a single speak, a
        // panel speak, a read-along) — one voice at a time — then reads
        // this block; its onEnded advances the chain.
        player.play(text: block.text, language: AppDelegate.speakLanguage(for: block.text))
        // The new session is live now — the replacement stop is over,
        // so the flag can go (a later real end must fire the hook).
        isReplacingSession = false
    }

    /// Speak a single text (a selection — no hover block, so no overlay
    /// and no chaining) with the same play/pause/resume law. The
    /// indicator shows the session (playing/paused) so the user can
    /// pause and resume it — the float icon does not.
    func start(text: String, indicatorFrame: CGRect?) {
        // Same replacement marking as `start(from:)` (Manh 2026-11-27,
        // 19:38): a single speak also replaces the old session, so its
        // stop must not fire the session-ended hook either.
        isReplacingSession = true
        stop()
        currentBlock = nil
        currentSingleText = text
        sentenceRanges = []
        clusterRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        isChaining = false
        indicator.show(at: indicatorFrame)
        player.play(text: text, language: AppDelegate.speakLanguage(for: text))
        // The new session is live now — the replacement stop is over,
        // so the flag can go (a later real end must fire the hook).
        isReplacingSession = false
    }

    /// Pause the current session (Manh 2026-11-26): the voice stops but
    /// the position and the highlight stay, so resume continues from
    /// the same word. The indicator flips to ▶ and starts its 5s
    /// auto-hide (when it hides, the session ends silently). No-op when
    /// not playing.
    func pause() {
        guard player.state == .playing else { return }
        player.pause()
        indicator.setPaused(true)
    }

    /// Resume a paused session from the kept position (Manh 2026-11-26).
    /// The indicator flips back to ⏸ and its auto-hide is cancelled.
    /// No-op when not paused.
    func resume() {
        guard player.state == .paused else { return }
        player.resume()
        indicator.setPaused(false)
    }

    /// Stop everything: the in-flight utterance, the chain, the overlay
    /// and the indicator. Idempotent — safe to call when idle.
    /// (The indicator hiding while paused, and "new play replaces old
    /// play", both come through here. There is no Esc and no Stop button.)
    func stop() {
        isChaining = false
        currentBlock = nil
        currentSingleText = nil
        sentenceRanges = []
        clusterRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        // Stopping the player bumps its generation, so an in-flight
        // utterance returns without firing onEnded — the chain then
        // ends instead of advancing.
        player.stop()
        overlay.hide()
        indicator.hide()
    }

    /// The current unit finished on its own: for a chain, advance to the
    /// next block below; for a single speak (or the last block), end the
    /// session and hide the indicator (the player never fires
    /// onPlaybackEnded, so the controller clears it itself).
    private func handleUnitEnded() {
        guard isChaining, let block = currentBlock else {
            // A single speak ended, or the chain already stopped — end
            // the session (the player is already idle).
            endSession()
            return
        }
        // Find the next block below this one; none means the end of the
        // article — end the session.
        guard let next = Self.nextBlock(below: block) else {
            endSession()
            return
        }
        currentBlock = next
        sentenceRanges = Self.sentenceRanges(for: next.text)
        clusterRanges = Self.paragraphRanges(for: next.text, sentences: sentenceRanges)
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        overlay.show(block: next)
        player.play(text: next.text, language: AppDelegate.speakLanguage(for: next.text))
    }

    /// The session was stopped or cut short from outside (the indicator
    /// hid while paused, a new play on another surface, an auto-play):
    /// end the chain/session and hide the indicator + overlay. (A pause
    /// does NOT fire this — the player only calls onStopped for a real
    /// end, never for a pause.)
    private func handleSessionStopped() {
        // If this stop came from our own stop() (which already cleared
        // everything), these are no-ops — the guards make it safe.
        isChaining = false
        currentBlock = nil
        currentSingleText = nil
        sentenceRanges = []
        clusterRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        overlay.hide()
        indicator.hide()
        // The session is over — a pending reminder may show itself
        // now (unless a new session is replacing this one).
        notifySessionEnded()
    }

    /// The session ended (natural end or stop) — tell whoever is
    /// listening (the focus timer store, via AppDelegate) so a pending
    /// reminder can show itself. Skipped while a new session is
    /// replacing this one: the stop a replacement causes must not pop
    /// the reminder mid-flow (Manh 2026-11-27, 19:38).
    private func notifySessionEnded() {
        guard !isReplacingSession else { return }
        onSessionEnded?()
    }

    /// Natural end of a session (last block read, or a single speak
    /// finished): hide the overlay + indicator. Unlike `stop()` this
    /// does not call the player (it is already idle — the unit finished
    /// on its own).
    private func endSession() {
        isChaining = false
        currentBlock = nil
        currentSingleText = nil
        sentenceRanges = []
        clusterRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        currentClusterRange = nil
        currentClusterFrame = nil
        overlay.hide()
        indicator.hide()
        // The unit finished on its own — a pending reminder may show
        // itself now (the "Nghe hết unit → reminder chờ tự hiện" rule,
        // Manh 2026-11-27, 19:38).
        notifySessionEnded()
    }

    /// A spoken word's range arrived: map it to its sentence and
    /// cluster and update the overlay (word + sentence + cluster
    /// frames). The sentence and cluster frames are cached and only
    /// re-read when they actually change; the word frame is read every
    /// time (it moves with every word). Any level may be nil (the app
    /// does not expose range bounds) — the overlay simply skips that
    /// level. Ignored for a single speak (no overlay, no block).
    private func handleWordRange(_ wordRange: NSRange) {
        guard let block = currentBlock else { return }
        guard let sentenceRange = Self.sentence(containing: wordRange.location, in: sentenceRanges) else { return }
        var sentenceFrame = currentSentenceFrame
        if sentenceRange != currentSentenceRange {
            currentSentenceRange = sentenceRange
            sentenceFrame = HoverBlockText.bounds(for: sentenceRange, in: block.element)
            currentSentenceFrame = sentenceFrame
        }
        // The cluster is the paragraph around the sentence (a sentence
        // never spans a newline, so it always sits inside exactly one
        // cluster). Its frame is cached the same way as the sentence's.
        var clusterFrame = currentClusterFrame
        if let clusterRange = Self.paragraph(containing: sentenceRange.location, in: clusterRanges) {
            if clusterRange != currentClusterRange {
                currentClusterRange = clusterRange
                clusterFrame = HoverBlockText.bounds(for: clusterRange, in: block.element)
                currentClusterFrame = clusterFrame
            }
        } else {
            // No cluster for this sentence — either the block text has
            // no non-blank line, or the block is a single paragraph
            // (Manh 2026-11-27: no boundary means no cluster, the
            // cluster would be the whole block). Clear the cluster
            // fill instead of leaving a stale one.
            currentClusterRange = nil
            clusterFrame = nil
            currentClusterFrame = nil
        }
        let wordFrame = HoverBlockText.bounds(for: wordRange, in: block.element)
        overlay.update(wordFrame: wordFrame, sentenceFrame: sentenceFrame, clusterFrame: clusterFrame)
    }

    /// The next block below `block`: probe points just under its frame
    /// (AX coordinates, y grows downward) and take the first hit that
    /// yields a DIFFERENT block. A probe inside the same block (or on
    /// nothing hoverable) is skipped, not taken.
    private static func nextBlock(below block: HoverBlock) -> HoverBlock? {
        for offset in nextBlockProbeOffsets {
            let point = CGPoint(x: block.frame.midX, y: block.frame.maxY + offset)
            guard let hit = HoverBlockText.element(at: point),
                  let candidate = HoverBlockText.blockText(from: hit),
                  !HoverBlockText.isSameBlock(
                    text: candidate.text, frame: candidate.frame,
                    otherText: block.text, otherFrame: block.frame
                  )
            else { continue }
            return candidate
        }
        return nil
    }

    /// Split `text` into sentence ranges (NSRange, UTF-16 offsets —
    /// the same indexing the TTS word callback reports). A sentence
    /// ends at `.`/`!`/`?` followed by whitespace or end-of-string, or
    /// at a newline. A simple splitter is enough for the trial — it
    /// only has to map a spoken word to the sentence around it, not
    /// to parse language.
    static func sentenceRanges(for text: String) -> [NSRange] {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else { return [] }
        var ranges: [NSRange] = []
        var start = 0
        var index = 0
        while index < length {
            let ch = nsText.character(at: index)
            let isTerminator = ch == 0x2E || ch == 0x21 || ch == 0x3F // "." "!" "?"
            let isNewline = ch == 0x0A || ch == 0x0D // "\n" "\r"
            if isTerminator || isNewline {
                // A terminator only ends the sentence when the next
                // character is whitespace or the string ends — "e.g."
                // and "3.5" must not split mid-sentence. Whitespace is
                // checked as raw UTF-16 units (space/tab/newline/CR) so
                // no Unicode.Scalar conversion can fail on a surrogate.
                let nextIsBoundary: Bool
                if index + 1 >= length {
                    nextIsBoundary = true
                } else {
                    let next = nsText.character(at: index + 1)
                    nextIsBoundary = next == 0x20 || next == 0x09 || next == 0x0A || next == 0x0D
                }
                if isNewline || nextIsBoundary {
                    // The sentence runs up to and including the
                    // terminator (a newline is the boundary itself, so
                    // the sentence ends just before it).
                    let end = isNewline ? index : index + 1
                    if end > start {
                        ranges.append(NSRange(location: start, length: end - start))
                    }
                    // The next sentence starts after the terminator and
                    // any following whitespace.
                    var nextStart = index + 1
                    while nextStart < length {
                        let c = nsText.character(at: nextStart)
                        guard c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D else { break }
                        nextStart += 1
                    }
                    start = nextStart
                    index = nextStart
                    continue
                }
            }
            index += 1
        }
        // Trailing text without a terminator is still a sentence (the
        // last line of a block rarely ends with a period).
        if start < length {
            ranges.append(NSRange(location: start, length: length - start))
        }
        return ranges
    }

    /// The sentence containing a UTF-16 offset, or the nearest one when
    /// the offset falls in the whitespace between sentences (a word is
    /// never whitespace, so this is only a safety net).
    static func sentence(containing offset: Int, in ranges: [NSRange]) -> NSRange? {
        for range in ranges where NSLocationInRange(offset, range) {
            return range
        }
        // Fallback: the last sentence starting at or before the offset,
        // else the first sentence — the overlay always has a sentence
        // to show while a word is being spoken.
        var fallback: NSRange?
        for range in ranges where range.location <= offset {
            fallback = range
        }
        return fallback ?? ranges.first
    }

    /// Group sentences into paragraph (cluster) ranges (NSRange, UTF-16
    /// offsets — the same indexing as `sentenceRanges`). A cluster is a
    /// run of sentences in one paragraph; a new cluster starts at a
    /// sentence when the whitespace before it marks a paragraph
    /// boundary (Manh 2026-11-27 16:14 — the ORIGINAL rule): (1) a blank
    /// line in the gap (2+ line breaks); (2) a single line break; (3)
    /// the sentence is indented (a tab anywhere in the gap, or 2+
    /// spaces — a single space is ordinary inter-sentence spacing, not
    /// a boundary). CRLF counts as one line break, so it never splits
    /// by itself. A cluster's range runs from its first sentence's
    /// start to its last sentence's end, so its AX bounds cover only
    /// its own text. A block whose sentences form a single cluster
    /// yields one range — which is NOT a cluster for highlighting (see
    /// `paragraph(containing:in:)`).
    /// TEMPORARILY reverted (Manh 2026-11-27 19:38): the branch had
    /// added a punctuation gate — a single line break split only after
    /// a sentence ending in `.`/`!`/`?` — to stop a visually wrapped
    /// PDF paragraph splitting into one cluster per line. Manh asked
    /// to REMOVE it for now and follow main's literal rule, because a
    /// PDF paragraph wrapped over many lines becoming ONE big block
    /// breaks the display — the block highlight frame can exceed the
    /// PDF frame being read. This is a TEMPORARY revert, not a
    /// rejection of the gate: the gate may come back once the
    /// block-frame problem is understood. Do not re-add it without
    /// Manh's say-so.
    static func paragraphRanges(for text: String, sentences: [NSRange]) -> [NSRange] {
        guard !sentences.isEmpty else { return [] }
        let nsText = text as NSString
        var ranges: [NSRange] = []
        var start = sentences[0].location
        var end = sentences[0].location + sentences[0].length
        for i in 1..<sentences.count {
            let prev = sentences[i - 1]
            let cur = sentences[i]
            // A paragraph boundary is any of three signals in the
            // whitespace gap between the sentences (Manh 2026-11-27
            // 16:14): a blank line (2+ line breaks), a single line
            // break (1), or an indented next sentence. Books/PDFs
            // often separate paragraphs with just one line break or
            // an indented first line (no blank line), and the old
            // 2+ rule missed those. A single space is the normal
            // sentence separator, not a boundary. A CRLF pair counts
            // as ONE line break, so Windows-style endings never split
            // a paragraph by accident.
            var breaks = 0
            var hasTab = false
            var j = prev.location + prev.length
            while j < cur.location {
                let ch = nsText.character(at: j)
                if ch == 0x0D { // "\r" — a CRLF pair is one break
                    breaks += 1
                    if j + 1 < cur.location, nsText.character(at: j + 1) == 0x0A { j += 1 }
                } else if ch == 0x0A { // "\n"
                    breaks += 1
                } else if ch == 0x09 { // "\t" — a tab before the next sentence is indentation
                    hasTab = true
                }
                j += 1
            }
            // The gap is all whitespace (the sentence splitter skips
            // it), so its length is the indent width when there is no
            // line break: 2+ spaces is an indented first line, 1 space
            // is just the separator between sentences.
            let gapLength = cur.location - (prev.location + prev.length)
            if breaks >= 1 || hasTab || gapLength >= 2 {
                ranges.append(NSRange(location: start, length: end - start))
                start = cur.location
            }
            end = cur.location + cur.length
        }
        ranges.append(NSRange(location: start, length: end - start))
        return ranges
    }

    /// The paragraph (cluster) containing a UTF-16 offset — same lookup
    /// as `sentence(containing:in:)`: the range holding the offset, else
    /// the last one starting at or before it, else the first. A sentence
    /// always sits inside exactly one cluster, so this finds one while
    /// a word is being spoken — EXCEPT when the block has no paragraph
    /// boundary at all (see below).
    static func paragraph(containing offset: Int, in ranges: [NSRange]) -> NSRange? {
        // No cluster when the block is a single paragraph (Manh
        // 2026-11-27): one range means no blank line split the block,
        // so the "cluster" would be the whole block — drawing its fill
        // over the whole block is redundant (the block has its own Show
        // toggle for that) and blurs where the two translucent fills
        // overlap. A cluster only marks a PART of a block, so a block
        // with no boundary has no cluster to highlight — return nil
        // and the caller clears the cluster fill.
        guard ranges.count > 1 else { return nil }
        for range in ranges where NSLocationInRange(offset, range) {
            return range
        }
        var fallback: NSRange?
        for range in ranges where range.location <= offset {
            fallback = range
        }
        return fallback ?? ranges.first
    }
}
