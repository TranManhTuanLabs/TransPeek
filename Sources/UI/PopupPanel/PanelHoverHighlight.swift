import SwiftUI

/// Custom hover highlight for panel buttons (Manh 2026-11-20, "Làm cả 2").
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
/// Apply to every panel button for consistency. It does not change the
/// button's style (`.plain` stays `.plain`, `.bordered` stays `.bordered`)
/// and does not touch the settled 0.25-opacity borders. The tint is an
/// overlay (not a background) so it stays visible on `.bordered` buttons
/// too, whose own background would cover a background highlight.
struct PanelHoverHighlight: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
            }
            .onHover { isHovering = $0 }
    }
}

extension View {
    /// Subtle hover tint for a panel button — see `PanelHoverHighlight`.
    func panelHoverHighlight() -> some View {
        modifier(PanelHoverHighlight())
    }
}
