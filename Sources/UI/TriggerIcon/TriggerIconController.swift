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
    /// user can tell at a glance: bubble = translate/speak, book = Fast
    /// Read. Updated when the icon is shown (it follows the Settings
    /// "Click icon" choice).
    var clickAction: TriggerClickAction = .speak {
        didSet {
            if clickAction != oldValue {
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

        // SF Symbol icon — speaker while TTS is playing, book pages when a
        // plain click opens Fast Read, bubble otherwise. The glyph always
        // shows what a plain click will do, so the user never clicks the
        // wrong action (Manh 2026-11-17). The bubble/book glyph is ocean
        // blue (.systemBlue) so the icon stays easy to spot in both light
        // and dark mode; the circle background keeps adapting to the system
        // appearance — never a solid blue fill, which would hide the glyph.
        let symbolName: String
        let symbolColor: NSColor
        if isSpeaking {
            symbolName = "speaker.wave.2.fill"
            symbolColor = .controlAccentColor
        } else if clickAction == .read {
            symbolName = "book.pages"
            symbolColor = .systemBlue
        } else {
            symbolName = "character.bubble"
            symbolColor = .systemBlue
        }
        let accessibilityDescription = isSpeaking ? "Stop speaking" : (clickAction == .read ? "Fast Read" : "Translate")
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
        trackingView.clickAction = Defaults[.triggerClickAction]

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

    /// Click handling (TransPeek Phase 1, extended with Fast Read 2026-11-17).
    /// In click-activation mode the click always means translate — that mode's
    /// whole point is click-to-translate.
    /// In hover mode the click action follows `triggerClickAction`, and
    /// Option+click runs the *other* action: when the plain click speaks,
    /// Option+click opens Fast Read; when the plain click opens Fast Read,
    /// Option+click speaks (the translate action is reachable from the
    /// right-click menu instead).
    private func handleIconClick(event: NSEvent) {
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

    /// Open Fast Read with the selected text: dismiss the icon (no panel)
    /// and hand the text to the app.
    private func performRead() {
        let text = currentText
        cancelAllTimers()
        guard let panel else { return }
        panel.contentView = nil
        panel.close()
        cleanup()
        onReadRequested?(text)
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
