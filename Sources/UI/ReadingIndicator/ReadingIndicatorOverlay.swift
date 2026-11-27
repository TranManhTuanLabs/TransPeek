import AppKit
import Defaults
import Foundation

// MARK: - ReadingIndicatorOverlay

/// Step 2 — reading indicator (Manh 2026-11-24): a floating overlay that
/// marks the block being read on the page itself — a vertical line at
/// the block's left edge plus translucent highlights for the block, the
/// paragraph (cluster) around the sentence, the sentence and (when the
/// app exposes range bounds) the word.
/// It draws OVER another app's window without touching that app: the
/// window ignores mouse events (clicks pass through) and never becomes
/// key, so reading along never steals input from the page.
/// Follow-ONLY in this build (phase 1): a 0.3 s timer re-reads the
/// block frame and repositions the window. The hide-during-scroll
/// fallback (phase 2) is built too (Manh 2026-11-27): while the frame
/// moves, the highlight content hides and the window still follows;
/// two stable polls (~0.6 s) bring it back. A Settings toggle
/// ("Hide highlights while scrolling", default ON) turns it off for
/// the old follow-only behaviour (see the trial plan).
/// Which layers are drawn is configurable (Manh 2026-11-26): main
/// draws ONLY sentence + word (the branch is not stable yet, so the
/// line + block stay on the branch); the branch draws all six. One
/// file, one component — the layers are a setting, not a fork. Each
/// layer also has its own Show toggle in Settings (Manh 2026-11-27):
/// a hidden layer is never drawn, on either side. The sixth layer is
/// an underline under the word + sentence (Manh 2026-11-27) — a thin
/// solid bar instead of a rectangle fill, because the fills' hard
/// edges read as a border; see `isUnderlineShown`.
@MainActor
final class ReadingIndicatorOverlay {
    /// Which indicator layers to draw. Main = sentence + word only;
    /// the branch = all six (line + block + cluster + sentence + word
    /// + underline).
    struct Layers: OptionSet {
        let rawValue: Int
        static let line = Layers(rawValue: 1 << 0)
        static let block = Layers(rawValue: 1 << 1)
        static let sentence = Layers(rawValue: 1 << 2)
        static let word = Layers(rawValue: 1 << 3)
        static let cluster = Layers(rawValue: 1 << 4)
        static let underline = Layers(rawValue: 1 << 5)
        /// All six layers (the branch).
        static let all: Layers = [.line, .block, .sentence, .word, .cluster, .underline]
        /// Sentence + word only (main — the branch is not stable yet).
        static let sentenceAndWord: Layers = [.sentence, .word]
    }

