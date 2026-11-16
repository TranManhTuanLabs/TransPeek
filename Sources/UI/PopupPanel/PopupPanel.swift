import AppKit
import SwiftUI

// MARK: - Environment Key

private struct PopupPanelKey: EnvironmentKey {
    static let defaultValue: PopupPanel? = nil
}

extension EnvironmentValues {
    var popupPanel: PopupPanel? {
        get { self[PopupPanelKey.self] }
        set { self[PopupPanelKey.self] = newValue }
    }
}

enum PopupPanelViewIdentifier {
    static let sourceInputTextView = "SourceInputTextView"
}

/// A floating, non-activating panel for showing translation results near the cursor.
final class PopupPanel: NSPanel {
    /// Minimum panel size (Manh 2026-11-16): the panel holds many rows and
    /// buttons (language pickers + Capture OCR, results, Pin/Settings,
    /// dictionary links, GitHub bar), so it must not shrink to a size where
    /// they no longer fit. Width 400 fits the language row (same as the
    /// Windows panel's minimum); height 450 matches the Windows panel's
    /// minimum/compact open height (Manh 2026-11-16, unify mac+Windows).
    /// The drag handles clamp to this constant directly — not via the
    /// window's `minSize` property, which NSHostingView can reset when the
    /// SwiftUI content is laid out, so reading `minSize` at drag time is
    /// not reliable (the minimum was silently ignored on build #191).
    /// The `windowWillResize` delegate below is the backstop: it clamps
    /// EVERY resize (drag, setFrame, auto-fit) at the AppKit level, the
    /// macOS equivalent of Windows' WM_GETMINMAXINFO, so the panel can
    /// never be dragged below this minimum (Manh 2026-11-17).
    static let minimumSize = CGSize(width: 400, height: 450)
    /// Maximum panel size (Manh 2026-11-17, Windows parity): width 600
    /// matches the Windows panel's MaxPanelWidth (600 is ~1.4x the 420
    /// default; the old 800 was ~double the default and left a too-wide
    /// panel after a wide drag). Height 800 matches Windows' MaxPanelSize.
    static let maximumSize = CGSize(width: 600, height: 800)
    var onCopyResultShortcut: ((Int) -> Bool)?
    var onSwapLanguagesShortcut: ((NSEvent) -> Bool)?

    /// Set when `focusSourceInput()` is called before the source text view has been mounted.
    /// `SubmitAwareTextView.viewDidMoveToWindow` consumes this flag once the view attaches.
    private(set) var pendingSourceInputFocus = false

    /// Number of upcoming `NSWindow.didMoveNotification` events that should be ignored by the
    /// position-saving observer. The controller bumps this before each programmatic `setFrame`
    /// so we don't overwrite the saved drag position with a freshly-computed show location.
    var suppressNextMoveSave: Int = 0
    var isUserResizing = false
    var manualResizeGeneration: Int?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        isReleasedWhenClosed = false
        minSize = Self.minimumSize
        contentMinSize = Self.minimumSize
        maxSize = Self.maximumSize
        // This panel is its own window delegate (delegate is weak, so no
        // retain cycle) so windowWillResize can clamp every resize at the
        // AppKit level — the backstop for the minimum (see below).
        delegate = self

