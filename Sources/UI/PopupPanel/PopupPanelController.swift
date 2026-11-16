import AppKit
import Defaults
import SwiftUI

/// Manages the lifecycle and positioning of the popup translation panel.
@MainActor
final class PopupPanelController {
    var onDismiss: (() -> Void)?
    /// Called when a panel OCR run in copy-only mode actually copied text,
    /// so the app can show the "Copied" toast (set by AppDelegate).
    var onOCRCopyOnlySuccess: (() -> Void)?

    private var panel: PopupPanel?
    private var dismissMonitor: PopupDismissMonitor?
    private var copyShortcutDismissTask: Task<Void, Never>?
    private var panelMoveObserver: NSObjectProtocol?
    private var resultLayout = PopupResultLayout()
    private var resizeTask: Task<Void, Never>?
    /// Set when auto-fit retried once for missing measurements (report P2);
    /// cleared when a resize runs with valid measurements, so each new
    /// episode gets one retry.
    private var resizeRetryUsed = false

    private let coordinator: TranslationCoordinator
    private let ttsCoordinator: TTSCoordinator?
    private let settingsController: SettingsWindowController?

    /// The app that was frontmost before we activated ourselves for input mode.
    private var previouslyActiveApp: NSRunningApplication?

    init(
        coordinator: TranslationCoordinator,
        ttsCoordinator: TTSCoordinator? = nil,
        settingsController: SettingsWindowController? = nil
    ) {
        self.coordinator = coordinator
        self.ttsCoordinator = ttsCoordinator
        self.settingsController = settingsController
    }

    deinit {
        resizeTask?.cancel()
        if let observer = panelMoveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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

        let frame: NSRect
        if let origin = restoredOrigin(for: initialSize) {
            frame = NSRect(origin: origin, size: initialSize)
        } else {
            let cursorPos = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            else { return }
            frame = PopupPositioning.panelFrame(
                contentSize: initialSize,
                cursor: cursorPos,
                screen: screen
            )
        }
        panel.suppressNextMoveSave += 1
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

        let origin: NSPoint
        if let saved = restoredOrigin(for: initialSize) {
            origin = saved
        } else {
            let cursorPos = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            else { return }
            let visibleFrame = screen.visibleFrame
            origin = NSPoint(
                x: visibleFrame.midX - initialSize.width / 2,
                y: visibleFrame.midY - initialSize.height / 2
            )
        }
        panel.suppressNextMoveSave += 1
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
        if let observer = panelMoveObserver {
            NotificationCenter.default.removeObserver(observer)
            panelMoveObserver = nil
        }
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

    private func hidePanelTemporarily() {
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
            panelMoveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: newPanel,
                queue: .main
            ) { [weak self, weak newPanel] _ in
                guard let panel = newPanel else { return }
                MainActor.assumeIsolated {
                    self?.handlePanelMove(panel)
                }
            }
        }

        return initialSize
    }

    private func handlePanelMove(_ panel: PopupPanel) {
        if panel.suppressNextMoveSave > 0 {
            panel.suppressNextMoveSave -= 1
            return
        }
        guard Defaults[.popupRememberPosition] else { return }
        let f = panel.frame
        Defaults[.popupLastTopLeftX] = Double(f.origin.x)
        Defaults[.popupLastTopLeftY] = Double(f.origin.y + f.height)
        Defaults[.popupHasSavedPosition] = true
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
        if abs(frame.origin.y - panel.frame.origin.y) > 0.5 {
            panel.suppressNextMoveSave += 1
        }
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

    /// Returns the persisted last-dragged origin if the feature is enabled and a position has been
    /// saved. The persisted point is the top-left corner, so we derive the NSWindow origin
    /// (bottom-left) by subtracting the current panel height — this keeps the visual position
    /// anchored even when the panel's width or height differs from the previously saved session.
    /// The result is clamped to the visible frame of the screen containing the saved top-left so a
    /// resized-larger panel doesn't spill off the edge.
    private func restoredOrigin(for size: CGSize) -> NSPoint? {
        guard Defaults[.popupRememberPosition], Defaults[.popupHasSavedPosition] else { return nil }
        let topLeft = NSPoint(
            x: Defaults[.popupLastTopLeftX],
            y: Defaults[.popupLastTopLeftY]
        )
        let origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        let candidate = NSRect(origin: origin, size: size)

        // Prefer the screen that contained the saved top-left point; otherwise any screen the
        // candidate rect still overlaps. If neither holds (e.g. external display disconnected),
        // fall back to cursor/center logic.
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(topLeft) })
            ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(candidate) })
        else { return nil }

        return clampOrigin(origin, size: size, into: screen.visibleFrame)
    }

    private func clampOrigin(_ origin: NSPoint, size: CGSize, into bounds: NSRect) -> NSPoint {
        let padding: CGFloat = 8
        let minX = bounds.minX + padding
        let maxX = bounds.maxX - size.width - padding
        let minY = bounds.minY + padding
        let maxY = bounds.maxY - size.height - padding
        // If the screen is smaller than the panel along an axis, fall back to the min edge.
        let clampedX = maxX >= minX ? min(max(origin.x, minX), maxX) : minX
        let clampedY = maxY >= minY ? min(max(origin.y, minY), maxY) : minY
        return NSPoint(x: clampedX, y: clampedY)
    }

    private func startDismissMonitor() {
        guard let panel else { return }
        dismissMonitor?.stop()
        dismissMonitor = PopupDismissMonitor(
            panel: panel,
            isPinned: { [weak self] in self?.coordinator.isPinned ?? false }
        ) { [weak self] in
            self?.dismiss()
        }
        dismissMonitor?.start()
    }
}
