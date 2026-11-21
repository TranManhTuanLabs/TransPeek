import AppKit

/// The alternative icon's glyph view: a blue "A" inside a chat bubble.
/// A real floating view (receives mouse events), not a static image.
/// The bubble is the earlier icon design (Style 2, `character.bubble`
/// era), reused here for the in-Read lookup icon — it looks like the
/// float icon but is a different object with its own wiring (see
/// docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md). The glyph does NOT
/// change on hover (unlike the main float icon); it only switches to
/// the speaker while its own TTS is speaking.
@MainActor
final class AlternativeIconView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseDown: ((NSEvent) -> Void)?

    /// True while the icon's own TTS is speaking the selected text.
    /// Shows the speaker glyph instead of the "A" (click again to stop).
    var isSpeaking = false {
        didSet {
            if isSpeaking != oldValue {
                needsDisplay = true
            }
        }
    }

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

        // Glyph — same on hover (no swap). Speaking shows the speaker
        // so the user can click again to stop it.
        if isSpeaking {
            drawSpeakerGlyph(in: bounds)
        } else {
            drawPlainAGlyph(in: bounds)
        }
    }

    /// Glyph sizes scale with the bubble (Manh 2026-11-21, same rule
    /// as the main icon): the "A" is half the bubble size, the speaker
    /// ~44% — a smaller bubble still shows a proportional letter.
    private var aFontSize: CGFloat { bounds.width * 0.5 }
    private var speakerPointSize: CGFloat { bounds.width * 0.44 }

    /// Draw the speaker glyph (`speaker.wave.2.fill`, accent color) —
    /// shown while the icon's own TTS is speaking (click again to stop).
    private func drawSpeakerGlyph(in bounds: NSRect) {
        let symbolName = "speaker.wave.2.fill"
        let symbolColor = NSColor.controlAccentColor
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: speakerPointSize, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: symbolColor)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Speak")?
            .withSymbolConfiguration(sizeConfig.applying(colorConfig))
        {
            let imageSize = image.size
            let imageRect = NSRect(
                x: (bounds.width - imageSize.width) / 2,
                y: (bounds.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

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