    /// The 6 layer colors, read live from Defaults (Manh 2026-11-27):
    /// user-customizable in Settings (Audio tab → Highlight colors).
    /// Computed (not stored) so a change applies at once — `draw` reads
    /// them every time, and the follow timer redraws every 0.3 s while
    /// showing. The opacity stays fixed here (fills 0.30, line +
    /// underline solid 1.0) — the picker never edits it. A malformed
    /// hex falls back to the layer's default color. `fileprivate` so
    /// the content view (same file) can draw with them.
    fileprivate static var wordFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightWordHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.wordDefaultHex)
    }
    fileprivate static var sentenceFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightSentenceHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.sentenceDefaultHex)
    }
    fileprivate static var blockFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightBlockHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.blockDefaultHex)
    }
    fileprivate static var clusterFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightClusterHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.clusterDefaultHex)
    }
    fileprivate static var lineFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightLineHex], alpha: HighlightColors.lineAlpha, fallbackHex: HighlightColors.lineDefaultHex)
    }
    /// Whether each layer is shown, read live from Defaults (Manh
    /// 2026-11-27): each layer has its own Show toggle in Settings
    /// (Audio tab → Highlight colors). Computed (not stored) so a
    /// toggle applies at once — `draw` reads them every time, and
    /// the follow timer redraws every 0.3 s while showing. A hidden
    /// layer is never drawn, even when its frame arrives.
    /// `fileprivate` so the content view (same file) can draw with
    /// them. On the branch the block defaults to hidden (Manh
    /// 2026-11-27 — the cluster is the broad fill now) and the other
    /// four default to shown.
    fileprivate static var isLineShown: Bool { Defaults[.highlightLineShown] }
    fileprivate static var isBlockShown: Bool { Defaults[.highlightBlockShown] }
    fileprivate static var isSentenceShown: Bool { Defaults[.highlightSentenceShown] }
    fileprivate static var isWordShown: Bool { Defaults[.highlightWordShown] }
    fileprivate static var isClusterShown: Bool { Defaults[.highlightClusterShown] }
    /// Which unit the vertical line's height follows (Manh 2026-11-27):
    /// the sentence being read, the paragraph (cluster) around it, or
    /// the whole block. Read live from Defaults so a picker change in
    /// Settings applies at once (the follow timer re-lays out every
    /// 0.3 s while showing). An unknown stored value falls back to the
    /// branch default (paragraph) instead of hiding the line.
    fileprivate static var lineFollows: HighlightColors.LineFollows {
        HighlightColors.LineFollows(rawValue: Defaults[.highlightLineFollows]) ?? .paragraph
    }
    /// Whether the highlight hides while the page scrolls (Manh
    /// 2026-11-27, trial plan phase 2): a Settings toggle in the
    /// Highlight colors section. Read live so flipping it applies at
    /// once (the next follow poll re-evaluates). Default ON on the
    /// branch — a lagging highlight reads as jerkiness.
    fileprivate static var isHideWhileScrolling: Bool { Defaults[.highlightHideWhileScrolling] }
    /// Whether the underline under the word + sentence is drawn (Manh
    /// 2026-11-27): the underline is the 6th layer, with its own Show
    /// toggle in its Highlight colors row. Read live so flipping it
    /// applies at once (the next draw shows or hides the underlines).
    /// Default ON — the underline reads better than the rectangle
    /// fills (no hard edges). Independent of the word/sentence Show
    /// toggles: the underline shows even when both fills are off, so
    /// the two styles can be compared.
    fileprivate static var isUnderlineShown: Bool { Defaults[.highlightUnderlineShown] }
    /// Thickness of the underline bar (points). Same idea as the
    /// vertical line: a thin solid bar reads as a line, not a box.
    /// Thinned from 2.5 to 1.5 (Manh 2026-11-27 — 2.5 pt read as too
    /// thick and ugly); 1.5 pt is the standard underline weight and
    /// sits in the same family as the 1.75 pt vertical line.
    fileprivate static let underlineThickness: CGFloat = 1.5
    /// Solid (opacity 1.0) version of the underline's own color, for
    /// the underline (Manh 2026-11-27): a translucent 1.5 pt bar would
    /// be too faint to read as a line, so the underline uses its color
    /// solid — like the vertical line, which is solid for the same
    /// reason. One color for both the word and the sentence underline
    /// (the underline is one layer, not two).
    fileprivate static var underlineSolid: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightUnderlineHex], alpha: HighlightColors.lineAlpha, fallbackHex: HighlightColors.underlineDefaultHex)
    }
    /// Width of the vertical line (points). Halved from 3.5 to 1.75
    /// (Manh 2026-11-27 — the line read as too thick); the 8 pt strip
    /// it sits in is unchanged, only the bar is thinner.
    fileprivate static let lineWidth: CGFloat = 1.75
    /// How far the window extends left of the block (points) so the
    /// line sits BESIDE the text instead of covering the first
    /// characters — the line lives in this strip, the fills start at
    /// the block's own left edge. Only when the line layer is on and
    /// shown; with sentence + word only, the window is exactly the
    /// block frame.
    private var leftPad: CGFloat { layers.contains(.line) && Self.isLineShown ? 8 : 0 }
    /// How often the block frame is re-read while showing (seconds) —
    /// the same interval as the hover follow poll, so the indicator
    /// moves with the text when the page scrolls.
    private static let followIntervalSec = 0.3

    /// The layers this overlay draws (set at init — main vs branch).
    private let layers: Layers
    private let panel: ReadingIndicatorPanel
    private let contentView: ReadingIndicatorView
    /// The block being marked (the controller's copy — the overlay owns
    /// the element for its follow poll).
    private var block: HoverBlock?
    /// Sentence/word/cluster frames in AX coordinates (absolute on
    /// screen), or nil when the level is not drawn. Stored in AX
    /// coordinates and converted to window-local at draw time, so a
    /// window move never needs the frames re-read — only the window
    /// frame changes.
    private var sentenceAXRect: CGRect?
    private var wordAXRect: CGRect?
    private var clusterAXRect: CGRect?
    /// Word/sentence frames for the underline (Manh 2026-11-27):
    /// stored WITHOUT the Show gate — the underline is independent of
    /// the fill toggles, so turning all fills off still shows the
    /// underline. Gated only on the layer being in `layers` (the
    /// branch has all six). Same AX coordinates as the fill rects
    /// above, converted at layout time.
    private var sentenceUnderlineAXRect: CGRect?
    private var wordUnderlineAXRect: CGRect?
    /// Hide-during-scroll state (Manh 2026-11-27, trial plan phase 2):
    /// the follow timer compares each poll's block frame with the
    /// previous one. `lastBlockScreenFrame` is the screen frame from
    /// the last poll; `stablePolls` counts consecutive polls with an
    /// (almost) unchanged frame; `isScrolling` is true while the
    /// highlight content is hidden for scrolling. No extra AX reads —
    /// the frame is the one the poll already read for repositioning.
    private var lastBlockScreenFrame: CGRect?
    private var stablePolls: Int = 0
    private var isScrolling: Bool = false
    /// The line strip's ACTUAL width this poll (points) — the desired
    /// `leftPad` (8 pt when the line layer is on) clamped so the strip
    /// never sticks out past the host window's visible left edge (see
    /// `reposition`, Manh 2026-11-27, 20:36 — the block may start right
    /// at the window edge, where the full strip would draw outside
    /// it). `layoutHighlightRects` uses this, not `leftPad`, so the
    /// block fill stays aligned with the text. Reset on hide.
    private var currentLeftPad: CGFloat = 0
    private var followTimer: Timer?

    init(layers: Layers = .all) {
        self.layers = layers
        contentView = ReadingIndicatorView(layers: layers)
        panel = ReadingIndicatorPanel()
        panel.contentView = contentView
        // A valid strip width before the first reposition (the overlay
        // is always repositioned in show() before anything is drawn,
        // so this is only a safety net).
        self.currentLeftPad = self.leftPad
    }

    /// Show the indicator for a block: position the window over the
    /// block's frame and start following it. The fills start empty
    /// (only the enabled static layers show) until `update` reports a
    /// sentence/word.
    func show(block: HoverBlock) {
        self.block = block
        sentenceAXRect = nil
        wordAXRect = nil
        clusterAXRect = nil
        sentenceUnderlineAXRect = nil
        wordUnderlineAXRect = nil
        // Fresh show: no scroll history yet — the highlight shows at
        // once (the first poll below establishes the baseline frame).
        lastBlockScreenFrame = nil
        stablePolls = 0
        isScrolling = false
        guard reposition() else {
            // The block is off-screen or its element is gone — nothing
            // to mark, so stay hidden instead of showing a stale box.
            hide()
            return
        }
        // The fills start empty (only the enabled static layers show)
        // until `update` reports a sentence/word — reposition already
        // laid them out from the (nil) AX rects.
        contentView.needsDisplay = true
        panel.orderFront(nil)
        startFollowing()
    }

    /// Update the sentence/word/cluster highlight frames (AX
    /// coordinates, or nil when that level has no frame). A nil level is
    /// simply not drawn — the other levels keep showing. A level whose
    /// layer is off or hidden is ignored (never drawn, even if a frame
    /// arrives).
    func update(wordFrame: CGRect?, sentenceFrame: CGRect?, clusterFrame: CGRect?) {
        sentenceAXRect = layers.contains(.sentence) && Self.isSentenceShown ? sentenceFrame : nil
        wordAXRect = layers.contains(.word) && Self.isWordShown ? wordFrame : nil
        clusterAXRect = layers.contains(.cluster) && Self.isClusterShown ? clusterFrame : nil
        // Underline frames (Manh 2026-11-27): stored WITHOUT the Show
        // gate — the underline is independent of the fill toggles, so
        // it shows even when the word/sentence fills are off. The
        // controller passes the frames ungated, so the only gate here
        // is the layer being in `layers`.
        sentenceUnderlineAXRect = layers.contains(.sentence) ? sentenceFrame : nil
        wordUnderlineAXRect = layers.contains(.word) ? wordFrame : nil
        layoutHighlightRects()
        contentView.needsDisplay = true
    }

    /// Hide the indicator and stop following. Idempotent.
    func hide() {
        followTimer?.invalidate()
        followTimer = nil
        block = nil
        sentenceAXRect = nil
        wordAXRect = nil
        clusterAXRect = nil
        sentenceUnderlineAXRect = nil
        wordUnderlineAXRect = nil
        lastBlockScreenFrame = nil
        stablePolls = 0
        isScrolling = false
        currentLeftPad = 0
        contentView.blockRect = nil
        contentView.wordRect = nil
        contentView.sentenceRect = nil
        contentView.clusterRect = nil
        contentView.lineRect = nil
        contentView.wordUnderlineRect = nil
        contentView.sentenceUnderlineRect = nil
        contentView.isScrollingHidden = false
        panel.orderOut(nil)
    }

    /// Re-read the block frame and move/resize the window to match it.
    /// Returns false when the block is gone or off-screen (the caller
    /// hides the overlay then). The sentence/word frames are absolute
    /// (AX coordinates), so they only need re-converting, not re-reading.
    /// This also tracks scrolling (see below): the window ALWAYS
    /// follows the frame, even while the highlight content is hidden.
    @discardableResult
    private func reposition() -> Bool {
        guard let block else { return false }
        guard let frame = HoverBlockText.frame(of: block.element) else { return false }
        guard let screenFrame = Self.appKitRect(fromAXRect: frame) else { return false }
        // Off-screen (scrolled out of view): hide instead of marking
        // a rectangle the user cannot see.
        guard let mainScreen = NSScreen.screens.first,
              screenFrame.intersects(mainScreen.frame) else { return false }
        // Clip to the visible area of the host app window (Manh
        // 2026-11-27, 20:36 — the block highlight overflowed outside
        // the app window): a long block's AX frame is the full rect of
        // its text, which can run past the window (scrolled content,
        // a paragraph taller than the view). The overlay window must
        // never extend past what the user can actually see of that
        // window, so intersect the block frame with the window's
        // visible area — the window's own frame (from AX) clipped to
        // the screen's visible frame (menu bar / Dock / the part
        // dragged off-screen). When the app does not expose its
        // window, fall back to the screen's visible frame alone. A
        // block with no visible part at all is hidden, like an
        // off-screen block. The scroll comparison below still uses
        // the RAW frame (the window may be resized without the page
        // scrolling) — only the window placement uses the clipped
        // frame.
        let clipFrame: CGRect
        if let windowAXFrame = HoverBlockText.windowFrame(of: block.element),
           let windowScreenFrame = Self.appKitRect(fromAXRect: windowAXFrame) {
            clipFrame = windowScreenFrame.intersection(mainScreen.visibleFrame)
        } else {
            clipFrame = mainScreen.visibleFrame
        }
        let visibleFrame = screenFrame.intersection(clipFrame)
        guard !visibleFrame.isEmpty else { return false }
        // Hide-during-scroll (Manh 2026-11-27, trial plan phase 2):
        // compare this poll's frame with the last one. A frame that
        // moved means the page is scrolling — hide the highlight
        // content (the window still follows below, so it is already in
        // the right place when the highlight comes back). Two stable
        // polls in a row (~0.6 s) mean the scroll stopped — show the
        // highlight again. The comparison tolerates 1 pt of AX jitter
        // so a still page is not mistaken for scrolling. No extra AX
        // reads: the frame is the one this poll already read. When the
        // toggle is off, the highlight never hides (the old
        // follow-only behaviour).
        if Self.isHideWhileScrolling {
            if let last = lastBlockScreenFrame {
                let moved = abs(screenFrame.minX - last.minX) > 1
                    || abs(screenFrame.minY - last.minY) > 1
                    || abs(screenFrame.width - last.width) > 1
                    || abs(screenFrame.height - last.height) > 1
                if moved {
                    isScrolling = true
                    stablePolls = 0
                } else {
                    stablePolls += 1
                    if stablePolls >= 2 { isScrolling = false }
                }
            }
            // First poll after show: no baseline yet — the highlight
            // shows (isScrolling is already false from show()).
        } else {
            isScrolling = false
            stablePolls = 0
        }
        lastBlockScreenFrame = screenFrame
        // The line strip extends left of the block; never let it leave
        // the visible host window (the block may start right at the
        // window edge, where the full 8 pt strip would stick out).
        // Clamp the strip to the room between the block's visible left
        // edge and the window's visible left edge — 0 when the block
        // starts at the edge (the line then sits on the text's edge).
        // The window is the VISIBLE block frame (see the clip above),
        // not the raw AX frame, so a long block never draws outside
        // the app window.
        currentLeftPad = min(leftPad, max(0, visibleFrame.minX - clipFrame.minX))
        let windowFrame = CGRect(
            x: visibleFrame.minX - currentLeftPad,
            y: visibleFrame.minY,
            width: visibleFrame.width + currentLeftPad,
            height: visibleFrame.height
        )
        panel.setFrame(windowFrame, display: true)
        layoutHighlightRects()
        return true
    }

    /// Convert the stored AX sentence/word/cluster frames to
    /// window-local rects for the content view. The block fill is always
    /// the window's own block area (the window minus the left line
    /// strip, or the whole window when there is no line strip). The
    /// line's vertical span follows the chosen unit (see `lineFollows`).
    /// Also passes the scrolling state to the view: while scrolling,
    /// `draw` skips the fills and the line (the rects are still laid
    /// out, so the highlight comes back in the right place).
    private func layoutHighlightRects() {
        let windowFrame = panel.frame
        contentView.isScrollingHidden = Self.isHideWhileScrolling && isScrolling
        // The block area in window-local coordinates: everything right
        // of the line strip (or the whole window when no line layer).
        // Uses the CLAMPED strip width (see `reposition`): when the
        // strip was narrowed at the window edge, the fill still starts
        // exactly at the text's visible left edge.
        contentView.blockRect = layers.contains(.block) && Self.isBlockShown ? CGRect(
            x: currentLeftPad,
            y: 0,
            width: max(0, panel.frame.width - currentLeftPad),
            height: panel.frame.height
        ) : nil
        contentView.sentenceRect = sentenceAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.wordRect = wordAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.clusterRect = clusterAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        // The vertical line lives in the left strip (x 0, width 1.75
        // pt) and its height follows the chosen unit (Manh 2026-11-27):
        // the sentence, the paragraph (cluster), or the whole block.
        // The window itself stays the block frame (the fills still need
        // it) — only the line's height changes. Fallback chain (Manh
        // 2026-11-27, revised 03:07): chosen unit → sentence → cluster.
        // The block is NOT a fallback — it is only the unit when the
        // picker is Block. If none of the three has a frame yet (no
        // word spoken, or the app hides range bounds), the line is not
        // drawn at all — losing the line is fine, the other highlights
        // still show. Duplicates are skipped: when the chosen unit
        // already is the sentence (or the cluster), it is tried once.
        // The span is clamped to the window so a partially scrolled
        // unit never draws the line outside it.
        let lineSpanRect: CGRect?
        switch Self.lineFollows {
        case .sentence:
            // The sentence, then the cluster around it.
            lineSpanRect = contentView.sentenceRect ?? contentView.clusterRect
        case .paragraph:
            // The cluster, then the sentence the voice is on.
            lineSpanRect = contentView.clusterRect ?? contentView.sentenceRect
        case .block:
            // The whole block — it IS the chosen unit here, not a
            // fallback, so no frame is needed.
            lineSpanRect = CGRect(x: 0, y: 0, width: panel.frame.width, height: panel.frame.height)
        }
        if let unit = lineSpanRect {
            let y = max(0, unit.minY)
            let height = max(0, min(unit.maxY, panel.frame.height) - y)
            contentView.lineRect = height > 0 ? CGRect(x: 0, y: y, width: Self.lineWidth, height: height) : nil
        } else {
            // No frame for any unit — no line this poll.
            contentView.lineRect = nil
        }
        // Underline rects (Manh 2026-11-27): a thin solid bar at the
        // bottom of the word/sentence frame, in the underline's own
        // color. Computed from the ungated AX frames above, so the
        // underline shows even when the fills are off. Nil when the
        // unit has no frame (the app hides range bounds) — no
        // underline that poll, the other marks still show. The `draw`
        // gate is the toggle, not these rects.
        contentView.wordUnderlineRect = Self.underlineRect(fromAXRect: wordUnderlineAXRect, windowFrame: windowFrame)
        contentView.sentenceUnderlineRect = Self.underlineRect(fromAXRect: sentenceUnderlineAXRect, windowFrame: windowFrame)
    }

    /// A thin underline rect at the bottom edge of a unit's frame
    /// (Manh 2026-11-27): the unit's window-local rect, reduced to a
    /// `underlineThickness` bar at its bottom (AppKit origin is
    /// bottom-left, so the bottom edge is `minY`). Clamped to the
    /// window so a partially scrolled unit never draws the underline
    /// outside it. Nil when the unit has no frame or is outside the
    /// window.
    private static func underlineRect(fromAXRect axRect: CGRect?, windowFrame: CGRect) -> CGRect? {
        guard let axRect, let local = windowLocalRect(fromAXRect: axRect, windowFrame: windowFrame) else { return nil }
        let y = max(0, local.minY)
        let height = max(0, min(underlineThickness, windowFrame.height - y))
        guard height > 0, local.width > 0 else { return nil }
        return CGRect(x: local.minX, y: y, width: local.width, height: height)
    }

    private func startFollowing() {
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: Self.followIntervalSec, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // The block scrolled away or vanished — hide instead of
                // marking a stale rectangle.
                guard let self, self.reposition() else {
                    self?.hide()
                    return
                }
                self.contentView.needsDisplay = true
            }
        }
    }

    /// AX coordinates (top-left origin) → AppKit screen coordinates
    /// (bottom-left origin). Same conversion as HoverTextDetector
    /// (primary screen height) — single-screen trial scope.
    static func appKitRect(fromAXRect axRect: CGRect) -> CGRect? {
        guard let screenHeight = NSScreen.screens.first?.frame.height else { return nil }
        return CGRect(
            x: axRect.minX,
            y: screenHeight - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )
    }

    /// An AX rect (absolute on screen) → window-local coordinates for
    /// drawing. Returns nil when the rect does not overlap the window
    /// (a highlight outside the block is never drawn).
    static func windowLocalRect(fromAXRect axRect: CGRect, windowFrame: CGRect) -> CGRect? {
        guard let screenRect = appKitRect(fromAXRect: axRect) else { return nil }
        let local = CGRect(
            x: screenRect.minX - windowFrame.minX,
            y: screenRect.minY - windowFrame.minY,
            width: screenRect.width,
            height: screenRect.height
        )
        guard local.intersects(CGRect(x: 0, y: 0, width: windowFrame.width, height: windowFrame.height)) else { return nil }
        return local
    }
}

