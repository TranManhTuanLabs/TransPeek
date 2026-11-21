import AppKit
import Defaults

/// A tiny floating panel that hosts the trigger icon near the cursor.
final class TriggerIconPanel: NSPanel {
    /// Full size for the selection icon — user-adjustable in Settings
    /// (Manh 2026-11-21), default 26pt. Read live at each show, so a
    /// Settings change applies to the next icon that appears.
    static var size: CGFloat { CGFloat(Defaults[.floatIconSize]) }
    /// Compact size for the block-text hover icon (Manh 2026-11-21):
    /// the hover icon appears often (every text block), so it is smaller
    /// than the selection icon — less in the way of the mouse and the
    /// text, still easy to see and click. User-adjustable in Settings,
    /// default 24pt. The glyphs scale with the circle (see
    /// TriggerTrackingView), so a smaller circle still shows a
    /// proportional letter.
    static var compactSize: CGFloat { CGFloat(Defaults[.autoShowFloatIconSize]) }

    init() {
        let rect = NSRect(x: 0, y: 0, width: Self.size, height: Self.size)
        super.init(
            contentRect: rect,
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
}
