import AppKit
import Defaults
import Foundation

// MARK: - ReadingIndicatorOverlay

/// Step 2 — reading indicator (Manh 2026-11-24): a floating overlay that
/// marks the block being read on the page itself — a vertical line at
/// the block's left edge plus translucent highlights for the block,
/// the paragraph (cluster) around the sentence, the sentence and (when
/// the app exposes range bounds) the word.
/// It draws OVER another app's window without touching that app: the
/// window ignores mouse events (clicks pass through) and never becomes
/// key, so reading along never steals input from the page.
/// Follow-ONLY in this build (phase 1): a 0.3 s timer re-reads the
/// block frame and repositions the window. The hide-during-scroll
/// behaviour (Manh 2026-11-27, phase 2 of the trial plan — built now
/// that scrolling jerkiness is confirmed) hides the highlight while
/// the block moves and shows it again after 2 stable polls; it is
/// behind the "Hide highlights while scrolling" toggle in Settings
/// (default on) and needs no extra AX reads — it reuses the frame the
/// follow poll already read.
/// Which layers are drawn is user-configurable (Manh 2026-11-27): the
/// overlay is created with all five layers, and each layer has its own
/// Show toggle in Settings (Audio tab → Highlight colors) — the
/// toggles decide what actually shows (see `isShown`). The vertical
/// line's length is configurable too (Manh 2026-11-27): it can follow
/// the sentence, the paragraph (cluster) or the whole block (see
/// `LineFollows`). One file, one component — the layers are a setting,
/// not a fork.
@MainActor
final class ReadingIndicatorOverlay {
    /// Which indicator layers to draw. The creation set — the
    /// per-layer Show toggles in Settings filter it further (see
    /// `isShown`): a layer draws only when it is in this set AND its
    /// toggle is on. Main creates the overlay with `.all` and the
    /// toggles decide (main defaults: only the word on).
    struct Layers: OptionSet {
        let rawValue: Int
        static let line = Layers(rawValue: 1 << 0)
        static let block = Layers(rawValue: 1 << 1)
        static let sentence = Layers(rawValue: 1 << 2)
        static let word = Layers(rawValue: 1 << 3)
        /// The paragraph (cluster) around the sentence being read —
        /// the group of sentences with no blank line between them
        /// (Manh 2026-11-27).
        static let cluster = Layers(rawValue: 1 << 4)
        /// All five layers.
        static let all: Layers = [.line, .block, .sentence, .word, .cluster]
        /// Sentence + word only (kept for callers that want it).
        static let sentenceAndWord: Layers = [.sentence, .word]
    }

    /// Which unit the vertical line follows (Manh 2026-11-27): the
    /// sentence being read, the paragraph (cluster) around it, or the
    /// whole block. Stored in Defaults as a String; an unknown stored
    /// value falls back to `.sentence` (the main default), so a
    /// hand-edited default can never leave the line without a unit.
    enum LineFollows: String {
        case sentence
        case paragraph
        case block
    }

    /// The line's current unit, read live from Defaults (not cached)
    /// so changing the picker in Settings applies at once — the
    /// follow timer redraws every 0.3 s while showing.
    fileprivate static var lineFollows: LineFollows {
        LineFollows(rawValue: Defaults[.highlightLineFollows]) ?? .sentence
    }

    /// Whether the highlight hides while the page scrolls, read live
    /// from Defaults (not cached) so flipping the toggle in Settings
    /// applies at once. Default on (Manh 2026-11-27).
    fileprivate static var hideWhileScrolling: Bool {
        Defaults[.highlightHideWhileScrolling]
    }

    /// Whether a layer draws: it must be in the creation set AND its
    /// Settings Show toggle must be on (Manh 2026-11-27). The toggles
    /// are read live (not cached) so flipping one applies at once —
    /// the follow timer redraws every 0.3 s while showing, and
    /// `update` re-lays out on the next word. `fileprivate` so the
    /// content view (same file) can draw with it.
    fileprivate static func isShown(_ layer: Layers, in layers: Layers) -> Bool {
        guard layers.contains(layer) else { return false }
        if layer == .line { return Defaults[.highlightLineShown] }
        if layer == .block { return Defaults[.highlightBlockShown] }
        if layer == .sentence { return Defaults[.highlightSentenceShown] }
        if layer == .word { return Defaults[.highlightWordShown] }
        if layer == .cluster { return Defaults[.highlightClusterShown] }
        return false
    }

