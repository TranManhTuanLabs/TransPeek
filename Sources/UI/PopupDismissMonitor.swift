import AppKit

/// Monitors for clicks outside the panel and Escape key to dismiss the popup.
/// The language picker's popover counts as part of the panel (Manh 2026-11-19,
/// 0.1.5): a `.popover` is a separate NSWindow, so a click on it would read
/// as "click outside" and hide the panel before anything can be picked.
/// The `popoverTracker` tells this monitor which window is the popover.
@MainActor
final class PopupDismissMonitor {
    private let panel: NSPanel
    private let popoverTracker: LanguagePopoverTracker?
    private let isPinned: @MainActor () -> Bool
    private let onDismiss: @MainActor () -> Void

    nonisolated(unsafe) private var globalClickMonitor: Any?
    nonisolated(unsafe) private var globalKeyMonitor: Any?
    nonisolated(unsafe) private var localClickMonitor: Any?
    nonisolated(unsafe) private var localKeyMonitor: Any?

    init(
        panel: NSPanel,
        popoverTracker: LanguagePopoverTracker? = nil,
        isPinned: @escaping @MainActor () -> Bool = { false },
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.panel = panel
        self.popoverTracker = popoverTracker
        self.isPinned = isPinned
        self.onDismiss = onDismiss
    }

    func start() {
        // Global monitors: clicks and keys in OTHER applications
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismissForOutsideClick()
            }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.onDismiss()
                }
            }
        }

        // Local monitors: clicks and keys in OUR app (global monitors don't capture these)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            // Only dismiss if click is outside the panel AND outside the
            // language popover (the popover is a separate window but part
            // of the panel — a click there picks a language, it must not
            // dismiss anything). A click outside BOTH still dismisses.
            let clickLocation = event.locationInWindow
            let inPopover = event.window != nil && event.window === self.popoverTracker?.window
            if event.window !== self.panel && !inPopover {
                Task { @MainActor in
                    self.dismissForOutsideClick()
                }
            } else if !inPopover, let contentView = self.panel.contentView,
                      !contentView.frame.contains(clickLocation) {
                Task { @MainActor in
                    self.dismissForOutsideClick()
                }
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.onDismiss()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    private func dismissForOutsideClick() {
        guard !isPinned() else { return }
        onDismiss()
    }

    func stop() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }

        globalClickMonitor = nil
        globalKeyMonitor = nil
        localClickMonitor = nil
        localKeyMonitor = nil
    }

    deinit {
        // Safety: remove monitors if stop() wasn't called
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
    }
}
