import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Manages the lifecycle and positioning of the popup translation panel.
@MainActor
final class PopupPanelController {
    var onDismiss: (() -> Void)?
    /// Called when a panel OCR run in copy-only mode actually copied text,
    /// so the app can show the "Copied" toast (set by AppDelegate).
    var onOCRCopyOnlySuccess: (() -> Void)?
    /// Called when the "?" shortcuts panel's Run button is clicked (set by
    /// AppDelegate): runs the named shortcut through the same dispatch the
    /// physical hotkeys use (AppDelegate.performShortcut).
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?
    /// Called when the panel's "Fast Read" button is clicked (set by
    /// AppDelegate): opens the RSVP reading window with the text being
    /// translated (Manh 2026-11-17).
    var onFastRead: ((String) -> Void)?

    private var panel: PopupPanel?
    private var dismissMonitor: PopupDismissMonitor?
    /// Tracks the language picker's popover window so the dismiss monitor
    /// treats clicks in it as clicks inside the panel (Manh 2026-11-19,
    /// 0.1.5). One tracker for the panel's lifetime; the picker sets its
    /// window when the popover opens and clears it when it closes.
    private let languagePopoverTracker = LanguagePopoverTracker()
    private var copyShortcutDismissTask: Task<Void, Never>?
    private var resultLayout = PopupResultLayout()
    private var resizeTask: Task<Void, Never>?
    /// Set when auto-fit retried once for missing measurements (report P2);
    /// cleared when a resize runs with valid measurements, so each new
    /// episode gets one retry.
    private var resizeRetryUsed = false

    private let coordinator: TranslationCoordinator
    private let ttsCoordinator: TTSCoordinator?
    private let settingsController: SettingsWindowController?
    /// Focus timer store (Manh 2026-11-20, focus timer + panel decor):
    /// one store for the app — the panel-left card, the panel-right
    /// reading view, and the Rest window all read the same state.
    private let focusTimerStore: FocusTimerStore

    /// The app that was frontmost before we activated ourselves for input mode.
    private var previouslyActiveApp: NSRunningApplication?

    init(
        coordinator: TranslationCoordinator,
        ttsCoordinator: TTSCoordinator? = nil,
        settingsController: SettingsWindowController? = nil,
        // Default is a fresh store (tests construct the controller
        // without one); the app passes its shared store.
        focusTimerStore: FocusTimerStore = FocusTimerStore()
    ) {
        self.coordinator = coordinator
        self.ttsCoordinator = ttsCoordinator
        self.settingsController = settingsController
        self.focusTimerStore = focusTimerStore
    }

    deinit {
        resizeTask?.cancel()
    }

    func showAtCursor() {
        let initialSize = setupPanel()
        guard let panel else { return }

        // Coordinator auto-unpins on non-nil globalError via didSet, so checking isPinned alone is safe.
        if coordinator.isPinned, panel.isVisible {
            panel.orderFront(nil)
            startDismissMonitor()
            return
        }

        // The panel always opens at the cursor (Manh 2026-11-17: the
        // "Remember Last Popup Position" setting was removed — with
        // auto-fit on every open and Settings-only default size, a saved
        // position is meaningless). Position is clamped to the screen
        // containing the cursor by PopupPositioning.panelFrame.
        let cursorPos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }
        let frame = PopupPositioning.panelFrame(
            contentSize: initialSize,
            cursor: cursorPos,
            screen: screen
        )
        panel.setFrame(frame, display: true)
        // Non-activating: don't steal focus from the user's active app.
        // The panel will accept key events (and ⌘1...⌘9 copy shortcuts) once the user clicks
        // into it, since PopupPanel.canBecomeKey is true.
        panel.orderFront(nil)
        scheduleResultResize()

