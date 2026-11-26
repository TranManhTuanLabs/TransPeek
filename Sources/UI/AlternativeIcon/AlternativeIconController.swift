import AppKit
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
    /// Click → start a click-to-listen session (new speaker law, Manh
    /// 2026-11-27): AppDelegate starts it through the shared chaining
    /// controller — the same flow as the real float icon — so the
    /// SEPARATE speak indicator appears at this icon's frame and owns
    /// pause/resume. The icon itself never speaks and never shows
    /// playback state (it always keeps its blue A glyph).
    var onSpeakRequested: ((String) -> Void)?

    private var panel: NSPanel?
    private var iconView: AlternativeIconView?
    private var currentText: String = ""
    private var currentSurface: AlternativeIconSurface = .windowRead
    private var hoverTimer: Timer?
    private var autoDismissTimer: Timer?

    /// The icon's current frame — the speak indicator appears exactly
    /// where the icon stood when the user clicked it (same pattern as
    /// the real float icon's `currentFrame`).
    var currentFrame: CGRect? {
        panel?.frame
    }

    /// Show the icon near the given screen point. Replaces any icon
    /// already visible (silently, no dismiss callback).
    func show(text: String, near point: CGPoint, surface: AlternativeIconSurface) {
        dismissSilently()

        currentText = text
        currentSurface = surface

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
        cancelHoverTimer()
        cancelAutoDismissTimer()
        panel.contentView = nil
        panel.close()
        cleanup()
    }

    private func cleanup() {
        panel = nil
        iconView = nil
        currentText = ""
    }

    // MARK: - Hover (translate)

    /// Hover → translate, after the same hover delay as the real icon
    /// (Settings "Hover delay", default 500ms) — so a passing mouse
    /// does not trigger a lookup.
    private func startHoverTimer() {
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

    // MARK: - Click (speak, shared flow)

    /// Click → start a click-to-listen session through AppDelegate
    /// (the shared chaining controller + separate speak indicator —
    /// the same flow as the real float icon). The icon does NOT dismiss
    /// itself here: AppDelegate reads the frame first (for the
    /// indicator), then dismisses it. Clicking again (a new selection)
    /// while a session plays starts a NEW session replacing the old
    /// one — pause/resume is the indicator's job. There is NO Read
    /// action here (design doc §4): the user selected one word inside
    /// a long passage, so a Fast Read session on that fragment would
    /// lose the long context.
    private func handleIconClick() {
        onSpeakRequested?(currentText)
    }

    // MARK: - Auto-dismiss

    /// The icon follows its normal lifecycle at all times — the session
    /// is owned by the separate speak indicator, not by this icon, so
    /// the icon auto-hides after the Settings delay even while a
    /// session plays (hover pauses the timer, like the real icon).
    private func startAutoDismissTimer() {
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
