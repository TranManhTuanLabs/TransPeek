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

    /// When true the icon shows a speaker symbol (TTS playing) instead of
    /// the plain A (Manh 2026-11-18, round 7: speaking wins the glyph so
    /// the user can click again to stop it).
    var isSpeaking = false {
        didSet {
            if isSpeaking != oldValue {
                needsDisplay = true
            }
        }
    }

    /// What a plain click on this icon does — it decides the Option+Click
    /// preview (Option held flips to the other action) and what a click
    /// does. Updated when the icon is shown (it follows the Settings
    /// "Click icon for:" choice). Default `.read` to match the Defaults
    /// key's default (the old `.speak` initial value was an upstream
    /// leftover — the setting default has been Read since 2026-11-18).
    var clickAction: TriggerClickAction = .read {
        didSet {
            if clickAction != oldValue {
                needsDisplay = true
            }
        }
    }

    /// True while a Fast Read open is pending (the 2.5s A+ confirmation
    /// after a Read click, Manh 2026-11-18): the glyph stays on A+ so the
    /// user knows the click landed, even though the idle glyph is the
    /// plain A (translate-first, Manh 2026-11-20). Set by the controller.
    var isReadPending = false {
        didSet {
            if isReadPending != oldValue {
                needsDisplay = true
            }
        }
    }

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

        // Glyph — translate-first (Manh 2026-11-20): the idle icon is
        // ALWAYS the plain translate A (Style 1), for both Click
        // settings — hover is the icon's primary job. The old Style B
        // preview (idle A+ for Click=Read, idle speaker for
        // Click=Speak) was removed 2026-11-20; it was a deviation added
        // to make the Click setting visible at a glance, and it confused
        // the flow with the upstream (MoePeek) activation logic.
        // The glyph only leaves the plain A to show: the Option+Click
        // preview (while Option is held), the speaking state, or the
        // 2.5s A+ confirmation after a Read click.
        //
        // Speaking comes FIRST (Manh 2026-11-18, round 7): while TTS is
        // playing the icon must show the speaker, so the user can click
        // again to stop it — even when the click action is Read. Before
        // this fix the `.read` branch below returned early, so after an
        // Option+click to Speak (with Click = Read) the icon stayed on
        // A+ once Option was released, instead of switching to the
        // speaker, and the user had no way to tell speech was playing.
        if isSpeaking {
            // TTS playing — speaker glyph (click again to stop).
            drawSpeakerGlyph(in: bounds)
            return
        }

        if isReadPending {
            // Fast Read click landed — turmeric "A+" for 2.5s as a
            // confirmation while the Read window opens (Manh 2026-11-18).
            drawFastReadGlyph(in: bounds)
            return
        }

        if isOptionHeld {
            // Option+Click preview — the OTHER action (Manh 2026-11-18,
            // style B, kept): when the plain click reads, Option+click
            // speaks (speaker); when the plain click speaks,
            // Option+click opens Fast Read (A+).
            if clickAction == .read {
                drawSpeakerGlyph(in: bounds)
            } else {
                drawFastReadGlyph(in: bounds)
            }
            return
        }

        // Idle — plain blue "A" (Style 1, Manh 2026-11-20). The chat
        // bubble (`character.bubble`, Style 2) is NOT the translate
        // icon — it was the upstream original, only a temporary
        // stand-in, documented in
        // docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md §3.
        drawPlainAGlyph(in: bounds)
    }

    /// Draw the speaker glyph (`speaker.wave.2.fill`, accent color) —
    /// used both while TTS is playing (click again to stop) and as the
    /// Speak preview (Manh 2026-11-19, 0.1.5).
    private func drawSpeakerGlyph(in bounds: NSRect) {
        let symbolName = "speaker.wave.2.fill"
        let symbolColor = NSColor.controlAccentColor
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
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
    /// blue (Style 1, Manh 2026-11-19, 0.1.5). Drawn as text into the
    /// current graphics context — there is no plain-A SF Symbol.
    /// The blue is the color of the letter A itself.
    private func drawPlainAGlyph(in bounds: NSRect) {
        let aFont = NSFont.systemFont(ofSize: 15)
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
    /// Option-clicks it while the click action is `.speak`.
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
    private var hoverTimer: Timer?
    private var autoDismissTimer: Timer?
    /// Poll timer for the Option key while the icon is visible (Manh
    /// 2026-11-18, style B): flips the glyph to the other action the
    /// moment Option is held/released. A LOCAL flags monitor does NOT
    /// work here — the user selects text in ANOTHER app, so the Option
    /// press is delivered to that app, not to TransPeek, and the local
    /// monitor never fires (Manh 2026-11-18: holding Opt changed
    /// nothing until the mouse hovered the icon, because only the
    /// mouse-enter re-check reads the key state). Polling
    /// `NSEvent.modifierFlags` reads the global hardware state
    /// directly, so it works no matter which app is frontmost. Fires
    /// every 0.1s; only acts when the state actually changed, so the
    /// auto-hide timer is never reset by a no-change poll.
    private var optionPollTimer: Timer?
    /// Last Option state seen by the poll timer (change detection).
    private var lastOptionHeld = false
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
    /// `compact` (Manh 2026-11-21): the block-text hover icon is smaller
    /// than the selection icon — it appears often (every text block), so
    /// a compact icon stays out of the mouse's way. The selection icon
    /// keeps the full size.
    func show(text: String, near point: CGPoint, compact: Bool = false) {
        // Silently close any existing icon (no dismiss callback)
        dismissSilently()

        currentText = text
        isSpeaking = false

        // The panel size: compact for the hover icon, full for selection.
        let size = compact ? TriggerIconPanel.compactSize : TriggerIconPanel.size

        let panel = TriggerIconPanel()
        let trackingView = TriggerTrackingView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        trackingView.clickAction = Defaults[.triggerClickAction]

        // The icon is always hover (Manh 2026-11-20): the old upstream
        // activation mode (hover / click) was removed.
        // If Option is already held when the icon appears, show the other
        // action's glyph right away (Manh 2026-11-18, style B).
        trackingView.isOptionHeld = NSEvent.modifierFlags.contains(.option)

        trackingView.onMouseEntered = { [weak self] in
            guard let self else { return }
            // Re-check Option in case a flags-changed event was missed, so
            // the glyph preview is correct the moment the cursor arrives.
            self.trackingView?.isOptionHeld = NSEvent.modifierFlags.contains(.option)
            self.startHoverTimer()
        }
        trackingView.onMouseExited = { [weak self] in
            guard let self else { return }
            self.cancelHoverTimer()
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
        // visible, poll the Option key so the glyph flips to the other
        // action the moment Option is held/released. updateOptionPreview
        // also pauses the auto-hide while Option is held, so the A+
        // preview doesn't vanish before the user can click it (Manh
        // 2026-11-18: A+ rarely seen — with Click = Speak the A+ only
        // shows while Option is held, and the 5s auto-hide used to steal
        // it). See optionPollTimer: a local flags monitor can't see the
        // key (it goes to the app where the text was selected), so the
        // preview is polled instead. Stopped in cleanup().
        startOptionPollTimer()

        startAutoDismissTimer()
        // If Option is already held when the icon appears, the preview is
        // already showing — pause the auto-hide so it doesn't steal it.
        // (The poll timer's first fire would do this too, but the pause
        // belongs here so the icon never gets a 5s timer it doesn't need.)
        lastOptionHeld = trackingView.isOptionHeld
        if trackingView.isOptionHeld {
            cancelAutoDismissTimer()
        }
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
        optionPollTimer?.invalidate()
        optionPollTimer = nil
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

    /// Start polling the Option key (0.1s) while the icon is visible.
    /// Reads `NSEvent.modifierFlags` — the global hardware state, so it
    /// works even when another app is frontmost (where the text was
    /// selected). Only acts when the state actually changed, so a
    /// no-change poll never resets the auto-hide timer. Stopped in
    /// cleanup(). See optionPollTimer for why a local flags monitor
    /// can't do this job.
    private func startOptionPollTimer() {
        optionPollTimer?.invalidate()
        optionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.trackingView != nil else { return }
                let optionHeld = NSEvent.modifierFlags.contains(.option)
                guard optionHeld != self.lastOptionHeld else { return }
                self.lastOptionHeld = optionHeld
                self.updateOptionPreview(optionHeld: optionHeld)
            }
        }
    }

    /// Update the Option preview: flip the glyph to the other action and
    /// pause the auto-hide while Option is held so the preview (A+ /
    /// speaker) stays visible long enough to see and click (Manh
    /// 2026-11-18: with Click = Speak the A+ only shows while Option is
    /// held, and the 5s auto-hide used to steal it — A+ was rarely seen).
    /// On release, restart the auto-hide so the icon still goes away.
    /// Skipped while a Read open is pending (the 2.5s A+ confirmation
    /// has its own hide timer).
    private func updateOptionPreview(optionHeld: Bool) {
        trackingView?.isOptionHeld = optionHeld
        guard !isReadPending else { return }
        if optionHeld {
            cancelAutoDismissTimer()
        } else {
            startAutoDismissTimer()
        }
    }

    private func cancelAllTimers() {
        cancelHoverTimer()
        cancelAutoDismissTimer()
    }

    /// Click handling (TransPeek Phase 1, extended with Fast Read 2026-11-17).
    /// The click action follows `triggerClickAction`, and Option+click runs
    /// the *other* action: when the plain click speaks, Option+click opens
    /// Fast Read; when the plain click opens Fast Read, Option+click speaks
    /// (Translate is hover-only — there is no Translate click action,
    /// Manh 2026-11-20; the old click-activation mode that made a click
    /// always translate was removed the same day).
    private func handleIconClick(event: NSEvent) {
        // While a Fast Read open is pending (the 2.5s A+ confirmation),
        // ignore further clicks so a double-click cannot open two Read
        // windows or start speaking over the Read window (Manh 2026-11-18).
        guard !isReadPending else { return }
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
        // The view shows A+ while a Read open is pending (the 2.5s
        // confirmation), even though the idle glyph is the plain A
        // (translate-first, Manh 2026-11-20).
        trackingView?.isReadPending = true
        onReadRequested?(text)
        readHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.readHideTimer = nil
                self.isReadPending = false
                self.trackingView?.isReadPending = false
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