        // Rounded corners
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true
    }

    // Allow becoming key window so users can select/copy text within the panel.
    override var canBecomeKey: Bool { true }

    /// Move first responder to the source input text view. If the text view has not
    /// been mounted yet (SwiftUI renders asynchronously), arms a one-shot flag that
    /// `SubmitAwareTextView.viewDidMoveToWindow` will consume when the view attaches.
    func focusSourceInput() {
        if let contentView, let textView = findSourceInputTextView(in: contentView) {
            makeKey()
            _ = makeFirstResponder(textView)
            return
        }
        pendingSourceInputFocus = true
    }

    /// Called by `SubmitAwareTextView` once it enters the window hierarchy.
    /// Consumes the one-shot `pendingSourceInputFocus` flag.
    /// Responder-chain mutation is deferred to the next runloop tick to avoid
    /// reentering AppKit during the `viewDidMoveToWindow` callback.
    func consumePendingSourceInputFocus(into textView: NSTextView) {
        guard pendingSourceInputFocus else { return }
        pendingSourceInputFocus = false
        Task { @MainActor [weak self, weak textView] in
            guard let self, let textView, textView.window === self else { return }
            self.makeKey()
            _ = self.makeFirstResponder(textView)
        }
    }

    // MARK: - Selective Window Dragging

    /// Intercepts left-mouse-down on non-interactive areas to start a window drag,
    /// while letting interactive controls (text views, buttons, gesture views) handle events normally.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           onSwapLanguagesShortcut?(event) == true {
            return
        }

        if event.type == .keyDown,
           let resultIndex = copyResultShortcutIndex(for: event),
           onCopyResultShortcut?(resultIndex) == true {
            return
        }

        if event.type == .leftMouseDown {
            if shouldStartWindowDrag(for: event) {
                performDrag(with: event)
                // Position saving is handled by the controller's NSWindow.didMoveNotification
                // observer, which fires during and at the end of the drag.
                return
            }
            // Make panel key so text selection and other interactions work.
            if !isKeyWindow { makeKey() }
        }
        super.sendEvent(event)
    }

    private func copyResultShortcutIndex(for event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedFlags: NSEvent.ModifierFlags = [.shift, .option, .control]
        guard flags.contains(.command),
              flags.intersection(disallowedFlags).isEmpty,
              let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let number = Int(characters),
              (1...9).contains(number)
        else { return nil }

        return number - 1
    }

    private func shouldStartWindowDrag(for event: NSEvent) -> Bool {
        guard let contentView else { return true }
        let point = contentView.convert(event.locationInWindow, from: nil)

        // The top bar (app name / slogan / hint) is always draggable: the
        // app-name Text ("TransPeek", bold) is backed by NSTextField,
        // which refuses mouseDownCanMoveWindow, so a plain walk-up would
        // block dragging from the app name — the spot the user grabs most
        // (Manh 2026-11-16; only the app name is affected, the slogan/hint
        // drag fine). A TopBarDragMarkerView marks that region; it takes
        // precedence over the checks below. The top bar has no buttons.
        if hasTopBarDragMarker(in: contentView, containing: event.locationInWindow) {
            return true
        }

        guard let hitView = contentView.hitTest(point) else { return true }

        // Walk up the view hierarchy: any standard AppKit control that refuses
        // mouseDownCanMoveWindow means the user is interacting with it.
        var view: NSView? = hitView
        while let v = view, v !== contentView {
            if !v.mouseDownCanMoveWindow { return false }
            view = v.superview
        }

        // Check if the click lands on an InteractiveMarkerView (SwiftUI gesture views).
        let windowPoint = event.locationInWindow
        return !hasInteractiveMarker(in: contentView, containing: windowPoint)
    }

    private func hasInteractiveMarker(in view: NSView, containing point: NSPoint) -> Bool {
        if let marker = view as? InteractiveMarkerView {
            let rect = marker.convert(marker.bounds, to: nil)
            if rect.contains(point) { return true }
        }
        for subview in view.subviews {
            if hasInteractiveMarker(in: subview, containing: point) { return true }
        }
        return false
    }

    private func hasTopBarDragMarker(in view: NSView, containing point: NSPoint) -> Bool {
        if let marker = view as? TopBarDragMarkerView {
            let rect = marker.convert(marker.bounds, to: nil)
            if rect.contains(point) { return true }
        }
        for subview in view.subviews {
            if hasTopBarDragMarker(in: subview, containing: point) { return true }
        }
        return false
    }

    private func findSourceInputTextView(in view: NSView) -> NSTextView? {
        if view.identifier?.rawValue == PopupPanelViewIdentifier.sourceInputTextView,
           let textView = view as? NSTextView {
            return textView
        }

        for subview in view.subviews {
            if let textView = findSourceInputTextView(in: subview) {
                return textView
            }
        }

        return nil
    }
}

// MARK: - NSWindowDelegate (minimum/maximum enforcement)

extension PopupPanel: NSWindowDelegate {
    /// Clamp EVERY resize at the AppKit level — user drags, programmatic
    /// setFrame, and auto-fit all pass through here, so the panel can
    /// never end up below `minimumSize` or above `maximumSize` no matter
    /// which code path resizes it. This is the macOS equivalent of
    /// Windows' WM_GETMINMAXINFO min-tracking (Manh 2026-11-17: "không
    /// thể kéo bé quá mức set min height"). It is a backstop only: the
    /// drag handles and auto-fit already clamp to the same constants, so
    /// in normal use this returns the size unchanged. It exists because
    /// `minSize` alone is not reliable — NSHostingView can reset the
    /// window's minSize during layout (build #191) — and a delegate clamp
    /// cannot be reset that way.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: min(max(frameSize.width, Self.minimumSize.width), Self.maximumSize.width),
            height: min(max(frameSize.height, Self.minimumSize.height), Self.maximumSize.height)
        )
    }
}