    /// The 5 layer colors, read live from Defaults (Manh 2026-11-27):
    /// user-customizable in Settings (Audio tab → Highlight colors).
    /// Computed (not stored) so a change applies at once — `draw` reads
    /// them every time, and the follow timer redraws every 0.3 s while
    /// showing. The opacity stays fixed here (fills 0.30, line solid
    /// 1.0) — the picker never edits it. A malformed hex falls back to
    /// the layer's default color. `fileprivate` so the content view
    /// (same file) can draw with them.
    fileprivate static var wordFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightWordHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.wordDefaultHex)
    }
    fileprivate static var sentenceFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightSentenceHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.sentenceDefaultHex)
    }
    fileprivate static var blockFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightBlockHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.blockDefaultHex)
    }
    fileprivate static var lineFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightLineHex], alpha: HighlightColors.lineAlpha, fallbackHex: HighlightColors.lineDefaultHex)
    }
    fileprivate static var clusterFill: NSColor {
        HighlightColors.nsColor(hex: Defaults[.highlightClusterHex], alpha: HighlightColors.fillAlpha, fallbackHex: HighlightColors.clusterDefaultHex)
    }
    /// Width of the vertical line (points).
    fileprivate static let lineWidth: CGFloat = 3.5
    /// How far the window extends left of the block (points) so the
    /// line sits BESIDE the text instead of covering the first
    /// characters — the line lives in this strip, the fills start at
    /// the block's own left edge. Only when the line layer is shown
    /// (creation set + its Settings toggle); otherwise the window is
    /// exactly the block frame. Read live so toggling the line applies
    /// at once (the follow timer repositions every 0.3 s).
    private var leftPad: CGFloat { Self.isShown(.line, in: layers) ? 8 : 0 }
    /// How often the block frame is re-read while showing (seconds) —
    /// the same interval as the hover follow poll, so the indicator
    /// moves with the text when the page scrolls.
    private static let followIntervalSec = 0.3

    /// The layers this overlay draws (the creation set — the Settings
    /// Show toggles filter it further, see `isShown`).
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
    /// Hide-during-scroll state (Manh 2026-11-27): the follow timer
    /// compares the block frame it just read with the previous poll's
    /// frame — a move means the page is scrolling, so the highlight
    /// hides until the frame stands still for 2 polls (~0.6 s). The
    /// window keeps following (repositioning) while hidden, so the
    /// highlight reappears in the right place. No extra AX reads: the
    /// comparison reuses the frame `reposition` already read.
    private var currentBlockScreenFrame: CGRect?
    private var previousBlockScreenFrame: CGRect?
    /// Consecutive polls whose frame did not move (see above).
    private var stablePolls: Int = 0
    /// Whether the highlight is currently hidden for scrolling (the
    /// content view reads this to skip drawing; the window still
    /// follows).
    private var hideForScroll: Bool = false
    private var followTimer: Timer?

    init(layers: Layers = .all) {
        self.layers = layers
        contentView = ReadingIndicatorView(layers: layers)
        panel = ReadingIndicatorPanel()
        panel.contentView = contentView
    }

    /// Show the indicator for a block: position the window over the
    /// block's frame and start following it. The fills start empty
    /// (only the enabled static layers show) until `update` reports a
    /// sentence/word/cluster.
    func show(block: HoverBlock) {
        self.block = block
        sentenceAXRect = nil
        wordAXRect = nil
        clusterAXRect = nil
        guard reposition() else {
            // The block is off-screen or its element is gone — nothing
            // to mark, so stay hidden instead of showing a stale box.
            hide()
            return
        }
        // First poll compares against the frame at show time, so a
        // scroll that starts right after show still hides the
        // highlight; a still page counts as stable from the start.
        previousBlockScreenFrame = currentBlockScreenFrame
        stablePolls = 0
        hideForScroll = false
        contentView.hideForScroll = false
        // The fills start empty (only the enabled static layers show)
        // until `update` reports a sentence/word/cluster — reposition
        // already laid them out from the (nil) AX rects.
        contentView.needsDisplay = true
        panel.orderFront(nil)
        startFollowing()
    }

    /// Update the sentence/word/cluster highlight frames (AX
    /// coordinates, or nil when that level has no frame). A nil level
    /// is simply not drawn — the other levels keep showing. The frames
    /// are stored as they arrive (NOT gated here): the fills are gated
    /// in `layoutHighlightRects`, but the line needs its unit's frame
    /// even when that unit's fill is hidden — a line following the
    /// sentence must still track the sentence when the sentence fill
    /// is off. The line's length follows the chosen unit (see
    /// `lineFollows`) and is re-laid out here too, so it moves with
    /// the voice on the next word.
    func update(wordFrame: CGRect?, sentenceFrame: CGRect?, clusterFrame: CGRect?) {
        sentenceAXRect = sentenceFrame
        wordAXRect = wordFrame
        clusterAXRect = clusterFrame
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
        currentBlockScreenFrame = nil
        previousBlockScreenFrame = nil
        stablePolls = 0
        hideForScroll = false
        contentView.blockRect = nil
        contentView.wordRect = nil
        contentView.sentenceRect = nil
        contentView.clusterRect = nil
        contentView.lineRect = nil
        contentView.hideForScroll = false
        panel.orderOut(nil)
    }

    /// Re-read the block frame and move/resize the window to match it.
    /// Returns false when the block is gone or off-screen (the caller
    /// hides the overlay then). The sentence/word/cluster frames are
    /// absolute (AX coordinates), so they only need re-converting,
    /// not re-reading.
    @discardableResult
    private func reposition() -> Bool {
        guard let block else { return false }
        guard let frame = HoverBlockText.frame(of: block.element) else { return false }
        guard let screenFrame = Self.appKitRect(fromAXRect: frame) else { return false }
        // Remember the frame just read — the follow timer compares it
        // with the previous poll's frame to tell scrolling from still
        // (see `hideForScroll`).
        currentBlockScreenFrame = screenFrame
        // Off-screen (scrolled out of view): hide instead of marking
        // a rectangle the user cannot see.
        guard let mainScreen = NSScreen.screens.first,
              screenFrame.intersects(mainScreen.frame) else { return false }
        // The window extends left of the block so the line sits beside
        // the text (see leftPad); without the line layer the window is
        // exactly the block frame.
        let windowFrame = CGRect(
            x: screenFrame.minX - leftPad,
            y: screenFrame.minY,
            width: screenFrame.width + leftPad,
            height: screenFrame.height
        )
        panel.setFrame(windowFrame, display: true)
        layoutHighlightRects()
        return true
    }

    /// Convert the stored AX sentence/word/cluster frames to
    /// window-local rects for the content view. The block fill is always
    /// the window's own block area (the window minus the left line
    /// strip, or the whole window when there is no line strip).
    private func layoutHighlightRects() {
        let windowFrame = panel.frame
        // The block area in window-local coordinates: everything right
        // of the line strip (or the whole window when no line layer).
        contentView.blockRect = Self.isShown(.block, in: layers) ? CGRect(
            x: leftPad,
            y: 0,
            width: max(0, panel.frame.width - leftPad),
            height: panel.frame.height
        ) : nil
        // Window-local rects for the sentence/cluster (ungated — the
        // line needs them even when their fill is hidden; the fills are
        // gated below).
        let sentenceLocal = sentenceAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        let clusterLocal = clusterAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.sentenceRect = Self.isShown(.sentence, in: layers) ? sentenceLocal : nil
        contentView.wordRect = Self.isShown(.word, in: layers) ? wordAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) } : nil
        contentView.clusterRect = Self.isShown(.cluster, in: layers) ? clusterLocal : nil
        // The line's vertical span (Manh 2026-11-27 03:07): the chosen
        // unit's rect, falling back down the chain chosen unit →
        // sentence → cluster. The block is NOT a fallback — it is only
        // a chosen unit (picker = Block), whose frame is the window
        // itself. When no unit has a frame there is no line at all —
        // losing the line is fine, the fills still mark the text.
        // Clamped to the window so a frame sticking out (rounding, a
        // unit taller than the block) never draws outside the window.
        let unitRect: CGRect?
        switch Self.lineFollows {
        case .sentence: unitRect = sentenceLocal ?? clusterLocal
        case .paragraph: unitRect = clusterLocal ?? sentenceLocal
        case .block: unitRect = nil
        }
        let lineHeight = panel.frame.height
        let lineRect: CGRect?
        if let unitRect, unitRect.height > 0 {
            let lineY = min(max(unitRect.minY, 0), lineHeight)
            let lineSpan = min(max(unitRect.maxY, lineY) - lineY, lineHeight - lineY)
            lineRect = CGRect(x: 0, y: lineY, width: Self.lineWidth, height: max(0, lineSpan))
        } else if Self.lineFollows == .block {
            // The block is the chosen unit: full height, always available.
            lineRect = CGRect(x: 0, y: 0, width: Self.lineWidth, height: lineHeight)
        } else {
            // No unit has a frame — no line (the fills still show).
            lineRect = nil
        }
        contentView.lineRect = Self.isShown(.line, in: layers) ? lineRect : nil
        contentView.hideForScroll = hideForScroll
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
                // Hide-during-scroll (Manh 2026-11-27): when the toggle
                // is on, a frame that moved since the last poll means
                // the page is scrolling — hide the highlight (the
                // window still follows, so it reappears in the right
                // place). It takes 2 still polls (~0.6 s) to show
                // again, so a brief pause mid-scroll does not flash
                // the highlight back. Toggle off = the old follow-only
                // behaviour (the highlight stays, and may jerk).
                if Self.hideWhileScrolling {
                    if let prev = self.previousBlockScreenFrame,
                       let cur = self.currentBlockScreenFrame {
                        if Self.frameMoved(prev, cur) {
                            self.stablePolls = 0
                            self.hideForScroll = true
                        } else {
                            self.stablePolls += 1
                            if self.stablePolls >= 2 { self.hideForScroll = false }
                        }
                    } else {
                        // No previous frame (first poll after show) —
                        // not scrolling.
                        self.stablePolls = 0
                        self.hideForScroll = false
                    }
                    self.previousBlockScreenFrame = self.currentBlockScreenFrame
                } else {
                    self.stablePolls = 0
                    self.hideForScroll = false
                    self.previousBlockScreenFrame = self.currentBlockScreenFrame
                }
                self.contentView.hideForScroll = self.hideForScroll
                self.contentView.needsDisplay = true
            }
        }
    }

    /// Whether two block frames count as "moved" (scrolling): any edge
    /// moved by more than half a point. Exact equality would flicker
    /// on sub-pixel AX rounding; half a point is far below a visible
    /// move, so a real scroll always counts and a still page never does.
    private static func frameMoved(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) > 0.5 || abs(a.minY - b.minY) > 0.5 ||
        abs(a.width - b.width) > 0.5 || abs(a.height - b.height) > 0.5
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
/// is never drawn.
private final class ReadingIndicatorView: NSView {
    /// The layers this view draws (same set as the overlay).
    private let layers: ReadingIndicatorOverlay.Layers
    var blockRect: CGRect?
    var sentenceRect: CGRect?
    var wordRect: CGRect?
    var clusterRect: CGRect?
    /// The vertical line's rect (in the 8 pt strip at the window's
    /// left edge): its height follows the chosen unit (sentence /
    /// cluster / block, see `LineFollows`), full window height when
    /// the unit is the block. Nil when the line layer is off, or when
    /// no unit has a frame (the line is then not drawn at all).
    var lineRect: CGRect?
    /// Hide-during-scroll (Manh 2026-11-27): while the page scrolls
    /// the highlight is hidden — the window still follows, so it
    /// reappears in the right place when the text stops. Set by the
    /// overlay; `draw` skips everything while it is true.
    var hideForScroll: Bool = false

