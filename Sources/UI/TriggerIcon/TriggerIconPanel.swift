import AppKit

/// A tiny floating panel that hosts the trigger icon near the cursor.
final class TriggerIconPanel: NSPanel {
    static let size: CGFloat = 32
    /// Compact size for the block-text hover icon (Manh 2026-11-21):
    /// the hover icon appears often (every text block), so it is smaller
    /// than the selection icon — less in the way of the mouse and the
    /// text, still easy to see and click. The glyphs (15pt "A", 14pt
    /// speaker) still fit inside.
    static let compactSize: CGFloat = 24

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
