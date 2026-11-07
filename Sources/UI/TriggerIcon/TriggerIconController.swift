import AppKit
import Defaults

// MARK: - TriggerTrackingView

/// A circular icon view with mouse tracking for hover and click detection.
@MainActor
final class TriggerTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseDown: (() -> Void)?

    /// When true the icon shows a speaker symbol (TTS playing) instead of the bubble.
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
        let rect = bounds.insetBy(dx: 1, dy: 1)

        // Circle background
        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        ctx.fillEllipse(in: rect)

        // Border
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: rect)

        // SF Symbol icon — speaker while TTS is playing, bubble otherwise.
        let symbolName = isSpeaking ? "speaker.wave.2.fill" : "character.bubble"
        let symbolColor: NSColor = isSpeaking ? .controlAccentColor : .labelColor
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: symbolColor)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isSpeaking ? "Stop speaking" : "Translate")?
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

// MARK: - TriggerIconController

/// Manages the trigger icon lifecycle: show near cursor, hover/click to translate, auto-dismiss.
@MainActor
final class TriggerIconController {
    var onTranslateRequested: ((String) -> Void)?
    /// Click-to-speak (TransPeek Phase 1): invoked with the selected text when the
    /// user clicks the icon while `triggerClickAction` is `.speak`. The panel is
    /// not opened for this path.
    var onSpeakRequested: ((String) -> Void)?
    /// Second click while speaking: the app should stop playback.
    var onStopSpeakRequested: (() -> Void)?
    var onDismissed: (() -> Void)?

    /// True while click-to-speak playback is in progress. The icon shows a
    /// speaker symbol and does not auto-dismiss until playback stops.
    private(set) var isSpeaking = false {
        didSet { trackingView?.isSpeaking = isSpeaking }
    }

    /// Set the speaking state and redraw the icon. While speaking the icon does
    /// not auto-dismiss; when speaking stops the 3s auto-dismiss timer restarts
    /// (only if the icon is still visible).
    func setSpeaking(_ speaking: Bool) {
        guard isSpeaking != speaking else { return }
        isSpeaking = speaking
        if speaking {
            cancelAutoDismissTimer()
        } else if panel != nil {
            startAutoDismissTimer()
        }
    }

    /// Called when TTS playback ends on its own (finished or failed) so the icon
    /// returns to its normal state.
    func speakingDidStop() {
        setSpeaking(false)
    }

    private var panel: TriggerIconPanel?
    private var trackingView: TriggerTrackingView?
    private var currentText: String = ""
    private var activationMode: TriggerActivationMode = .hover
    private var hoverTimer: Timer?
    private var autoDismissTimer: Timer?

    /// Show the trigger icon near the given screen point.
    /// If already visible, silently replace without triggering suppress.
    func show(text: String, near point: CGPoint) {
        // Silently close any existing icon (no dismiss callback)
        dismissSilently()

        currentText = text
        isSpeaking = false

        let panel = TriggerIconPanel()
        let trackingView = TriggerTrackingView(frame: NSRect(x: 0, y: 0, width: TriggerIconPanel.size, height: TriggerIconPanel.size))

        let activationMode = Defaults[.triggerActivationMode]
        self.activationMode = activationMode

        trackingView.onMouseEntered = { [weak self] in
            guard let self else { return }
            switch activationMode {
            case .hover:
                self.startHoverTimer()
            case .click:
                // Pause auto-dismiss while cursor is over the icon so the user has time to click.
                self.cancelAutoDismissTimer()
            }
        }
        trackingView.onMouseExited = { [weak self] in
            guard let self else { return }
            switch activationMode {
            case .hover:
                self.cancelHoverTimer()
            case .click:
                // In click mode, mouseEntered paused auto-dismiss; restart it on exit
                // so the icon eventually disappears if the user never clicks.
                self.startAutoDismissTimer()
            }
        }
        trackingView.onMouseDown = { [weak self] in
            self?.handleIconClick()
        }

        panel.contentView = trackingView

        // Position: offset to the right and below the cursor
        let offset: CGFloat = 8
        let size = TriggerIconPanel.size
        var x = point.x + offset
        var y = point.y - offset - size

        // Adjust for screen bounds
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if x + size > visibleFrame.maxX { x = point.x - size - offset }
            if y + size > visibleFrame.maxY { y = point.y - size - offset }
            if x < visibleFrame.minX { x = visibleFrame.minX }
            if y < visibleFrame.minY { y = visibleFrame.minY }
        }

        panel.setFrame(NSRect(x: x, y: y, width: size, height: size), display: true)
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.trackingView = trackingView

        startAutoDismissTimer()
    }

    /// Dismiss the icon with fade-out and notify via onDismissed.
    func dismiss() {
        guard let panel else { return }
        cancelAllTimers()

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

    /// Dismiss silently — used when replacing with a new icon. Does NOT trigger onDismissed.
    func dismissSilently() {
        guard let panel else { return }
        cancelAllTimers()
        panel.contentView = nil
        panel.close()
        cleanup()
    }

    private func cleanup() {
        isSpeaking = false
        panel = nil
        trackingView = nil
        currentText = ""
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Timers

    private func startHoverTimer() {
        // While speaking, hover must not re-trigger translation (the click
        // already consumed the interaction and the panel must stay closed).
        guard !isSpeaking else { return }
        cancelHoverTimer()
        cancelAutoDismissTimer()
        let delayMs = min(max(Defaults[.hoverDelayMs], 100), 1000)
        hoverTimer = Timer.scheduledTimer(withTimeInterval: Double(delayMs) / 1000, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.triggerTranslation()
            }
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func startAutoDismissTimer() {
        // While speaking the icon must stay visible so the user can click
        // again to stop playback.
        guard !isSpeaking else { return }
        cancelAutoDismissTimer()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func cancelAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }

    private func cancelAllTimers() {
        cancelHoverTimer()
        cancelAutoDismissTimer()
    }

    /// Click handling (TransPeek Phase 1). In click-activation mode the click
    /// always means translate — that mode's whole point is click-to-translate.
    /// In hover mode the click action follows `triggerClickAction`: `.speak`
    /// cancels both timers and speaks immediately without opening the panel
    /// (a second click while speaking stops playback); `.translate` keeps the
    /// old behaviour.
    private func handleIconClick() {
        guard activationMode != .click else {
            triggerTranslation()
            return
        }
        switch Defaults[.triggerClickAction] {
        case .speak:
            if isSpeaking {
                onStopSpeakRequested?()
                setSpeaking(false)
            } else {
                cancelAllTimers()
                setSpeaking(true)
                onSpeakRequested?(currentText)
            }
        case .translate:
            triggerTranslation()
        }
    }

    private func triggerTranslation() {
        let text = currentText
        cancelAllTimers()

        guard let panel else { return }
        // Immediately hide the icon
        panel.contentView = nil
        panel.close()
        cleanup()

        onTranslateRequested?(text)
    }
}
