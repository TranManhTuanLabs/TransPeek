import AppKit

/// The alternative icon's glyph view: a blue "A" inside a chat bubble.
/// A real floating view (receives mouse events), not a static image.
/// The bubble is the earlier icon design (Style 2, `character.bubble`
/// era), reused here for the in-Read lookup icon — it looks like the
/// float icon but is a different object with its own wiring (see
/// docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md). The glyph does NOT
/// change on hover (unlike the main float icon) and does NOT change
/// while speaking (Manh 2026-11-27: playback state lives only on the
/// separate speak indicator — the icon always keeps its blue A).
@MainActor
final class AlternativeIconView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseDown: ((NSEvent) -> Void)?

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Chat bubble: a rounded rect (the "chat box"), filled and
        // stroked like the main icon's circle so the two icons feel
        // like family. No tail — the rounded rect alone reads as a
        // chat bubble at this size.
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let radius = rect.height * 0.30
        let bubblePath = CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        ctx.addPath(bubblePath)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.addPath(bubblePath)
        ctx.strokePath()

        // Glyph — always the plain blue A (same on hover, same while
        // speaking). Playback state lives only on the separate speak
        // indicator (Manh 2026-11-27), so the icon never swaps glyphs.
        drawPlainAGlyph(in: bounds)
    }

    /// The "A" is half the bubble size (Manh 2026-11-21, same rule as
    /// the main icon) — a smaller bubble still shows a proportional
    /// letter.
    private var aFontSize: CGFloat { bounds.width * 0.5 }

    /// Draw the translate glyph: a plain "A", regular weight (NOT bold),
    /// blue (Style 1, like the main icon's idle glyph). Drawn as text
    /// into the current graphics context — there is no plain-A SF Symbol.
    private func drawPlainAGlyph(in bounds: NSRect) {
        let aFont = NSFont.systemFont(ofSize: aFontSize)
        let aAttrs: [NSAttributedString.Key: Any] = [
            .font: aFont,
            .foregroundColor: NSColor.systemBlue,
        ]
        let aString = NSAttributedString(string: "A", attributes: aAttrs)
        let aSize = aString.size()
        let aOrigin = NSPoint(
            x: bounds.midX - aSize.width / 2,
            y: bounds.midY - aSize.height / 2
        )
        aString.draw(at: aOrigin)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }
}
