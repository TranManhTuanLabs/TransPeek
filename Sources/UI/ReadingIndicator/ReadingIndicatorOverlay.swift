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
/// block frame and repositions the window. The hide-during-scroll /
/// show-when-stopped fallback is phase 2 — only if testing shows
/// jerkiness (see the trial plan).
/// Which layers are drawn is configurable (Manh 2026-11-26): main
/// draws ONLY sentence + word (the branch is not stable yet, so the
/// line + block stay on the branch); the branch draws all five. One
/// file, one component — the layers are a setting, not a fork. Each
/// layer also has its own Show toggle in Settings (Manh 2026-11-27):
/// a hidden layer is never drawn, on either side.
@MainActor
final class ReadingIndicatorOverlay {
    /// Which indicator layers to draw. Main = sentence + word only;
    /// the branch = all five (line + block + cluster + sentence + word).
    struct Layers: OptionSet {
        let rawValue: Int
        static let line = Layers(rawValue: 1 << 0)
        static let block = Layers(rawValue: 1 << 1)
        static let sentence = Layers(rawValue: 1 << 2)
        static let word = Layers(rawValue: 1 << 3)
        static let cluster = Layers(rawValue: 1 << 4)
        /// All five layers (the branch).
        static let all: Layers = [.line, .block, .sentence, .word, .cluster]
        /// Sentence + word only (main — the branch is not stable yet).
        static let sentenceAndWord: Layers = [.sentence, .word]
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
    /// Width of the vertical line (points).
    fileprivate static let lineWidth: CGFloat = 3.5
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
    /// sentence/word.
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
        contentView.blockRect = nil
        contentView.wordRect = nil
        contentView.sentenceRect = nil
        contentView.clusterRect = nil
        panel.orderOut(nil)
    }

    /// Re-read the block frame and move/resize the window to match it.
    /// Returns false when the block is gone or off-screen (the caller
    /// hides the overlay then). The sentence/word frames are absolute
    /// (AX coordinates), so they only need re-converting, not re-reading.
    @discardableResult
    private func reposition() -> Bool {
        guard let block else { return false }
        guard let frame = HoverBlockText.frame(of: block.element) else { return false }
        guard let screenFrame = Self.appKitRect(fromAXRect: frame) else { return false }
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
    /// strip, or the whole window when there is no line strip). The
    /// line's vertical span follows the chosen unit (see `lineFollows`).
    private func layoutHighlightRects() {
        let windowFrame = panel.frame
        // The block area in window-local coordinates: everything right
        // of the line strip (or the whole window when no line layer).
        contentView.blockRect = layers.contains(.block) && Self.isBlockShown ? CGRect(
            x: leftPad,
            y: 0,
            width: max(0, panel.frame.width - leftPad),
            height: panel.frame.height
        ) : nil
        contentView.sentenceRect = sentenceAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.wordRect = wordAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.clusterRect = clusterAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        // The vertical line lives in the left strip (x 0, width 3.5 pt)
        // and its height follows the chosen unit (Manh 2026-11-27):
        // the sentence, the paragraph (cluster), or the whole block.
        // The window itself stays the block frame (the fills still need
        // it) — only the line's height changes. A unit with no frame
        // yet (no word spoken, or the app hides range bounds) falls
        // back to the full block height, so the line is never lost.
        // The span is clamped to the window so a partially scrolled
        // unit never draws the line outside it.
        let lineUnitRect: CGRect?
        switch Self.lineFollows {
        case .sentence: lineUnitRect = contentView.sentenceRect
        case .paragraph: lineUnitRect = contentView.clusterRect
        case .block: lineUnitRect = nil
        }
        if let unit = lineUnitRect {
            let y = max(0, unit.minY)
            let height = max(0, min(unit.maxY, panel.frame.height) - y)
            contentView.lineRect = CGRect(x: 0, y: y, width: Self.lineWidth, height: height)
        } else {
            contentView.lineRect = CGRect(x: 0, y: 0, width: Self.lineWidth, height: panel.frame.height)
        }
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
/// is never drawn.
private final class ReadingIndicatorView: NSView {
    /// The layers this view draws (same set as the overlay).
    private let layers: ReadingIndicatorOverlay.Layers
    var blockRect: CGRect?
    var sentenceRect: CGRect?
    var wordRect: CGRect?
    var clusterRect: CGRect?
    /// The vertical line's rect in the left strip (set by
    /// `layoutHighlightRects` — its height follows the chosen unit).
    var lineRect: CGRect = .zero

    init(layers: ReadingIndicatorOverlay.Layers) {
        self.layers = layers
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
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
        // block — see `layoutHighlightRects`); a zero-height rect (no
        // layout yet) falls back to the full window height, so the eye
        // finds the block being read at a glance even when the fills
        // are faint. Only when the line layer is on and shown.
        if layers.contains(.line), ReadingIndicatorOverlay.isLineShown {
            ReadingIndicatorOverlay.lineFill.setFill()
            let rect = lineRect.height > 0 ? lineRect : CGRect(x: 0, y: 0, width: ReadingIndicatorOverlay.lineWidth, height: bounds.height)
            NSBezierPath(rect: rect).fill()
        }
    }
}
