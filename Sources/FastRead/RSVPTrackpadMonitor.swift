import AppKit
import Combine

/// What a trackpad swipe over the Fast Read window means (Manh
/// 2026-11-18, from testing v0.1.3.226).
enum RSVPTrackpadAction {
    /// Fingers swiped left — like pressing → (next slide).
    case stepForward
    /// Fingers swiped right — like pressing ← (previous slide).
    case stepBack
    /// Fingers swiped up — make the reading text bigger.
    case fontBigger
    /// Fingers swiped down — make the reading text smaller.
    case fontSmaller
}

/// Turns two-finger trackpad swipes over the Fast Read window into
/// reading actions (Manh 2026-11-18): a horizontal swipe steps slides
/// (like the ←/→ keys), a vertical swipe changes the font size.
///
/// Same API behavior as the panel's TrackpadSwipeMonitor (researched
/// 2026-11-17): a 2-finger swipe arrives as a stream of `.scrollWheel`
/// events with `scrollingDeltaX/Y` (precise, in points) — NOT an
/// `NSEventTypeSwipe` (that is only for 3-finger swipes). So this uses
/// a bounds-scoped LOCAL `NSEvent` monitor for `.scrollWheel`.
///
/// Direction mapping (natural scrolling, verified against the panel
/// monitor's comment — fingers moving left gives a positive deltaX):
/// - Horizontal: fingers left (positive deltaX) = step FORWARD, like
///   turning a page (→); fingers right (negative deltaX) = step BACK
///   (←). This is the page-turn convention, the OPPOSITE of the panel
///   tab mapping (there, fingers left = previous tab) — if it feels
///   backwards, flip it.
/// - Vertical: fingers up (negative deltaY) = font BIGGER; fingers
///   down (positive deltaY) = font SMALLER. One step changes the size
///   by 2pt (the same step as the font picker). A vertical swipe only
///   changes the text size — it never scrolls the block text (Manh
///   2026-11-18: when paused, up/down must not scroll the page).
///
/// Speed (Manh 2026-11-18, SwiftRead-style): horizontal steps ONE
/// slide per scroll event — SwiftRead's mousewheel handler moves
/// `wordIndex` by 1 on every event, with no threshold, so the word
/// keeps up with the fingers. The old "one step per gesture after
/// 50pt" felt very slow (a long swipe still moved only one word).
/// Vertical accumulates: every 50pt changes the font by 2pt, and a
/// long swipe keeps stepping (the remainder carries over).
///
/// Only gesture-phased trackpad events count (`event.phase != []`);
/// mouse-wheel events (empty phase) and momentum coasting
/// (`momentumPhase != []`) never trigger an action. Only a dominant
/// axis counts (|deltaX| > |deltaY| × 1.5 for horizontal, |deltaY| >
/// |deltaX| × 1.5 for vertical); a diagonal swipe passes through
/// untouched.
final class RSVPTrackpadMonitor: ObservableObject {
    /// Emitted when a swipe should act (once per horizontal event,
    /// once per 50pt of vertical movement).
    let actionPublisher = PassthroughSubject<RSVPTrackpadAction, Never>()

    /// Accumulated vertical delta for the current gesture (points).
    /// Horizontal needs no accumulator — it steps once per event.
    private var accumulatedY: CGFloat = 0
    /// The local monitor token (nil when not installed).
    private var monitor: Any?

    /// The reading window the swipe must happen over (weak — the
    /// controller owns the window). Events over any other window pass
    /// through.
    private weak var window: NSWindow?

    /// Install the local monitor. Safe to call repeatedly (no-op if
    /// already installed). The window is the scope: only scroll events
    /// over it are considered.
    func start(window: NSWindow) {
        self.window = window
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
        window = nil
        accumulatedY = 0
    }

    deinit {
        stop()
    }

    /// Handle one scroll-wheel event. Returns nil to consume it (a
    /// swipe over the window that we claimed), or the event itself to
    /// pass it through untouched.
    private func handle(event: NSEvent) -> NSEvent? {
        // Scope: only events over the visible reading window.
        guard let window, window.isVisible, event.window == window else { return event }
        // Only gesture-phased trackpad events count. A mouse wheel has
        // empty phase; momentum coasting has a momentumPhase — neither
        // ever triggers an action.
        guard event.phase != [] else { return event }
        guard event.momentumPhase == [] else { return event }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        switch event.phase {
        case .began:
            accumulatedY = 0
        case .changed:
            // Only a dominant axis counts; a diagonal swipe passes
            // through untouched.
            let horizontalDominant = abs(deltaX) > abs(deltaY) * 1.5
            let verticalDominant = abs(deltaY) > abs(deltaX) * 1.5
            guard horizontalDominant || verticalDominant else { return event }
            if horizontalDominant {
                // SwiftRead-style: one slide per scroll event, so the
                // word keeps up with the fingers as long as they move.
                // Page-turn convention: fingers left (positive deltaX)
                // = next slide; fingers right = previous.
                actionPublisher.send(deltaX > 0 ? .stepForward : .stepBack)
                return nil
            }
            // Vertical: accumulate; every 50pt changes the font by
            // 2pt, and a long swipe keeps stepping (the remainder
            // carries over to the next event).
            // Fingers up (negative deltaY) = bigger; fingers down
            // (positive deltaY) = smaller.
            accumulatedY += deltaY
            if abs(accumulatedY) >= 50 {
                let bigger = accumulatedY < 0
                accumulatedY -= 50 * (bigger ? -1 : 1)
                actionPublisher.send(bigger ? .fontBigger : .fontSmaller)
            }
            // A vertical swipe over the window only changes the text
            // size — it never scrolls the block text (Manh 2026-11-18,
            // when paused the up/down swipe must not scroll the page).
            return nil
        case .ended, .cancelled:
            accumulatedY = 0
        default:
            break
        }
        return event
    }
}
