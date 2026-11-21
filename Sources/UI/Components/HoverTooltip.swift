import SwiftUI

/// A small tooltip label that appears above a view shortly after the mouse
/// hovers it. The system `.help()` tooltip does not fire in the
/// non-activating panel (so Fast Read Lite shows no hints at all) and is
/// slow in the regular window (the macOS default delay, even with the
/// app's registered 300 ms `NSInitialToolTipDelay`), so the Fast Read
/// control rows need a fast, in-view hint that behaves identically on
/// both surfaces. `.help()` is kept alongside as a fallback (and for
/// accessibility) — this tooltip is the one the user actually sees.
/// Delay matches the app's registered tooltip delay (300 ms).
struct HoverTooltipModifier: ViewModifier {
    let text: String
    /// Delay before the tooltip appears, in milliseconds (default 300).
    let delayMs: Int
    @State private var isVisible = false
    @State private var showTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                showTask?.cancel()
                if hovering {
                    // Wait briefly so a passing mouse does not flash the
                    // label on every control it crosses.
                    showTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(delayMs))
                        guard !Task.isCancelled else { return }
                        isVisible = true
                    }
                } else {
                    isVisible = false
                }
            }
            .overlay(alignment: .top) {
                if isVisible {
                    Text(text)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                        // The label must never steal the click meant for
                        // the control underneath it.
                        .allowsHitTesting(false)
                        // Above the control (the control rows sit at the
                        // bottom, so below would fall off the window).
                        .offset(y: -30)
                }
            }
    }
}

extension View {
    /// Show `text` as a small fast tooltip above the view on hover.
    /// Use alongside `.help()` (kept as fallback); this is the hint the
    /// user sees. `delayMs` defaults to 300, matching the app's
    /// registered `NSInitialToolTipDelay`.
    func hoverTooltip(_ text: String, delayMs: Int = 300) -> some View {
        modifier(HoverTooltipModifier(text: text, delayMs: delayMs))
    }
}
