import AppKit
import AVFoundation
import Defaults

/// Which Fast Read surface the alternative icon was shown from.
/// Hover-translate differs per surface (design doc §5): Window Read
/// opens the panel, Lite only switches the already-open panel to the
/// center tab.
enum AlternativeIconSurface {
    case windowRead
    case lite
}

/// The alternative icon: a fake float icon that appears when the user
/// selects text inside Fast Read (Window Read or panel right). A
/// SEPARATE path from the real float icon (`TriggerIconController`) —
/// it does not touch that logic; it only delegates hover (translate)
/// and click (speak) through the callbacks AppDelegate wires up.
/// See docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md.
@MainActor
final class AlternativeIconController {
    /// Hover → translate the selected word. AppDelegate implements it
    /// per surface: Window Read translates and opens the panel at the
    /// cursor; Lite translates only (the panel follows `sourceText` to
    /// the center tab — calling showAtCursor there would move it).
    var onTranslateRequested: ((String, AlternativeIconSurface) -> Void)?
    /// Which language to speak the selected text in. AppDelegate wires
    /// this to its language detection (`speakLanguage(for:)`).
    var speakLanguageProvider: ((String) -> String)?

    /// True while the icon's own TTS is speaking. The icon shows a
    /// speaker glyph and does not auto-dismiss until playback stops.
    private(set) var isSpeaking = false {
        didSet { iconView?.isSpeaking = isSpeaking }
    }

    private var panel: NSPanel?
    private var iconView: AlternativeIconView?
    private var currentText: String = ""
    private var currentSurface: AlternativeIconSurface = .windowRead
    private var hoverTimer: Timer?
    private var autoDismissTimer: Timer?
    /// The icon's own speech synthesizer (design doc §6): a SEPARATE
    /// system-TTS path from the Read speaker button, which drives RSVP
    /// playback sync through the shared TTSCoordinator. This one just
    /// speaks the selected text and never touches RSVP playback state.
    private let synthesizer = AVSpeechSynthesizer()
    private var speechDelegate: AlternativeIconSpeechDelegate?
    /// Delegates whose speech was stopped (or replaced) but whose
    /// didFinish/didCancel callback has not fired yet. Kept alive so
    /// Apple's TextToSpeech framework never retains a freed delegate
    /// (crash 2026-11-22, build 342: EXC_BAD_ACCESS in objc_retain —
    /// the delegate was nil-ed on stop while the framework's didCancel
    /// was still pending). Each delegate leaves this list when its own
    /// callback fires (speechDidFinish).
    private var retiredDelegates: [AlternativeIconSpeechDelegate] = []

    /// Show the icon near the given screen point. Replaces any icon
    /// already visible (silently, no dismiss callback).
    func show(text: String, near point: CGPoint, surface: AlternativeIconSurface) {
        dismissSilently()

        currentText = text
        currentSurface = surface
        isSpeaking = false

        // Size follows the auto-show (hover) icon size — the alternative
        // icon is an auto-show icon too, so it tracks that setting
        // (default 24pt, user-adjustable in Settings).
        let size = TriggerIconPanel.compactSize
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let iconView = AlternativeIconView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        iconView.onMouseEntered = { [weak self] in
            guard let self else { return }
            self.cancelAutoDismissTimer()
            self.startHoverTimer()
        }
        iconView.onMouseExited = { [weak self] in
            guard let self else { return }
            self.cancelHoverTimer()
            self.startAutoDismissTimer()
        }
        iconView.onMouseDown = { [weak self] _ in
            self?.handleIconClick()
        }
        panel.contentView = iconView

        // Position: offset to the right and below the cursor (same as
        // the real icon), clamped to the screen.
        let offset: CGFloat = 8
        var x = point.x + offset
        var y = point.y - offset - size
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
        self.iconView = iconView
        startAutoDismissTimer()
    }

