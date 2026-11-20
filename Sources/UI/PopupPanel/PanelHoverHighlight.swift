import SwiftUI

/// Custom hover + pressed highlight for panel buttons (Manh 2026-11-20,
/// "Làm cả 2"; click fix + pressed state Manh 2026-11-20, 10:11).
///
/// Why custom: the panel is an NSPanel with `.nonactivatingPanel`, so it
/// never activates the app — and macOS only draws the system hover effect
/// on buttons while the app is active. `.plain` buttons (Pin, Capture OCR,
/// Fast Read, "?", Settings) have no decoration at all, so there is nothing
/// to light up even in an active window. The only fix is to draw the
/// feedback ourselves: a subtle rounded translucent tint while the pointer
/// is over the button (`.onHover`, which DOES fire — the dictionary/GitHub
/// links already use it for the pointing-hand cursor).
///
/// CLICK BUG, build 285 (Manh 2026-11-20, 10:11 — "nút hover sáng nhưng
/// click không được"): the first version drew the tint as a plain
/// `.overlay` Shape. That Shape sits ON TOP of the button and is
/// hit-testable, so it became the hit view for the click: AppKit
/// dispatches a mouse-down to the topmost hit view, the Shape does
/// nothing with it, and the button underneath never fires. (The
/// input box and the source picker had no modifier yet, so they still
/// clicked fine — the modifier was the only difference.) The fix is
/// `.allowsHitTesting(false)` on the tint: the highlight is purely
/// visual and never participates in hit-testing, so clicks reach the
/// button itself, exactly as before the modifier existed.
/// Apply to every panel button for consistency. It does not change the
/// button's style (`.plain` stays `.plain`, `.bordered` stays `.bordered`)
/// and does not touch the settled 0.25-opacity borders. The tint is an
/// overlay (not a background) so it stays visible on `.bordered` buttons
/// too, whose own background would cover a background highlight.
///
/// Pressed state (Manh 2026-11-20, 10:11): hover alone is not enough —
/// pressing must look clearly different from hovering, so the user can
/// tell them apart. A simultaneous zero-distance drag tracks the press
/// (down = pressed, up = released). It is simultaneous so it never
/// blocks the button's own tap, and a gesture adds no hit-testable view,
/// so it cannot break clicks the way the overlay did. Pressed is a
/// deeper tint (0.18) than hover (0.08).
struct PanelHoverHighlight: ViewModifier {
    @State private var isHovering = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isPressed ? 0.18 : (isHovering ? 0.08 : 0)))
                    // Visual only: never intercept clicks (build 285 bug —
                    // a hit-testable overlay on top of a button swallows
                    // the mouse-down and the button never fires).
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                isHovering = hovering
                if !hovering { isPressed = false }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Subtle hover + pressed tint for a panel button (or the input box /
    /// a language picker) — see `PanelHoverHighlight`.
    func panelHoverHighlight() -> some View {
        modifier(PanelHoverHighlight())
    }
}
