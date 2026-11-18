import AppKit
import Defaults

// MARK: - TriggerTrackingView

/// A circular icon view with mouse tracking for hover and click detection.
@MainActor
final class TriggerTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    /// The mouse-down event, so the controller can tell a plain click from
    /// an Option-click (which runs the *other* click action).
    var onMouseDown: ((NSEvent) -> Void)?
    /// A right-click (Control-click / two-finger tap) opens the icon menu.
    var onRightMouseDown: ((NSEvent) -> Void)?

    /// When true the icon shows a speaker symbol (TTS playing) instead of the bubble.
    var isSpeaking = false {
        didSet {
            if isSpeaking != oldValue {
                needsDisplay = true
            }
        }
    }

    /// What a plain click on this icon does — the glyph shows it, so the
    /// user can tell at a glance: bubble = translate/speak, A+ = Fast
    /// Read (Manh 2026-11-18). Updated when the icon is shown (it follows
    /// the Settings "Click icon" choice).
    var clickAction: TriggerClickAction = .speak {
        didSet {
            if clickAction != oldValue {
                needsDisplay = true
            }
        }
    }

    /// How the icon is triggered (hover = click does the Settings action;
    /// click = click always translates). The Option preview only flips the
    /// glyph in hover mode, matching `handleIconClick` in the controller.
    var activationMode: TriggerActivationMode = .hover

    /// Whether the Option key is currently held. While held, the glyph
    /// shows the *other* click action (the one Option+click will run), so
    /// the user sees what the next click will do before clicking (Manh
    /// 2026-11-18, style B). Updated by the controller's flags-changed
    /// monitor while the icon is visible.
    var isOptionHeld = false {
        didSet {
            if isOptionHeld != oldValue {
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

        // Glyph — always shows what the *next* click will do (Manh
        // 2026-11-17, extended 2026-11-18 style B). In hover mode, holding
        // Option flips to the other action, so the user sees the preview
        // before clicking; in click mode the click always translates, so
        // there is nothing to preview.
        let effectiveAction: TriggerClickAction
        if activationMode == .hover && isOptionHeld {
            effectiveAction = clickAction == .read ? .speak : .read
        } else {
            effectiveAction = clickAction
        }

        if effectiveAction == .read {
            // Fast Read → turmeric "A+" (bold A + small + badge at its
            // top-right, Manh 2026-11-18). A custom-drawn glyph, not an
            // SF Symbol — there is no A+ symbol.
            drawFastReadGlyph(in: bounds)
            return
        }

        // SF Symbol icon — speaker while TTS is playing, bubble otherwise
        // (bubble = translate/speak). The bubble glyph is ocean blue
        // (.systemBlue) so the icon stays easy to spot in both light
        // and dark mode; the circle background keeps adapting to the system
        // appearance — never a solid blue fill, which would hide the glyph.
        let symbolName: String
        let symbolColor: NSColor
        if isSpeaking {
            symbolName = "speaker.wave.2.fill"
            symbolColor = .controlAccentColor
        } else {
            symbolName = "character.bubble"
            symbolColor = .systemBlue
        }
        let accessibilityDescription = isSpeaking ? "Stop speaking" : "Translate"
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: symbolColor)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
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

    /// Turmeric (màu nghệ) — the Fast Read "A+" glyph color (Manh
    /// 2026-11-18). A deep golden amber, readable on both the light and
    /// dark circle backgrounds (a bright turmeric would wash out on light).
    private static let fastReadTurmeric = NSColor(red: 0.78, green: 0.50, blue: 0.05, alpha: 1.0)

    /// Draw the Fast Read glyph: a bold "A" with a small "+" badge at its
    /// top-right corner (Manh 2026-11-18: "chữ A+ có dấu + góc trên phải").
    /// Drawn as text into the current graphics context — there is no A+
    /// SF Symbol.
    private func drawFastReadGlyph(in bounds: NSRect) {
        let turmeric = Self.fastReadTurmeric
        let aFont = NSFont.boldSystemFont(ofSize: 15)
        let aAttrs: [NSAttributedString.Key: Any] = [
            .font: aFont,
            .foregroundColor: turmeric
        ]
        let aString = NSAttributedString(string: "A", attributes: aAttrs)
        let aSize = aString.size()
        let aOrigin = NSPoint(
            x: bounds.midX - aSize.width / 2,
            y: bounds.midY - aSize.height / 2
        )
        aString.draw(at: aOrigin)

        // Small "+" badge, centred on the A’s top-right corner.
        let plusFont = NSFont.boldSystemFont(ofSize: 8)
        let plusAttrs: [NSAttributedString.Key: Any] = [
            .font: plusFont,
            .foregroundColor: turmeric
        ]
        let plusString = NSAttributedString(string: "+", attributes: plusAttrs)
        let plusSize = plusString.size()
        let plusOrigin = NSPoint(
            x: aOrigin.x + aSize.width - plusSize.width / 2,
            y: aOrigin.y + aSize.height - plusSize.height / 2
        )
        plusString.draw(at: plusOrigin)
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

    override func rightMouseDown(with event: NSEvent) {
        onRightMouseDown?(event)
    }
}

// MARK: - TriggerIconController

/// Manages the trigger icon lifecycle: show near cursor, hover/click to translate, auto-dismiss.
///
/// Inherits NSObject so the right-click menu items can target it with
/// @objc actions.
@MainActor
final class TriggerIconController: NSObject {
    var onTranslateRequested: ((String) -> Void)?
    /// Click-to-speak (TransPeek Phase 1): invoked with the selected text when the
    /// user clicks the icon while `triggerClickAction` is `.speak`. The panel is
    /// not opened for this path.
    var onSpeakRequested: ((String) -> Void)?
    /// Second click while speaking: the app should stop playback.
    var onStopSpeakRequested: (() -> Void)?
    /// Fast Read (RSVP, Manh 2026-11-17): invoked with the selected text when
    /// the user clicks the icon while `triggerClickAction` is `.read`, or
    /// Option-clicks it while the click action is `.speak` / `.translate`.
    /// The panel is not opened for this path.
    var onReadRequested: ((String) -> Void)?
    /// The icon menu's "Settings..." item.
    var onOpenSettingsRequested: (() -> Void)?
    var onDismissed: (() -> Void)?

    /// True while click-to-speak playback is in progress. The icon shows a
    /// speaker symbol and does not auto-dismiss until playback stops.
    private(set) var isSpeaking = false {
        didSet { trackingView?.isSpeaking = isSpeaking }
    }

    /// Set the speaking state and redraw the icon. While speaking the icon does
    /// not auto-dismiss; when speaking stops the 5s auto-dismiss timer restarts
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
    /// Local monitor for Option-key changes while the icon is visible
    /// (Manh 2026-11-18, style B): flips the glyph to the other action
    /// the moment Option is held/released.
    private var flagsMonitor: Any?
    /// Delayed-hide timer after a Fast Read click (Manh 2026-11-18): the
    /// icon stays showing the turmeric "A+" for 2.5s as a confirmation
    /// while the Read window opens, then hides.
    private var readHideTimer: Timer?
    /// True while a Fast Read open is pending (the 2.5s A+ confirmation):
    /// further clicks are ignored so a double-click cannot open two Read
    /// windows or start speaking over the Read window.
    private var isReadPending = false

    /// Show the trigger icon near the given screen point.
    /// If already visible, silently replace without triggering suppress.
    func show(text: String, near point: CGPoint) {
        // Silently close any existing icon (no dismiss callback)
        dismissSilently()

        currentText = text
        isSpeaking = false

        let panel = TriggerIconPanel()
        let trackingView = TriggerTrackingView(frame: NSRect(x: 0, y: 0, width: TriggerIconPanel.size, height: TriggerIconPanel.size))
        trackingView.clickAction = Defaults[.triggerClickAction]

        let activationMode = Defaults[.triggerActivationMode]
        self.activationMode = activationMode
        trackingView.activationMode = activationMode
        // If Option is already held when the icon appears, show the other
        // action's glyph right away (Manh 2026-11-18, style B).
        trackingView.isOptionHeld = NSEvent.modifierFlags.contains(.option)

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
        trackingView.onMouseDown = { [weak self] event in
            self?.handleIconClick(event: event)
        }
        trackingView.onRightMouseDown = { [weak self] event in
            self?.showContextMenu(for: event)
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

        // Option-key preview (Manh 2026-11-18, style B): while the icon is
        // visible, track the Option key so the glyph flips to the other
        // action the moment Option is held/released. Removed in cleanup().
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                guard let self, let trackingView = self.trackingView else { return }
                trackingView.isOptionHeld = event.modifierFlags.contains(.option)
            }
            return event
        }

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
        isReadPending = false
        readHideTimer?.invalidate()
        readHideTimer = nil
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
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
        // Auto-hide delay from Settings (default 5s, range 3–10s; was a
        // hardcoded 3.0s, raised to 5.0s 2026-11-17 ~20:38, then made
        // adjustable 2026-11-17 ~21:01). Long enough to reach the icon,
        // short enough not to linger.
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

    private func cancelAllTimers() {
        cancelHoverTimer()
        cancelAutoDismissTimer()
    }

    /// Click handling (TransPeek Phase 1, extended with Fast Read 2026-11-17).
    /// In click-activation mode the click always means translate — that mode's
    /// whole point is click-to-translate.
    /// In hover mode the click action follows `triggerClickAction`, and
    /// Option+click runs the *other* action: when the plain click speaks,
    /// Option+click opens Fast Read; when the plain click opens Fast Read,
    /// Option+click speaks (the translate action is reachable from the
    /// right-click menu instead).
    private func handleIconClick(event: NSEvent) {
        // While a Fast Read open is pending (the 2.5s A+ confirmation),
        // ignore further clicks so a double-click cannot open two Read
        // windows or start speaking over the Read window (Manh 2026-11-18).
        guard !isReadPending else { return }
        guard activationMode != .click else {
            triggerTranslation()
            return
        }
        let optionClicked = event.modifierFlags.contains(.option)
        let action = Defaults[.triggerClickAction]
        let effectiveAction: TriggerClickAction
        if optionClicked {
            effectiveAction = action == .read ? .speak : .read
        } else {
            effectiveAction = action
        }
        switch effectiveAction {
        case .speak:
            if isSpeaking {
                onStopSpeakRequested?()
                setSpeaking(false)
            } else {
                cancelAllTimers()
                setSpeaking(true)
                onSpeakRequested?(currentText)
            }
        case .read:
            performRead()
        case .translate:
            triggerTranslation()
        }
    }

    /// Open Fast Read with the selected text. The Read window opens
    /// immediately, but the icon stays visible showing the turmeric "A+"
    /// for 2.5s (Manh 2026-11-18: 2–3s) as a confirmation while the window
    /// is still opening, then it hides — so the user knows the click
    /// landed even before the window appears.
    private func performRead() {
        // Ignore a second Read (menu or double-click) while the delayed
        // hide is pending, so two Read windows cannot open.
        guard !isReadPending else { return }
        let text = currentText
        cancelAllTimers()
        guard panel != nil else { return }
        isReadPending = true
        onReadRequested?(text)
        readHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.readHideTimer = nil
                self.isReadPending = false
                guard let panel = self.panel else { return }
                panel.contentView = nil
                panel.close()
                self.cleanup()
            }
        }
    }

    /// Right-click (Control-click / two-finger tap) menu: Translate / Speak /
    /// Fast Read / Settings — the discoverable way to reach the action the
    /// plain click is not set to (Manh 2026-11-17).
    private func showContextMenu(for event: NSEvent) {
        cancelHoverTimer()
        let menu = NSMenu()
        let translateItem = NSMenuItem(title: "Translate", action: #selector(menuTranslate), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        let speakItem = NSMenuItem(title: "Speak", action: #selector(menuSpeak), keyEquivalent: "")
        speakItem.target = self
        menu.addItem(speakItem)
        let readItem = NSMenuItem(title: "Fast Read", action: #selector(menuRead), keyEquivalent: "")
        readItem.target = self
        menu.addItem(readItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuOpenSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        NSMenu.popUpContextMenu(menu, with: event, for: trackingView ?? NSView())
    }

    @objc private func menuTranslate() {
        triggerTranslation()
    }

    @objc private func menuSpeak() {
        cancelAllTimers()
        setSpeaking(true)
        onSpeakRequested?(currentText)
    }

    @objc private func menuRead() {
        performRead()
    }

    @objc private func menuOpenSettings() {
        dismiss()
        onOpenSettingsRequested?()
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
