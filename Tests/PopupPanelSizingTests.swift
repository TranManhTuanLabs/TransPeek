import AppKit
import Testing
@testable import TransPeek

@Suite struct PopupPanelSizingTests {
    private let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)

    @Test func shortResultStaysAtMinimumAndKeepsTopEdge() {
        let current = NSRect(x: 120, y: 300, width: 440, height: 450)

        let result = PopupPanelSizing.frameToFit(
            currentFrame: current,
            contentHeight: 100,
            viewportHeight: 250,
            measuredContainerHeight: 450,
            minimumHeight: 450,
            maximumHeight: 800,
            visibleFrame: visibleFrame
        )

        #expect(result.height == 450)
        #expect(result.maxY == current.maxY)
        #expect(result.origin.x == current.origin.x)
    }

    @Test func longResultGrowsOnlyToOutputCapAndKeepsTopEdge() {
        // Output cap (Manh 2026-11-16, Windows direction, design settled):
        // 500pt of content grows the panel to chrome + cap, not to chrome
        // + full content (200 + 500). Long text scrolls inside the results
        // box past the cap. The cap is the text cap (260) PLUS one card's
        // non-text chrome (90) so the whole first card — including its
        // speaker/Copy row — fits in the viewport (Manh 2026-11-17).
        let current = NSRect(x: 120, y: 300, width: 440, height: 450)

        let result = PopupPanelSizing.frameToFit(
            currentFrame: current,
            contentHeight: 500,
            viewportHeight: 250,
            measuredContainerHeight: 450,
            minimumHeight: 450,
            maximumHeight: 800,
            visibleFrame: visibleFrame
        )

        #expect(result.height == 550) // 200pt chrome + (260pt text cap + 90pt card chrome)
        #expect(result.maxY == current.maxY)
        #expect(result.origin.x == current.origin.x)
    }

    @Test func growthIsCappedByMaximumAndViewportAndClampedOnScreen() {
        let current = NSRect(x: 120, y: 100, width: 440, height: 450)
        let smallVisibleFrame = NSRect(x: 0, y: 0, width: 800, height: 500)

        let screenCapped = PopupPanelSizing.frameToFit(
            currentFrame: current,
            contentHeight: 2_000,
            viewportHeight: 100,
            measuredContainerHeight: 450,
            minimumHeight: 450,
            maximumHeight: 800,
            visibleFrame: smallVisibleFrame
        )
        #expect(screenCapped.height == 484) // 500pt viewport minus 8pt top/bottom padding
        #expect(screenCapped.minY == 8)
        #expect(screenCapped.maxY <= smallVisibleFrame.maxY - 8)

        let maximumCapped = PopupPanelSizing.frameToFit(
            currentFrame: current,
            contentHeight: 2_000,
            viewportHeight: 100,
            measuredContainerHeight: 450,
            minimumHeight: 450,
            maximumHeight: 420,
            visibleFrame: visibleFrame
        )
        #expect(maximumCapped.height == 420)
        #expect(maximumCapped.maxY == current.maxY)
    }

    @Test func laterShortResultShrinksBackToMinimum() {
        let tallCurrent = NSRect(x: 120, y: 50, width: 440, height: 600)

        let result = PopupPanelSizing.frameToFit(
            currentFrame: tallCurrent,
            contentHeight: 100,
            viewportHeight: 500,
            measuredContainerHeight: 600,
            minimumHeight: 450,
            maximumHeight: 800,
            visibleFrame: visibleFrame
        )

        #expect(result.height == 450)
        #expect(result.maxY == tallCurrent.maxY)
        #expect(result.origin.x == tallCurrent.origin.x)
    }

    @Test func usesMeasuredLayoutWhenPanelFrameHasAlreadyGrown() {
        let current = NSRect(x: 120, y: 50, width: 440, height: 600)

        let result = PopupPanelSizing.frameToFit(
            currentFrame: current,
            contentHeight: 550,
            viewportHeight: 250,
            measuredContainerHeight: 450,
            minimumHeight: 450,
            maximumHeight: 800,
            visibleFrame: visibleFrame
        )

        // Chrome comes from the MEASURED container (450 − 250 = 200), not
        // from the already-grown 600pt frame; output is capped at the text
        // cap (260) plus one card's chrome (90).
        #expect(result.height == 550)
    }
}