    /// Whether the given screen point is on this icon (so the selection
    /// monitor can ignore mouse-ups on the icon itself).
    func contains(_ point: CGPoint) -> Bool {
        guard let panel else { return false }
        return panel.frame.contains(point)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Dismiss the icon with fade-out.
    func dismiss() {
        guard let panel else { return }
        stopSpeaking()
        cancelHoverTimer()
        cancelAutoDismissTimer()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                panel.contentView = nil
                panel.close()
                self?.cleanup()
            }
        })
    }

    /// Dismiss silently — used when replacing with a new icon.
    func dismissSilently() {
        guard let panel else { return }
        stopSpeaking()
        cancelHoverTimer()
        cancelAutoDismissTimer()
        panel.contentView = nil
        panel.close()
        cleanup()
    }

    private func cleanup() {
        isSpeaking = false
        panel = nil
        iconView = nil
        currentText = ""
    }

    // MARK: - Hover (translate)

    /// Hover → translate, after the same hover delay as the real icon
    /// (Settings "Hover delay", default 500ms) — so a passing mouse
    /// does not trigger a lookup. While speaking, hover must not
    /// re-trigger translation (the click already consumed the
    /// interaction).
    private func startHoverTimer() {
        guard !isSpeaking else { return }
        cancelHoverTimer()
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

    /// Translate the selected word. The icon dismisses first (like the
    /// real icon — the panel takes over from here), then the text and
    /// surface go to AppDelegate, which translates and opens or
    /// switches the panel per surface.
    private func triggerTranslation() {
        let text = currentText
        let surface = currentSurface
        dismissSilently()
        onTranslateRequested?(text, surface)
    }

    // MARK: - Click (speak, separate TTS path)

    /// Click → speak the selected text through the icon's own
    /// synthesizer. A second click while speaking stops it. There is
    /// NO Read action here (design doc §4): the user selected one word
    /// inside a long passage, so a Fast Read session on that fragment
    /// would lose the long context.
    private func handleIconClick() {
        if isSpeaking {
            stopSpeaking()
            return
        }
        speakCurrentText()
    }

    private func speakCurrentText() {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancelAutoDismissTimer()
        cancelHoverTimer()
        let utterance = AVSpeechUtterance(string: text)
        let lang = speakLanguageProvider?(text) ?? "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        let delegate = AlternativeIconSpeechDelegate { [weak self] finished in
            Task { @MainActor in
                self?.speechDidFinish(finished)
            }
        }
        // Retire the previous delegate (if its didCancel is still
        // pending, keep it alive in retiredDelegates until its callback
        // fires — see the property comment for the crash this prevents).
        if let old = speechDelegate {
            retiredDelegates.append(old)
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func stopSpeaking() {
        guard isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        // Do NOT nil speechDelegate here — the framework's didCancel
        // callback is still pending (it runs later on the main queue)
        // and retains the delegate; freeing it now is the crash
        // (2026-11-22, build 342). speechDidFinish (from didCancel)
        // clears it once the framework has confirmed the speech ended.
        if panel != nil {
            startAutoDismissTimer()
        }
    }

    private func speechDidFinish(_ finished: AlternativeIconSpeechDelegate) {
        // Drop the finished delegate from the retired list (if it was
        // retired) or clear the current one — its speech is done, so
        // the framework holds no more callbacks for it.
        retiredDelegates.removeAll { $0 === finished }
        if speechDelegate === finished {
            speechDelegate = nil
        }
        isSpeaking = false
        if panel != nil {
            startAutoDismissTimer()
        }
    }

    // MARK: - Auto-dismiss

    private func startAutoDismissTimer() {
        // While speaking the icon must stay visible so the user can
        // click again to stop playback.
        guard !isSpeaking else { return }
        cancelAutoDismissTimer()
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

/// AVSpeechSynthesizerDelegate that reports when the utterance ends
/// (finished or cancelled) so the icon can clear its speaking state.
/// A tiny class because AVSpeechSynthesizer takes a delegate object.
/// The callback passes the delegate itself, so the controller can drop
/// exactly that delegate from its retired list (see
/// AlternativeIconController.retiredDelegates).
private final class AlternativeIconSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: (AlternativeIconSpeechDelegate) -> Void

    init(onFinish: @escaping (AlternativeIconSpeechDelegate) -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish(self)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish(self)
    }
}