// MARK: - ReadingIndicatorPanel

/// The floating window for the reading indicator — same pattern as
/// `TriggerIconPanel`: borderless, non-activating, floating, never key,
/// so it can sit over another app's window without stealing focus or
/// clicks. Mouse events are ignored (clicks pass through to the page).
private final class ReadingIndicatorPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        isReleasedWhenClosed = false
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
}

// MARK: - ReadingIndicatorView

/// Draws the enabled indicator levels (block fill, cluster fill,
/// sentence fill, word fill, vertical line) in window-local
/// coordinates. Any level with a nil rect is simply not drawn — a
/// missing frame never blanks the other levels. A layer that is off
/// is never drawn. The sixth layer is an underline under the word +
/// sentence (Manh 2026-11-27) — a thin solid bar instead of a
/// rectangle fill, in its own color.
private final class ReadingIndicatorView: NSView {
    /// The layers this view draws (same set as the overlay).
    private let layers: ReadingIndicatorOverlay.Layers
    var blockRect: CGRect?
    var sentenceRect: CGRect?
    var wordRect: CGRect?
    var clusterRect: CGRect?
    /// The underline rects under the word/sentence (set by
    /// `layoutHighlightRects` from the ungated AX frames — their
    /// bottom edges, 1.5 pt tall). Nil means no underline this poll
    /// (no frame for that unit). Drawn only when the underline
    /// toggle is on; independent of the fill toggles.
    var wordUnderlineRect: CGRect?
    var sentenceUnderlineRect: CGRect?
    /// The vertical line's rect in the left strip (set by
    /// `layoutHighlightRects` — its height follows the chosen unit).
    /// Nil means no line this poll (no unit had a frame — the line is
    /// simply not drawn, the other highlights still show).
    var lineRect: CGRect?
    /// Hide-during-scroll flag (set by the overlay in
    /// `layoutHighlightRects`): while true, `draw` paints nothing —
    /// the fills and the line would lag behind the scrolling text.
    var isScrollingHidden: Bool = false

