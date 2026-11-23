import AppKit
import Foundation

// MARK: - ReadingIndicatorOverlay

/// Step 2 — reading indicator (Manh 2026-11-24): a floating overlay that
/// marks the block being read on the page itself — a vertical line at
/// the block's left edge plus translucent highlights for the block,
/// the sentence and (when the app exposes range bounds) the word.
/// It draws OVER another app's window without touching that app: the
/// window ignores mouse events (clicks pass through) and never becomes
/// key, so reading along never steals input from the page.
/// Follow-ONLY in this build (phase 1): a 0.3 s timer re-reads the
/// block frame and repositions the window. The hide-during-scroll /
/// show-when-stopped fallback is phase 2 — only if testing shows
/// jerkiness (see the trial plan).
@MainActor
final class ReadingIndicatorOverlay {
    /// Trial colors (Manh 2026-11-24 00:38, pastel palette). Fills are
    /// translucent (~30%) so the text underneath stays readable; the
    /// line is solid so it reads as a marker, not a tint.
    /// `fileprivate` so the content view (same file) can draw with them.
    fileprivate static let wordFill = NSColor(red: 0.85, green: 0.75, blue: 0.98, alpha: 0.30) // tím nhạt
    fileprivate static let sentenceFill = NSColor(red: 1.0, green: 0.95, blue: 0.65, alpha: 0.30) // vàng nhạt
    fileprivate static let blockFill = NSColor(red: 0.75, green: 0.95, blue: 0.70, alpha: 0.30) // green nhạt
    fileprivate static let lineFill = NSColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0) // blue nhạt, đặc
    /// Width of the vertical line (points).
    fileprivate static let lineWidth: CGFloat = 3.5
    /// How far the window extends left of the block (points) so the
    /// line sits BESIDE the text instead of covering the first
    /// characters — the line lives in this strip, the fills start at
    /// the block's own left edge.
    private static let leftPad: CGFloat = 8
    /// How often the block frame is re-read while showing (seconds) —
    /// the same interval as the hover follow poll, so the indicator
    /// moves with the text when the page scrolls.
    private static let followIntervalSec = 0.3

    private let panel: ReadingIndicatorPanel
    private let contentView: ReadingIndicatorView
    /// The block being marked (the controller's copy — the overlay owns
    /// the element for its follow poll).
    private var block: HoverBlock?
    /// Sentence/word frames in AX coordinates (absolute on screen), or
    /// nil when the level is not drawn. Stored in AX coordinates and
    /// converted to window-local at draw time, so a window move never
    /// needs the frames re-read — only the window frame changes.
    private var sentenceAXRect: CGRect?
    private var wordAXRect: CGRect?
    private var followTimer: Timer?

    init() {
        contentView = ReadingIndicatorView()
        panel = ReadingIndicatorPanel()
        panel.contentView = contentView
    }

    /// Show the indicator for a block: position the window over the
    /// block's frame and start following it. The fills start empty
    /// (block + line only) until `update` reports a sentence/word.
    func show(block: HoverBlock) {
        self.block = block
        sentenceAXRect = nil
        wordAXRect = nil
        guard reposition() else {
            // The block is off-screen or its element is gone — nothing
            // to mark, so stay hidden instead of showing a stale box.
            hide()
            return
        }
        // The fills start empty (block + line only) until `update`
        // reports a sentence/word — reposition already laid them out
        // from the (nil) AX rects.
        contentView.needsDisplay = true
        panel.orderFront(nil)
        startFollowing()
    }

    /// Update the sentence/word highlight frames (AX coordinates, or
    /// nil when that level has no frame). A nil level is simply not
    /// drawn — the block + line keep showing.
    func update(wordFrame: CGRect?, sentenceFrame: CGRect?) {
        sentenceAXRect = sentenceFrame
        wordAXRect = wordFrame
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
        contentView.blockRect = nil
        contentView.wordRect = nil
        contentView.sentenceRect = nil
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
        // the text (see leftPad); its origin is the block's left edge
        // minus that strip.
        let windowFrame = CGRect(
            x: screenFrame.minX - Self.leftPad,
            y: screenFrame.minY,
            width: screenFrame.width + Self.leftPad,
            height: screenFrame.height
        )
        panel.setFrame(windowFrame, display: true)
        layoutHighlightRects()
        return true
    }

    /// Convert the stored AX sentence/word frames to window-local rects
    /// for the content view. The block fill is always the window's own
    /// block area (the window minus the left line strip).
    private func layoutHighlightRects() {
        let windowFrame = panel.frame
        // The block area in window-local coordinates: everything right
        // of the line strip.
        contentView.blockRect = CGRect(
            x: Self.leftPad,
            y: 0,
            width: max(0, panel.frame.width - Self.leftPad),
            height: panel.frame.height
        )
        contentView.sentenceRect = sentenceAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
        contentView.wordRect = wordAXRect.flatMap { Self.windowLocalRect(fromAXRect: $0, windowFrame: windowFrame) }
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

/// Draws the four indicator levels (block fill, sentence fill, word
/// fill, vertical line) in window-local coordinates. Any level with a
/// nil rect is simply not drawn — a missing frame never blanks the
/// other levels.
private final class ReadingIndicatorView: NSView {
    var blockRect: CGRect?
    var sentenceRect: CGRect?
    var wordRect: CGRect?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Bottom to top: the broadest level first, so a narrower level
        // (sentence, then word) reads as a stronger mark inside it.
        // The fills are translucent, so overlapping levels blend
        // instead of hiding each other.
        if let blockRect {
            ReadingIndicatorOverlay.blockFill.setFill()
            NSBezierPath(rect: blockRect).fill()
        }
        if let sentenceRect {
            ReadingIndicatorOverlay.sentenceFill.setFill()
            NSBezierPath(rect: sentenceRect).fill()
        }
        if let wordRect {
            ReadingIndicatorOverlay.wordFill.setFill()
            NSBezierPath(rect: wordRect).fill()
        }
        // The vertical line: a solid bar at the window's left edge (the
        // strip left of the block text), full height, so the eye finds
        // the block being read at a glance even when the fills are faint.
        ReadingIndicatorOverlay.lineFill.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: ReadingIndicatorOverlay.lineWidth, height: bounds.height)).fill()
    }
}