        startDismissMonitor()
    }

    func showAtScreenCenter() {
        let initialSize = setupPanel()
        guard let panel else { return }

        // Input mode always opens centered on the screen containing the
        // cursor (see showAtCursor: no saved position is kept).
        let cursorPos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - initialSize.width / 2,
            y: visibleFrame.midY - initialSize.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: initialSize), display: true)
        // Input mode needs the app activated so the panel can receive keyboard events.
        // Without this, makeKeyAndOrderFront alone won't route keystrokes to our panel
        // because macOS keeps delivering them to the previously active app.
        // Remember the previously active app so we can restore focus after dismissal.
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        scheduleResultResize()
        panel.focusSourceInput()

        startDismissMonitor()
    }

    func dismiss() {
        resizeTask?.cancel()
        resizeTask = nil
        copyShortcutDismissTask?.cancel()
        copyShortcutDismissTask = nil
        dismissMonitor?.stop()
        dismissMonitor = nil
        ttsCoordinator?.stop()
        panel?.contentView = nil
        panel?.close()
        // Recreate panel on next show to ensure a fresh SwiftUI view tree,
        // avoiding stale @Observable state from previous translation sessions.
        panel = nil
        resultLayout = PopupResultLayout()
        coordinator.dismiss()
        onDismiss?()

        // Restore focus only when TransPeek is still frontmost (user hasn't switched away manually).
        if let previousApp = previouslyActiveApp, NSRunningApplication.current.isActive {
            previousApp.activate()
        }
        previouslyActiveApp = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// TransPeek Phase 1: OCR from the float panel. Hide the panel so the
    /// region selector is unobstructed, run OCR (respecting the user's
    /// post-OCR mode), then show the panel again with the result — or, in
    /// copy-only mode, stay hidden (the caller shows the "Copied" toast).
    /// Unlike dismiss(), this does NOT clear the coordinator state.
    func performPanelOCR() {
        hidePanelTemporarily()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.coordinator.ocrAndTranslateWithMode()
            if Defaults[.ocrPostMode] == .copyOnly,
               self.coordinator.lastCopyOnlyOutcome == .copied
            {
                self.onOCRCopyOnlySuccess?()
            }
            if outcome.shouldPresent {
                self.showAtCursor()
            }
        }
    }

    /// Hide the panel temporarily for a screen capture (the Capture OCR
    /// button's performPanelOCR, and the "?" Run buttons / performShortcut
    /// for capture actions — Manh 2026-11-17). The panel would otherwise
    /// cover the screen region to capture. Unlike dismiss(), this does NOT
    /// clear the coordinator state, so the caller can show the panel again
    /// with the result.
    func hidePanelTemporarily() {
        resizeTask?.cancel()
        resizeTask = nil
        copyShortcutDismissTask?.cancel()
        copyShortcutDismissTask = nil
        dismissMonitor?.stop()
        dismissMonitor = nil
        ttsCoordinator?.stop()
        panel?.orderOut(nil)
    }

    // MARK: - Private

    @discardableResult
    private func setupPanel() -> CGSize {
        // Clamp the restored size to the panel minimum: a size saved by
        // an older build (when the minimum was 280x200) can be below the
        // current 400x450 minimum, and the panel would otherwise open
        // smaller than the drag handles allow (Manh 2026-11-16).
        let initialSize = CGSize(
            width: max(CGFloat(Defaults[.popupDefaultWidth]), PopupPanel.minimumSize.width),
            height: max(CGFloat(Defaults[.popupDefaultHeight]), PopupPanel.minimumSize.height)
        )

        if panel == nil {
            let newPanel = PopupPanel(contentRect: NSRect(origin: .zero, size: initialSize))
            newPanel.onCopyResultShortcut = { [weak self] index in
                self?.copyResultFromShortcut(atDisplayIndex: index) ?? false
            }
            let contentView = PopupView(
                coordinator: coordinator,
                languagePopoverTracker: languagePopoverTracker,
                focusTimerStore: focusTimerStore,
                onDismiss: { [weak self] in
                    self?.dismiss()
                },
                onOpenSettings: { [weak self] in
                    self?.dismiss()
                    self?.settingsController?.showWindow()
                },
                onOCRRequested: { [weak self] in
                    self?.performPanelOCR()
                },
                // Forward at call time (not capture time): AppDelegate sets
                // onRunShortcut once at startup, but the panel is built
                // lazily, so reading the property here keeps the wiring
                // working no matter which ran first.
                onRunShortcut: { [weak self] name in
                    self?.onRunShortcut?(name)
                },
                // Same call-time forwarding for Fast Read (Manh 2026-11-17).
                onFastRead: { [weak self] text in
                    self?.onFastRead?(text)
                },
                onResultLayoutChange: { [weak self] layout in
                    self?.resultLayout = layout
                    self?.scheduleResultResize()
                }
            )
            .environment(\.popupPanel, newPanel)
            .environment(\.ttsCoordinator, ttsCoordinator)
            let hostingView = NSHostingView(rootView: contentView)
            // Prevent NSHostingView from auto-resizing the window on content changes,
            // which causes an infinite constraint update loop during streaming.
            hostingView.sizingOptions = []
            newPanel.contentView = hostingView
            panel = newPanel
        }

        return initialSize
    }

    private func scheduleResultResize() {
        guard resizeTask == nil else { return }
        // Leave SwiftUI's update transaction before setFrame can trigger another layout.
        // Coalesce pending measurements and read the latest snapshot when the task runs.
        resizeTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            self.resizeTask = nil
            self.resizeForResultContent()
        }
    }

    private func resizeForResultContent() {
        // A drag always holds the mouse button down. If the flag says a
        // drag is in progress but no button is held, the flag is stale —
        // the drag was interrupted without onEnded (e.g. the handle view
        // was recreated mid-drag, so onDisappear kept the flag because
        // dragStartMouse was non-nil) and was never cleared. Clear it so
        // auto-fit can run; otherwise long results never expand the panel
        // until the user drags again (Manh 2026-11-16: long text stayed
        // clipped until he dragged a bit and released).
        if let panel, panel.isUserResizing, NSEvent.pressedMouseButtons == 0 {
            panel.isUserResizing = false
        }
        guard let panel, panel.isVisible, !panel.isUserResizing,
              panel.manualResizeGeneration != coordinator.translationGeneration
        else { return }
        guard let resultContentHeight = resultLayout.contentHeight,
              let resultViewportHeight = resultLayout.viewportHeight,
              let measuredContainerHeight = resultLayout.containerHeight,
              resultViewportHeight > 0,
              let screen = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
        else {
            // Measurements missing — retry once after a short delay, so a
            // single missed layout pass does not leave the panel unexpanded
            // (report P2, Manh 2026-11-16). At most one retry per episode:
            // the flag is set here and only cleared when a resize runs
            // with valid measurements, so a still-missing retry does not
            // schedule another one.
            if !resizeRetryUsed {
                resizeRetryUsed = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self else { return }
                    self.resizeForResultContent()
                }
            }
            return
        }
        // Valid measurements — a later missing-measurement episode may
        // retry again.
        resizeRetryUsed = false

        let frame = PopupPanelSizing.frameToFit(
            currentFrame: panel.frame,
            contentHeight: resultContentHeight,
            viewportHeight: resultViewportHeight,
            measuredContainerHeight: measuredContainerHeight,
            minimumHeight: PopupPanel.minimumSize.height,
            maximumHeight: PopupPanel.maximumSize.height,
            visibleFrame: screen.visibleFrame
        )
        guard abs(frame.height - panel.frame.height) > 0.5
            || abs(frame.origin.y - panel.frame.origin.y) > 0.5
        else { return }
        panel.setFrame(frame, display: true)
    }

    private func copyResultFromShortcut(atDisplayIndex index: Int) -> Bool {
        guard coordinator.copyResult(atDisplayIndex: index) else { return false }

        copyShortcutDismissTask?.cancel()
        copyShortcutDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
        return true
    }

    private func startDismissMonitor() {
        guard let panel else { return }
        dismissMonitor?.stop()
        dismissMonitor = PopupDismissMonitor(
            panel: panel,
            popoverTracker: languagePopoverTracker,
            isPinned: { [weak self] in self?.coordinator.isPinned ?? false },
            // Two-stage Esc (Manh 2026-11-20, 07:02): while a read is
            // running in panel right, the first Esc only closes the
            // reading and returns to panel right; the next Esc dismisses
            // the panel.
            onEscape: { [weak self] in
                guard let self else { return false }
                guard self.focusTimerStore.panelReadingViewModel != nil else { return false }
                self.focusTimerStore.stopPanelReading()
                return true
            }
        ) { [weak self] in
            self?.dismiss()
        }
        dismissMonitor?.start()
    }
}
