import AppKit

struct PopupResultLayout: Equatable {
    var contentHeight: CGFloat?
    var viewportHeight: CGFloat?
    var containerHeight: CGFloat?
}

enum PopupPanelSizing {
    /// Auto-fit caps the result viewport at this height (Windows parity,
    /// Manh 2026-11-16, design settled): long text scrolls inside the
    /// results box instead of growing the panel to show it all. A manual
    /// drag still expands the panel (and the viewport) beyond the cap for
    /// this session.
    static let autoFitOutputCap: CGFloat = 260

    static func frameToFit(
        currentFrame: NSRect,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        measuredContainerHeight: CGFloat,
        minimumHeight: CGFloat,
        maximumHeight: CGFloat,
        visibleFrame: NSRect
    ) -> NSRect {
        let padding: CGFloat = 8
        let chromeHeight = max(measuredContainerHeight - viewportHeight, 0)
        // Cap the output so long text scrolls inside the results box
        // instead of growing the panel (Windows direction, Manh 2026-11-16).
        let cappedContentHeight = min(contentHeight, autoFitOutputCap)
        // The floor is the panel minimum, NOT a saved/default height: a
        // tall drag in a previous session must not keep the panel tall for
        // short text (report 7.4, Manh 2026-11-16). The minimum is enforced
        // here explicitly, not left to "content is always tall enough".
        let desiredHeight = max(minimumHeight, chromeHeight + cappedContentHeight)
        let screenLimit = max(visibleFrame.height - 2 * padding, 0)
        let height = min(desiredHeight, maximumHeight, screenLimit)
        let top = currentFrame.maxY
        let minY = visibleFrame.minY + padding
        let maxY = visibleFrame.maxY - height - padding
        let y = maxY >= minY ? min(max(top - height, minY), maxY) : minY
        return NSRect(x: currentFrame.minX, y: y, width: currentFrame.width, height: height)
    }
}
