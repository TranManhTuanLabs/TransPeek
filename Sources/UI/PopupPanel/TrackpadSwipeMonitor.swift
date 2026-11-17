import AppKit
import Combine

/// The direction of a two-finger trackpad swipe (Manh 2026-11-17).
enum TrackpadSwipeDirection {
    /// Fingers moved right — switch to the panel on the right (the next
    /// tab). Flipped 2026-11-17 ~20:28: Manh tested the first mapping
    /// (fingers left → next) and it felt backwards, so it is now
    /// fingers right → next.
    case next
    /// Fingers moved left — switch to the panel on the left (the previous
    /// tab).
    case previous
}

/// Turns a two-finger horizontal trackpad swipe over the popup panel into a
/// tab switch (Manh 2026-11-17 — the dots row's DragGesture only sees mouse
/// drags, so a 2-finger swipe did nothing).
///
/// API behavior (researched 2026-11-17, from Apple docs + real apps):
/// - A 2-finger trackpad swipe is NOT an `NSEventTypeSwipe` /
///   `swipeWithEvent:` — that is only for 3-finger swipes (and depends on
///   System Preferences). A 2-finger swipe arrives as a stream of
///   `.scrollWheel` events with `scrollingDeltaX/Y` (precise, in points).
/// - So this uses a bounds-scoped LOCAL `NSEvent` monitor for
///   `.scrollWheel` — NOT a responder-chain view. A `.background` sibling
///   never sees wheel events (the results ScrollView eats them), and a
///   hit-testing overlay would steal clicks/hovers. A local monitor runs
///   before view dispatch, so it can claim a horizontal swipe and pass
///   vertical scrolling through to the ScrollView.
/// - Only gesture-phased trackpad events count (`event.phase != []`);
///   mouse-wheel events (empty phase) and momentum coasting
///   (`momentumPhase != []`) never trigger a switch.
/// - `scrollingDeltaX` already honors Natural scrolling: fingers moving
///   left gives a positive delta. Flipped 2026-11-17 ~20:28 (Manh tested
///   the first mapping and it felt backwards): a positive delta is now the
///   previous panel (to the left), a negative delta the next panel (to the
///   right).
/// - One swipe = one switch: the accumulated horizontal delta must pass
///   50pt, it fires once per gesture, and momentum events are drained
///   (ignored) until the gesture fully ends, so a single swipe never
///   flips two tabs.
/// - Only horizontal-dominant swipes count (|deltaX| > |deltaY| × 1.5);
///   a vertical-dominant swipe passes through untouched so the results
///   ScrollView scrolls normally. Text selection is a mouse drag, not a
///   scroll event, so a trackpad swipe never steals a selection.
final class TrackpadSwipeMonitor: ObservableObject {
    /// Emitted once per swipe that passes the threshold.
    let swipePublisher = PassthroughSubject<TrackpadSwipeDirection, Never>()

    /// The accumulated horizontal delta for the current gesture (points).
    private var accumulatedX: CGFloat = 0
    /// Whether this gesture already fired a switch (one swipe = one switch).
    private var firedForGesture = false
    /// The local monitor token (nil when not installed).
    private var monitor: Any?

    /// The panel the swipe must happen over (weak — the panel owns the view
    /// that owns this monitor). Events over any other window pass through.
    private weak var panel: NSPanel?

    /// Install the local monitor. Safe to call repeatedly (no-op if already
    /// installed). The panel is the scope: only scroll events over it are
    /// considered.
    func start(panel: NSPanel) {
        self.panel = panel
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event: event) ?? event
        }
    }

    /// Remove the local monitor. Safe to call repeatedly.
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        panel = nil
        accumulatedX = 0
        firedForGesture = false
    }

    deinit {
        stop()
    }

    /// Handle one scroll-wheel event. Returns nil to consume it (a
    /// horizontal swipe over the panel that we claimed), or the event
    /// itself to pass it through untouched.
    private func handle(event: NSEvent) -> NSEvent? {
        // Scope: only events over the visible popup panel.
        guard let panel, panel.isVisible, event.window == panel else { return event }
        // Only gesture-phased trackpad events (phase != []) count. A mouse
        // wheel has empty phase; momentum coasting has a momentumPhase —
        // neither ever triggers a switch.
        guard event.phase != [] else { return event }
        guard event.momentumPhase == [] else { return event }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        switch event.phase {
        case .began:
            accumulatedX = 0
            firedForGesture = false
        case .changed:
            // Only a horizontal-dominant swipe counts; a vertical one
            // passes through so the results ScrollView scrolls normally.
            guard abs(deltaX) > abs(deltaY) * 1.5 else { return event }
            accumulatedX += deltaX
            if !firedForGesture, abs(accumulatedX) >= 50 {
                firedForGesture = true
                // Flipped 2026-11-17 ~20:28 (Manh tested the first mapping
                // and it felt backwards): fingers left (positive delta) is
                // now the previous panel, fingers right the next panel.
                swipePublisher.send(accumulatedX > 0 ? .previous : .next)
                // Claim the event so the ScrollView doesn't also scroll.
                return nil
            }
        case .ended, .cancelled:
            accumulatedX = 0
            firedForGesture = false
        default:
            break
        }
        return event
    }
}
