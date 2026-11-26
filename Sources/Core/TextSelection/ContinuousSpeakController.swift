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
    /// line is a single cluster (the whole block).
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
        // A new chain replaces the old one — stop first so no two
        // utterances overlap (same "stop before speak" rule as
        // `TTSCoordinator.speak`).
        stop()
        currentBlock = block
        currentSingleText = nil
        sentenceRanges = Self.sentenceRanges(for: block.text)
        clusterRanges = Self.paragraphRanges(for: block.text)
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
    }

    /// Speak a single text (a selection — no hover block, so no overlay
    /// and no chaining) with the same play/pause/resume law. The
    /// indicator shows the session (playing/paused) so the user can
    /// pause and resume it — the float icon does not.
    func start(text: String, indicatorFrame: CGRect?) {
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
        clusterRanges = Self.paragraphRanges(for: next.text)
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
            // No cluster for this sentence (only when the block text
            // has no non-blank line) — clear the cluster fill instead
            // of leaving a stale one.
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

    /// Split `text` into paragraph (cluster) ranges (NSRange, UTF-16
    /// offsets — the same indexing as `sentenceRanges`). A cluster is a
    /// run of non-blank lines: blank lines (empty, or only spaces/tabs)
    /// separate clusters, but a single newline inside a cluster (a
    /// wrapped line) does NOT split it. A block with no blank line is
    /// one cluster (the whole block) — the common case for short
    /// paragraphs. The ranges exclude the blank separator lines, so a
    /// cluster's AX bounds cover only its own text.
    static func paragraphRanges(for text: String) -> [NSRange] {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else { return [] }
        // First, the line ranges (without their newline terminator —
        // "\r\n" counts as one line break).
        var lines: [NSRange] = []
        var lineStart = 0
        var index = 0
        while index < length {
            let ch = nsText.character(at: index)
            if ch == 0x0A || ch == 0x0D { // "\n" "\r"
                lines.append(NSRange(location: lineStart, length: index - lineStart))
                index += 1
                if ch == 0x0D, index < length, nsText.character(at: index) == 0x0A { index += 1 }
                lineStart = index
                continue
            }
            index += 1
        }
        if lineStart < length {
            lines.append(NSRange(location: lineStart, length: length - lineStart))
        }
        // A line is blank when it holds only spaces/tabs (or is empty).
        func isBlank(_ line: NSRange) -> Bool {
            for i in line.location..<(line.location + line.length) {
                let c = nsText.character(at: i)
                guard c == 0x20 || c == 0x09 else { return false } // space/tab
            }
            return true
        }
        // Group consecutive non-blank lines into clusters; a blank line
        // ends the current cluster.
        var ranges: [NSRange] = []
        var clusterStart: Int? = nil
        var clusterEnd = 0
        for line in lines {
            if isBlank(line) {
                if let start = clusterStart {
                    ranges.append(NSRange(location: start, length: clusterEnd - start))
                    clusterStart = nil
                }
            } else {
                if clusterStart == nil { clusterStart = line.location }
                clusterEnd = line.location + line.length
            }
        }
        if let start = clusterStart {
            ranges.append(NSRange(location: start, length: clusterEnd - start))
        }
        return ranges
    }

    /// The paragraph (cluster) containing a UTF-16 offset — same lookup
    /// as `sentence(containing:in:)`: the range holding the offset, else
    /// the last one starting at or before it, else the first. A sentence
    /// always sits inside exactly one cluster, so this always finds one
    /// while a word is being spoken.
    static func paragraph(containing offset: Int, in ranges: [NSRange]) -> NSRange? {
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
