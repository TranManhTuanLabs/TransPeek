import AppKit

/// Detects text selections inside TransPeek's own Fast Read surfaces
/// and shows the alternative icon for them. The global
/// `SelectionMonitor` only sees OTHER apps (it gates TransPeek's own
/// windows out), so a selection inside Fast Read needs its own path:
/// a LOCAL mouse-up monitor + an Accessibility read of the focused
/// element (the frontmost app is TransPeek while the user reads, so
/// the AX focused element is the selectable text they just released
/// the mouse on). See docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md.
@MainActor
final class ReadSelectionMonitor {
    /// A selection was found in a Fast Read surface: the text, the
    /// mouse point, and which surface it came from.
    var onSelectionFound: ((String, CGPoint, AlternativeIconSurface) -> Void)?
    /// The mouse was released with no selection (or outside a Read
    /// surface): hide the alternative icon.
    var onSelectionCleared: (() -> Void)?

    /// Surface checks, wired by AppDelegate (the monitor does not own
    /// the windows): is the point inside the Read window / inside the
    /// popup panel on its Fast Read tab / on the alternative icon itself.
    var isInWindowRead: ((CGPoint) -> Bool)?
    var isInLiteRead: ((CGPoint) -> Bool)?
    var isInAlternativeIcon: ((CGPoint) -> Bool)?

    private var mouseUpMonitor: Any?

    func start() {
        guard mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseUp(event)
            }
            return event
        }
    }

    func stop() {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        // A mouse-up on the alternative icon itself belongs to the
        // icon (its click), not to a new selection.
        if isInAlternativeIcon?(point) == true { return }
        // Which Fast Read surface (if any) is the mouse in? The icon
        // only appears for selections inside a Read surface — never
        // for the translate input or Settings.
        let surface: AlternativeIconSurface?
        if isInWindowRead?(point) == true {
            surface = .windowRead
        } else if isInLiteRead?(point) == true {
            surface = .lite
        } else {
            surface = nil
        }
        guard let surface else {
            onSelectionCleared?()
            return
        }
        // Read the selected text from the focused element (TransPeek is
        // frontmost while the user reads, so the AX focused element is
        // the selectable text they just released the mouse on).
        guard let text = AccessibilityGrabber.grabSelectedText(near: point),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            onSelectionCleared?()
            return
        }
        onSelectionFound?(text, point, surface)
    }
}
