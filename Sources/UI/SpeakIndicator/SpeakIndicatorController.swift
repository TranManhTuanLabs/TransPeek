import AppKit
import Defaults

// MARK: - SpeakIndicatorPanel

/// The indicator's floating window — the same kind of window as the
/// float icon's TriggerIconPanel (borderless, non-activating, floating
/// level, joins all spaces), but owned by the speak indicator, not the
/// icon. The indicator is a separate element (Manh 2026-11-26,
/// SPEECH_PLAYER.md §1): it shows where the user clicked Speak and
/// never follows the text.
final class SpeakIndicatorPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )

        isReleasedWhenClosed = false
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
}

// MARK: - SpeakIndicatorView

/// The indicator's circle: ⏸ while playing (click to pause), ▶ while
/// paused (click to resume). Drawn like the float icon's circle
/// (controlBackgroundColor fill, separator border, accent SF Symbol
/// glyph at ~44% of the diameter) so it reads as the same family.
/// Reports hover (to pause the auto-hide timer) and click (to toggle).
@MainActor
final class SpeakIndicatorView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseDown: (() -> Void)?

    /// True while the session is paused: ▶ (play.fill, click to
    /// resume). False while playing: ⏸ (pause.fill, click to pause).
    var isPaused = false {
        didSet {
            if isPaused != oldValue {
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
        let rect = bounds.insetBy(dx: 1, dy: 1)

        // Circle background
        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        ctx.fillEllipse(in: rect)

        // Border
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: rect)

        // Glyph tells what the next click will do (the float icon's
        // standing principle): playing → ⏸ (pause), paused → ▶ (resume).
        drawSymbolGlyph(named: isPaused ? "play.fill" : "pause.fill", in: bounds)
    }

    /// The glyph scales with the circle (same ~44% as the float icon's
    /// speaker glyph), so a smaller circle still shows a proportional
    /// symbol.
    private var glyphPointSize: CGFloat { bounds.width * 0.44 }

    /// Draw an SF Symbol glyph (accent color) centred in the circle.
    private func drawSymbolGlyph(named symbolName: String, in bounds: NSRect) {
        let symbolColor = NSColor.controlAccentColor
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: symbolColor)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName)?
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

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }
}

// MARK: - SpeakIndicatorController

/// The separate speak indicator (Manh 2026-11-26, SPEECH_PLAYER.md §1):
/// a floating ⏸/▶ button that owns the pause/resume control for the
/// on-page speak session, INDEPENDENT of the float icon. The icon keeps
/// its normal lifecycle (auto-hide, dismiss when the block scrolls) and
/// never shows playback state; the indicator shows where the user
/// clicked Speak, stays put (never follows the text), and manages its
/// own hide: visible while playing, auto-hides after 5s while paused
/// (hover pauses the timer), and when it hides the session ends
/// silently (there is no Stop button and no Esc).
@MainActor
final class SpeakIndicatorController {
    /// Click while playing: pause the session (keep position + highlight).
    var onPauseRequested: (() -> Void)?
    /// Click while paused: resume from the kept position.
    var onResumeRequested: (() -> Void)?
    /// The indicator hid on its own (auto-hide while paused): the
    /// session ends silently — once the indicator is gone there is no
    /// way to resume it.
    var onDismissed: (() -> Void)?

    /// True while the session shown is paused (▶). Only meaningful
    /// while the indicator is visible.
    private(set) var isPaused = false {
        didSet { indicatorView?.isPaused = isPaused }
    }

    private var panel: SpeakIndicatorPanel?
    private var indicatorView: SpeakIndicatorView?
    private var autoDismissTimer: Timer?

    /// Show the indicator at `frame` (the float icon's frame — the place
    /// the user clicked Speak), showing ⏸ (playing). If already visible,
    /// replace silently (a new play replaces the old session, with its
    /// old indicator — no dismiss callback, the old session is ended by
    /// the caller's stop, not by the hide). `frame` nil → centre on the
    /// mouse (fallback when the icon frame is unavailable).
    func show(at frame: CGRect?) {
        // Replace silently — a new session's indicator takes the old
        // one's place.
        dismissSilently()

        let rect = frame ?? defaultFrame()
        let panel = SpeakIndicatorPanel(frame: rect)
        let view = SpeakIndicatorView(frame: NSRect(x: 0, y: 0, width: rect.width, height: rect.height))
        view.isPaused = false

        view.onMouseEntered = { [weak self] in
            // Hover pauses the auto-hide timer (the normal auto-hide
            // law): the user is reaching for the button, so it must
            // not vanish under the cursor.
            self?.cancelAutoDismissTimer()
        }
        view.onMouseExited = { [weak self] in
            // Mouse left — resume the countdown, but only while paused
            // (while playing the indicator never auto-hides).
            guard let self, self.isPaused else { return }
            self.startAutoDismissTimer()
        }
        view.onMouseDown = { [weak self] in
            guard let self else { return }
            if self.isPaused {
                self.onResumeRequested?()
            } else {
                self.onPauseRequested?()
            }
        }

        panel.contentView = view
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.indicatorView = view
        // A new indicator always starts playing (⏸) — no auto-hide
        // until it is paused.
        isPaused = false
    }

    /// Set the paused state and redraw (⏸ ↔ ▶). While PAUSED the
    /// indicator auto-hides after 5s (the session then ends silently);
    /// while PLAYING it stays. No-op when the state is unchanged.
    func setPaused(_ paused: Bool) {
        guard isPaused != paused else { return }
        isPaused = paused
        if paused {
            if panel != nil { startAutoDismissTimer() }
        } else {
            cancelAutoDismissTimer()
        }
    }

    /// Hide silently — the session ended for another reason (natural
    /// end, or a new play replacing it). No dismiss callback.
    func hide() {
        dismissSilently()
    }

    /// Hide with fade-out and notify via onDismissed (the auto-hide
    /// timer's path — the indicator hid while paused, so the session
    /// ends silently).
    func dismiss() {
        guard let panel else { return }
        cancelAutoDismissTimer()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                panel.contentView = nil
                panel.close()
                self?.cleanup()
                self?.onDismissed?()
            }
        })
    }

    /// Hide immediately without a callback — replacing with a new
    /// indicator, or the session ended elsewhere.
    func dismissSilently() {
        guard let panel else { return }
        cancelAutoDismissTimer()
        panel.contentView = nil
        panel.close()
        cleanup()
    }

    private func cleanup() {
        isPaused = false
        panel = nil
        indicatorView = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Fallback frame when the icon frame is unavailable: centre the
    /// indicator on the mouse (the place the user clicked). Same size
    /// as the float icon's default so it reads as the same family.
    private func defaultFrame() -> CGRect {
        let size = TriggerIconPanel.size
        let mouse = NSEvent.mouseLocation
        return NSRect(x: mouse.x - size / 2, y: mouse.y - size / 2, width: size, height: size)
    }

    private func startAutoDismissTimer() {
        // Only while paused: playing never auto-hides (the indicator
        // must stay so the user can click to pause — no Esc, no Stop).
        guard isPaused else { return }
        cancelAutoDismissTimer()
        // Same delay as the float icon's auto-hide (Settings, default
        // 5s): long enough to reach the button, short enough not to
        // linger. When it fires the session ends silently.
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: Double(Defaults[.autoHideDelaySec]), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func cancelAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }
}