    init(layers: ReadingIndicatorOverlay.Layers) {
        self.layers = layers
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Hide-during-scroll (Manh 2026-11-27): while the page scrolls
        // the highlight is hidden — the window still follows, so it
        // reappears in the right place when the text stops. A moving
        // highlight reads as jerk; a hidden one does not.
        guard !hideForScroll else { return }
        // Bottom to top: the broadest level first, so a narrower level
        // (cluster, then sentence, then word) reads as a stronger mark
        // inside it. The fills are translucent, so overlapping levels
        // blend instead of hiding each other.
        if ReadingIndicatorOverlay.isShown(.block, in: layers), let blockRect {
            ReadingIndicatorOverlay.blockFill.setFill()
            NSBezierPath(rect: blockRect).fill()
        }
        if ReadingIndicatorOverlay.isShown(.cluster, in: layers), let clusterRect {
            ReadingIndicatorOverlay.clusterFill.setFill()
            NSBezierPath(rect: clusterRect).fill()
        }
        if ReadingIndicatorOverlay.isShown(.sentence, in: layers), let sentenceRect {
            ReadingIndicatorOverlay.sentenceFill.setFill()
            NSBezierPath(rect: sentenceRect).fill()
        }
        if ReadingIndicatorOverlay.isShown(.word, in: layers), let wordRect {
            ReadingIndicatorOverlay.wordFill.setFill()
            NSBezierPath(rect: wordRect).fill()
        }
        // The vertical line: a solid bar in the strip left of the
        // block text, as tall as the unit it follows (sentence /
        // cluster / block — see `layoutHighlightRects`), so the eye
        // finds the unit being read at a glance even when the fills
        // are faint. Only when the line layer is shown (creation set
        // + its toggle).
        if ReadingIndicatorOverlay.isShown(.line, in: layers), let lineRect {
            ReadingIndicatorOverlay.lineFill.setFill()
            NSBezierPath(rect: lineRect).fill()
        }
    }
}