    init(layers: ReadingIndicatorOverlay.Layers) {
        self.layers = layers
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Hide-during-scroll (Manh 2026-11-27, trial plan phase 2):
        // while the page is scrolling, draw nothing — the fills and
        // the line would lag behind the text and read as jerkiness.
        // The window still follows (reposition runs every poll), so
        // the highlight comes back in the right place when the scroll
        // stops and the flag clears.
        guard !isScrollingHidden else { return }
        // Bottom to top: the broadest level first, so a narrower level
        // (cluster, then sentence, then word) reads as a stronger mark
        // inside it. The fills are translucent, so overlapping levels
        // blend instead of hiding each other.
        if layers.contains(.block), ReadingIndicatorOverlay.isBlockShown, let blockRect {
            ReadingIndicatorOverlay.blockFill.setFill()
            NSBezierPath(rect: blockRect).fill()
        }
        if layers.contains(.cluster), ReadingIndicatorOverlay.isClusterShown, let clusterRect {
            ReadingIndicatorOverlay.clusterFill.setFill()
            NSBezierPath(rect: clusterRect).fill()
        }
        if layers.contains(.sentence), ReadingIndicatorOverlay.isSentenceShown, let sentenceRect {
            ReadingIndicatorOverlay.sentenceFill.setFill()
            NSBezierPath(rect: sentenceRect).fill()
        }
        if layers.contains(.word), ReadingIndicatorOverlay.isWordShown, let wordRect {
            ReadingIndicatorOverlay.wordFill.setFill()
            NSBezierPath(rect: wordRect).fill()
        }
        // The vertical line: a solid bar in the strip left of the text.
        // Its height follows the chosen unit (sentence / paragraph /
        // block — see `layoutHighlightRects`). A nil rect means no unit
        // had a frame this poll, so the line is not drawn at all (the
        // other highlights still show). Only when the line layer is on
        // and shown.
        if layers.contains(.line), ReadingIndicatorOverlay.isLineShown, let lineRect {
            ReadingIndicatorOverlay.lineFill.setFill()
            NSBezierPath(rect: lineRect).fill()
        }
        // The underline (Manh 2026-11-27): a thin solid bar at the
        // bottom of the sentence + word frames, in the underline's own
        // color (one color for both). Only when the underline layer is
        // in `layers` and its Show toggle is on — and NOT gated on the
        // fill toggles, so turning all fills off still shows the
        // underline (a line under the text instead of a rectangle
        // around it, whose hard edges read as a border). A nil rect
        // means that unit had no frame this poll. The scroll guard at
        // the top already hides the underline while scrolling, with
        // the fills + line.
        if layers.contains(.underline), ReadingIndicatorOverlay.isUnderlineShown {
            if layers.contains(.sentence), let sentenceUnderlineRect {
                ReadingIndicatorOverlay.underlineSolid.setFill()
                NSBezierPath(rect: sentenceUnderlineRect).fill()
            }
            if layers.contains(.word), let wordUnderlineRect {
                ReadingIndicatorOverlay.underlineSolid.setFill()
                NSBezierPath(rect: wordUnderlineRect).fill()
            }
        }
    }
}
