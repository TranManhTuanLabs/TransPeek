import AppKit

/// Shows the resize cursor when the mouse is near the panel's right edge,
/// bottom edge, or bottom-right corner — including slightly OUTSIDE the
/// window, so the cursor changes while the mouse approaches the corner from
/// outside (below), like a native window. SwiftUI onHover only fires once
/// the mouse is inside the window, which is why the corner felt dead when
/// approached from outside: the edges are long strips, so they still felt
/// instant, but the corner is a single point.
///
/// The monitor only ever SETS a resize cursor when near a zone; it never
/// forces the arrow cursor. Resetting is left to the panel's own onHover
/// handlers (once the mouse is inside) and to the app under the mouse
/// (once it moves away to another app/desktop), so it cannot fight a text
/// field's I-beam or another app's cursor.
@MainActor
final class PopupResizeCursorMonitor {
    private weak var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// How far outside the panel frame the hot zone reaches (points).
    private let outsideMargin: CGFloat = 8
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
            return
        }
    }
}
