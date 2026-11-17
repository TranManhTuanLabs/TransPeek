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

    /// Estimated non-text height of one result card (header + divider +
    /// action row + paddings, at the largest font size): the panel must be
    /// this much taller than the text cap so the card's speaker/Copy row
    /// stays visible without scrolling the panel (Manh 2026-11-17, Windows
    /// parity — the Windows TextBox caps at 260 and its overlay buttons sit
    /// inside the visible box). An over-estimate is safe: the cap below is
    /// a maximum, and the panel uses min(content, cap), so a too-large
    /// value never adds empty space for a single card.
    static let resultCardChrome: CGFloat = 90

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
        // The cap covers the text (260) PLUS one card's non-text chrome
        // (header + speaker/Copy row), so the whole first card — including
        // its buttons — fits in the viewport without scrolling the panel
        // (Manh 2026-11-17). The card's own text is capped separately at
        // autoFitOutputCap and scrolls inside the card.
        let cappedContentHeight = min(contentHeight, autoFitOutputCap + resultCardChrome)
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
