import ApplicationServices
import Foundation

// MARK: - ContinuousSpeakController

/// Step 2 — "đọc nối tiếp" (Manh 2026-11-24): when the user clicks Speak
/// on the HOVER icon, read the hovered block, then automatically find and
/// read the next block below it, until no more blocks or the user stops.
/// Listening stays ON the page (no web extraction, no Reader) — this is
/// the Speechify-style continuous audio, not RSVP reading.
@MainActor
final class ContinuousSpeakController {
    /// How far below the current block to probe for the next one (AX
    /// coordinates, y grows downward). Several offsets because the gap
    /// between blocks varies (tight paragraphs vs. wide spacing) — the
    /// first probe that lands on a different block wins.
    private static let nextBlockProbeOffsets: [CGFloat] = [4, 24, 48, 80]

    private let ttsCoordinator: TTSCoordinator
    private let triggerIconController: TriggerIconController
    private let overlay: ReadingIndicatorOverlay

    /// The chain task (nil when idle). One chain at a time — starting a
    /// new chain stops the old one first.
    private var chainTask: Task<Void, Never>?
    /// Whether a chain is running. The loop checks this after every
    /// utterance, and `stop()` clears it — so a stop during speech ends
    /// the chain even if the in-flight utterance returns afterwards.
    private var isChaining = false
    /// The block being read right now (the controller's OWN copy — the
    /// hover detector may forget its block while speaking, so the chain
    /// must never depend on the detector after start).
    private var currentBlock: HoverBlock?
    /// Sentence ranges (NSRange, UTF-16 offsets in the current block's
    /// text) precomputed at each block start, so the word callback can
    /// map a spoken word to its sentence without re-splitting.
    private var sentenceRanges: [NSRange] = []
    /// The sentence currently highlighted (cached so its frame is only
    /// re-read from AX when the sentence actually changes, not on
    /// every word).
    private var currentSentenceRange: NSRange?
    /// The cached frame (AX coordinates) of `currentSentenceRange`, or
    /// nil when the app did not return one — the sentence level is
    /// simply not drawn then (the block + line still show).
    private var currentSentenceFrame: CGRect?

    init(ttsCoordinator: TTSCoordinator, triggerIconController: TriggerIconController, overlay: ReadingIndicatorOverlay) {
        self.ttsCoordinator = ttsCoordinator
        self.triggerIconController = triggerIconController
        self.overlay = overlay
    }

    /// Start a chain from a hovered block: stop any existing speech,
    /// show the reading indicator for this block, and read it — when it
    /// finishes on its own, the next block below is read, and so on.
    /// The icon speaking state is managed here (not via
    /// `onPlaybackEnded`): `speakContinuous` deliberately does not
    /// touch it, so a chain that ends naturally must clear it itself.
    func start(from block: HoverBlock) {
        // A new chain replaces the old one — stop first so no two
        // utterances overlap (same "stop before speak" rule as
        // `TTSCoordinator.speak`).
        stop()
        currentBlock = block
        sentenceRanges = Self.sentenceRanges(for: block.text)
        currentSentenceRange = nil
        currentSentenceFrame = nil
        // `stop()` above already stopped any speech from elsewhere (a
        // single speak, a read-along, or an old chain) — one voice at
        // a time — so the coordinator is quiet here.
        isChaining = true
        triggerIconController.setSpeaking(true)
        overlay.show(block: block)
        chainTask = Task { [weak self] in
            await self?.runChain()
        }
    }

    /// Stop everything: the in-flight utterance, the chain, the overlay
    /// and the icon speaking state. Idempotent — safe to call when idle
    /// (a single non-chained speak is stopped the same way).
    func stop() {
        isChaining = false
        chainTask?.cancel()
        chainTask = nil
        currentBlock = nil
        sentenceRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        // Stopping the coordinator bumps its generation, so an
        // in-flight `speakContinuous` returns false instead of true —
        // the loop then ends instead of chaining on.
        ttsCoordinator.stop()
        overlay.hide()
        triggerIconController.setSpeaking(false)
    }

    /// The chain loop: speak the current block, then advance to the
    /// next block below it. Ends when the user stops (isChaining
    /// cleared), an utterance is cut short, or no next block is found.
    private func runChain() async {
        while isChaining {
            guard let block = currentBlock else { return }
            // `speakContinuous` reports each word's range so the overlay
            // can track the sentence/word; its Bool is the chaining
            // signal (true = finished on its own, false = cut short).
            // The language rule is the app's single shared one
            // (`AppDelegate.speakLanguage`) so the chain and the
            // single-speak path can never disagree on language.
            let finished = await ttsCoordinator.speakContinuous(
                block.text,
                language: AppDelegate.speakLanguage(for: block.text),
                onWordRange: { [weak self] range in
                    self?.handleWordRange(range)
                }
            )
            // Stopped while speaking, or cut short from outside — the
            // chain ends here (stop() already cleaned up).
            guard isChaining, finished else { return }
            // Find the next block below this one; none means the end
            // of the article — end the chain and clear the icon state
            // (speakContinuous never fires onPlaybackEnded).
            guard let next = Self.nextBlock(below: block) else {
                endChain()
                return
            }
            currentBlock = next
            sentenceRanges = Self.sentenceRanges(for: next.text)
            currentSentenceRange = nil
            currentSentenceFrame = nil
            overlay.show(block: next)
        }
    }

    /// Natural end of a chain (no more blocks): hide the indicator and
    /// clear the icon speaking state. Unlike `stop()` this does not
    /// call `ttsCoordinator.stop()` — the speech already finished.
    private func endChain() {
        isChaining = false
        chainTask = nil
        currentBlock = nil
        sentenceRanges = []
        currentSentenceRange = nil
        currentSentenceFrame = nil
        overlay.hide()
        triggerIconController.setSpeaking(false)
    }

    /// A spoken word's range arrived: map it to its sentence and update
    /// the overlay (word + sentence frames). The sentence frame is
    /// cached and only re-read when the sentence changes; the word
    /// frame is read every time (it moves with every word). Either
    /// level may be nil (the app does not expose range bounds) — the
    /// overlay simply skips that level.
    private func handleWordRange(_ wordRange: NSRange) {
        guard let block = currentBlock else { return }
        guard let sentenceRange = Self.sentence(containing: wordRange.location, in: sentenceRanges) else { return }
        var sentenceFrame = currentSentenceFrame
        if sentenceRange != currentSentenceRange {
            currentSentenceRange = sentenceRange
            sentenceFrame = HoverBlockText.bounds(for: sentenceRange, in: block.element)
            currentSentenceFrame = sentenceFrame
        }
        let wordFrame = HoverBlockText.bounds(for: wordRange, in: block.element)
        overlay.update(wordFrame: wordFrame, sentenceFrame: sentenceFrame)
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
}
