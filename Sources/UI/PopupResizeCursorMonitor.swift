import AppKit

/// Shows the resize cursor when the mouse is near the panel's right edge,
/// bottom edge, or bottom-right corner — including slightly OUTSIDE the
/// window, so the cursor changes while the mouse approaches the corner from
/// outside (below), like a native window. SwiftUI onHover only fires once
/// the mouse is inside the window, which is why the corner felt dead when
/// approached from outside: the edges are long strips, so they still felt
/// instant, but the corner is a single point.
///
/// The monitor SETS a resize cursor when near a zone, and releases it
/// (back to the arrow) exactly once when the mouse leaves a zone for
/// outside the panel — otherwise the resize cursor would stay stuck after
/// the mouse moves away, because nothing else resets it. It never touches
/// the cursor while the mouse is INSIDE the panel: the panel's own onHover
/// handlers own it there (including a text field's I-beam), so the monitor
/// cannot fight them.
@MainActor
final class PopupResizeCursorMonitor {
    private weak var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// True after the monitor set a resize cursor; cleared once it releases
    /// the cursor (or the mouse moves back inside the panel, where onHover
    /// owns the cursor). Only used to release the cursor once when the
    /// mouse leaves a hot zone for outside the panel.
    private var didSetResizeCursor = false

    /// How far outside the panel frame the hot zone reaches (points).
    /// 0 = the cursor changes only once the mouse is ON the grip/edge
    /// itself (exactly the corner point). A larger margin (was 8) makes
    /// the cursor change BEFORE the mouse reaches the corner, which lies:
    /// clicking there is still outside the panel, so it misses the grip
    /// and dismisses the panel instead of resizing (Manh 2026-11-16).
    private let outsideMargin: CGFloat = 0
    /// Corner zone extends this far inside the frame (matches the 20pt grip).
    private let cornerInside: CGFloat = 20
    /// Edge zones extend this far inside the frame (matches the 6pt strips).
    private let edgeInside: CGFloat = 6

    init(panel: NSPanel) {
        self.panel = panel
    }

    func start() {
        stop()
        // Global: mouse over OTHER apps / the desktop (approaching from outside).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.updateCursor() }
        }
        // Local: mouse over OUR app (global monitors don't fire for our own events).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in self?.updateCursor() }
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = nil
        localMonitor = nil
        // Never leave a stuck resize cursor behind when the panel goes away.
        if didSetResizeCursor {
            NSCursor.arrow.set()
            didSetResizeCursor = false
        }
    }

    deinit {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func updateCursor() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let right = frame.maxX
        let bottom = frame.minY
        let top = frame.maxY
        let left = frame.minX

        // Corner first (most specific): square around the bottom-right
        // corner, reaching outsideMargin beyond the frame.
        let corner = NSRect(
            x: right - cornerInside,
            y: bottom - outsideMargin,
            width: cornerInside + outsideMargin,
            height: cornerInside + outsideMargin
        )
        if corner.contains(mouse) {
            if #available(macOS 15.0, *) {
                NSCursor.frameResize(position: .bottomRight, directions: .all).set()
            }
            didSetResizeCursor = true
            return
        }

        // Right edge (excluding the corner square).
        let rightEdge = NSRect(
            x: right - edgeInside,
            y: bottom + cornerInside,
            width: edgeInside + outsideMargin,
            height: top - (bottom + cornerInside)
        )
        if rightEdge.contains(mouse) {
            NSCursor.resizeLeftRight.set()
            didSetResizeCursor = true
            return
        }

        // Bottom edge (excluding the corner square).
        let bottomEdge = NSRect(
            x: left,
            y: bottom - outsideMargin,
            width: (right - cornerInside) - left,
            height: edgeInside + outsideMargin
        )
        if bottomEdge.contains(mouse) {
            NSCursor.resizeUpDown.set()
            didSetResizeCursor = true
            return
        }

        // Not near any zone. Inside the panel, leave the cursor alone —
        // the panel's onHover handlers own it there (including a text
        // field's I-beam). Outside the panel, if the monitor previously
        // set a resize cursor, release it back to the arrow exactly once;
        // otherwise the resize cursor stays stuck after the mouse moves
        // away, because nothing else resets it (Manh 2026-11-16).
        if frame.contains(mouse) {
            didSetResizeCursor = false
            return
        }
        if didSetResizeCursor {
            NSCursor.arrow.set()
            didSetResizeCursor = false
        }
    }
}
