import AppKit
import ApplicationServices
import Defaults
import os

// MARK: - HoverBlock

/// A block of text found under the mouse: its text, its on-screen frame
/// (AX coordinates, top-left origin) and the AX element it came from.
/// The frame is in AX coordinates so the follow poll can compare it
/// directly with later AX reads.
struct HoverBlock {
    let text: String
    let frame: CGRect
    let element: AXUIElement
}

// MARK: - HoverBlockText (decision rules)

/// The rules for hover block detection (Model A, research TTS 16/11):
/// what counts as a hoverable text block, and whether two hits are the
/// same block. The pure rules (`shouldAccept`, `isSameBlock`) are
/// unit-tested; the AX calls only run on a real Mac.
enum HoverBlockText {
    private static let log = Logger(subsystem: "com.tranmanhtuanlabs.transpeek", category: "HoverBlockText")

    /// Roles that never carry translatable block text — buttons, links
    /// and other controls. Hovering one must not summon the icon, and
    /// nothing above one is read either (a button inside a big text
    /// container must not surface the container's text).
    /// Exception (step 1, 2026-11-23): a link (AXLink) is climbed past
    /// in blockText — a link is part of its sentence, so the paragraph
    /// above it can still become the block. The link's own text is
    /// never accepted as a block (shouldAccept rejects it below).
    static let interactiveRoles: Set<String> = [
        kAXButtonRole as String,
        // "AXLink": the kAXLinkRole constant is not in scope in Swift
        // (unlike the other kAX*Role constants), so use the literal
        // role string the AX framework returns for a link.
        "AXLink",
        kAXMenuItemRole as String,
        kAXMenuBarItemRole as String,
        kAXCheckBoxRole as String,
        kAXRadioButtonRole as String,
        kAXPopUpButtonRole as String,
        kAXMenuButtonRole as String,
        kAXDisclosureTriangleRole as String,
        kAXSliderRole as String,
        kAXIncrementorRole as String,
        kAXColorWellRole as String,
        kAXComboBoxRole as String,
        kAXScrollBarRole as String,
        kAXSplitterRole as String,
        kAXProgressIndicatorRole as String,
        kAXBusyIndicatorRole as String,
    ]

    /// Roles that are window chrome, not content — hovering one must not
    /// summon the icon, and their title must never be read as text
    /// (a window title is not a text block).
    static let chromeRoles: Set<String> = [
        kAXWindowRole as String,
        // "AXDialog": same reason as "AXLink" above — the
        // kAXDialogRole constant is not in scope in Swift, so use
        // the literal role string the AX framework returns.
        "AXDialog",
        kAXApplicationRole as String,
        kAXMenuBarRole as String,
        kAXMenuRole as String,
        kAXSheetRole as String,
        kAXDrawerRole as String,
        kAXPopoverRole as String,
    ]

    /// Minimum trimmed length for a hovered block (characters). A
    /// character count, not a word count, so it works for CJK text
    /// (Chinese/Japanese/Korean have no spaces between words). v1
    /// tuning: short enough that headings and short phrases work, long
    /// enough that stray 1–3 letter UI labels do not summon the icon.
    static let minimumLength = 4

    /// Maximum length for a hovered block (characters). Longer strings
    /// are a whole document, not a block — the user can still select
    /// manually. Guards against a container handing back an entire page.
    static let maximumLength = 2000

    /// How far up the parent chain to look for text (levels). A single
    /// parent chain, not a tree scan — it follows one element, bounded.
    /// v1 was 3; raised to 5 (research 2026-11-23, step 1): the AX
    /// hit-test usually lands on the text itself (level 0), so 3 was
    /// enough, but 5 costs almost nothing and covers deeply nested
    /// inline spans (React pages). The 2000-char cap stays — it is
    /// what stops a whole document being treated as a block.
    static let maxParentLevels = 5

    /// Whether `text` from an element with `role` is a block worth
    /// showing the icon for: not a control or chrome, long enough to
    /// be a block, short enough not to be a whole document, and carrying
    /// at least one letter or digit (not just punctuation).
    static func shouldAccept(text: String, role: String?) -> Bool {
        if let role, interactiveRoles.contains(role) || chromeRoles.contains(role) {
            return false
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength, trimmed.count <= maximumLength else {
            return false
        }
        return trimmed.contains(where: { $0.isLetter || $0.isNumber })
    }

    /// Whether two hover hits are the same block (same frame + same
    /// text start), so a re-layout or a second hit-test of one block
    /// does not re-show the icon.
    static func isSameBlock(text: String, frame: CGRect, otherText: String, otherFrame: CGRect) -> Bool {
        // Same frame + same text start: one text may be a prefix of
        // the other (the block grew or shrank slightly), so a shared
        // start counts as the same block — exact equality of the
        // first 40 chars was too strict and treated a longer text
        // as a different block.
        guard frame == otherFrame else { return false }
        let head = text.prefix(40)
        let otherHead = otherText.prefix(40)
        return head.hasPrefix(otherHead) || otherHead.hasPrefix(head)
    }

    /// The AX element at a screen point (AX coordinates, top-left
    /// origin). One hit-test — never walks the tree.
    static func element(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(point.x),
            Float(point.y),
            &element
        )
        guard result == .success else {
            log.debug("hit-test failed (status: \(result.rawValue, privacy: .public))")
            return nil
        }
        return element
    }

    /// The text block at an AX element: the element itself or the nearest
    /// ancestor (at most `maxParentLevels` up) that carries readable
    /// text. Returns nil when nothing hoverable is there — no text, an
    /// interactive control or window chrome, or a non-text app. Walking
    /// up one parent chain is not a tree scan.
    static func blockText(from element: AXUIElement) -> HoverBlock? {
        var current: AXUIElement? = element
        for _ in 0...maxParentLevels {
            guard let el = current else { return nil }
            let role = stringAttribute(el, kAXRoleAttribute as CFString)
            // A control or chrome is never a text block, and neither is
            // anything above it — stop here instead of walking up into
            // a container that might hold the whole document.
            // Exception (research 2026-11-23, step 1): a link is part
            // of the sentence it sits in, so climb past it to the
            // paragraph that contains it instead of stopping — hovering
            // a link inside a paragraph should still summon the icon
            // for that paragraph. The link's own text is never taken
            // (shouldAccept rejects AXLink below); only an ancestor's
            // text can become the block.
            if let role, role != "AXLink",
               interactiveRoles.contains(role) || chromeRoles.contains(role) {
                return nil
            }
            if let text = readableText(of: el),
               shouldAccept(text: text, role: role),
               let frame = frame(of: el) {
                return HoverBlock(text: text, frame: frame, element: el)
            }
            current = parent(of: el)
        }
        return nil
    }

    /// The on-screen frame of an AX element (AX coordinates, top-left
    /// origin). Same position/size read as AccessibilityGrabber.
    static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    /// The window containing an AX element (AX coordinates, top-left
    /// origin) — the window the element's text lives in. Used by the
    /// Step 2 reading indicator to clip its overlay to the visible
    /// part of that window (Manh 2026-11-27, 20:36 — a long block's AX
    /// frame can run past the window, and the highlight must never
    /// draw outside it). Returns nil when the app does not expose the
    /// window (the caller falls back to the screen's visible frame).
    static func windowFrame(of element: AXUIElement) -> CGRect? {
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowValue) == .success,
              let windowRef = windowValue,
              CFGetTypeID(windowRef) == AXUIElementGetTypeID()
        else { return nil }
        // Safe: CFGetTypeID verified above; as?/as! cannot express CF type casts cleanly.
        let window = unsafeBitCast(windowRef, to: AXUIElement.self)
        return frame(of: window)
    }

    /// The on-screen frame of one character range inside an AX element
    /// (AX coordinates, top-left origin) — the frame of the sentence or
    /// word being read, for the Step 2 reading indicator (Manh
    /// 2026-11-24). Uses the standard macOS parameterized attribute
    /// `kAXBoundsForRangeParameterizedAttribute` with a CFRange
    /// parameter. Returns nil on ANY failure (the app does not support
    /// range bounds, the range is out of bounds, the rect is empty) —
    /// every caller must fall back gracefully (skip that highlight
    /// level), never crash or block on it. The range is an NSRange in
    /// the element's text (UTF-16 offsets, the same indexing the TTS
    /// word callback reports).
    static func bounds(for range: NSRange, in element: AXUIElement) -> CGRect? {
        // CFRange and NSRange share the same layout (location/length),
        // but build a CFRange explicitly so the AX call never depends
        // on that bridging.
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter,
            &value
        ) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect),
              !rect.isNull, !rect.isEmpty
        else { return nil }
        return rect
    }

    /// Read a string attribute (value / title / description / role).
    /// Returns nil when the attribute is missing or not a string.
    private static func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let text = value as? String, !text.isEmpty
        else { return nil }
        return text
    }

    /// The readable text of an element: its value first (text fields,
    /// static text, text areas), then its title, then its description.
    /// The first non-empty one wins.
    private static func readableText(of element: AXUIElement) -> String? {
        // `as CFString`: stringAttribute takes CFString, and these
        // kAX*Attribute constants are String in Swift (same cast as
        // the position/size/parent reads elsewhere in this file).
        if let value = stringAttribute(element, kAXValueAttribute as CFString) { return value }
        if let title = stringAttribute(element, kAXTitleAttribute as CFString) { return title }
        if let description = stringAttribute(element, kAXDescriptionAttribute as CFString) { return description }
        return nil
    }

    /// The parent of an AX element, or nil when it has none. Same
    /// type-checked cast as AccessibilityGrabber's focused-element read.
    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var parentValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentValue) == .success,
              let parentRef = parentValue,
              CFGetTypeID(parentRef) == AXUIElementGetTypeID()
        else { return nil }
        // Safe: CFGetTypeID verified above; as?/as! cannot express CF type casts cleanly.
        return unsafeBitCast(parentRef, to: AXUIElement.self)
    }
}

// MARK: - HoverTextDetector

/// Watches the mouse and shows the float icon when it hovers a block of
/// text in another app — without the user having to select the text
/// first (Model A, Manh 2026-11-21). After the icon appears, the flow
/// is the normal icon flow (hover → translate panel, click → Speak /
/// Fast Read per "Click icon for:"); this class only adds a second
/// trigger path alongside text selection. Only apps that expose text
/// via Accessibility work; where no text is exposed, hovering does
/// nothing (non-exposed apps are a separate next-session research task).
@MainActor
final class HoverTextDetector {
    /// A hovered block was found: the text + the mouse point to show
    /// the icon near. The caller shows the icon the same way it shows
    /// one for a selection.
    var onBlockHovered: ((String, CGPoint) -> Void)?
    /// The hovered block scrolled away or vanished while the icon was
    /// up: the icon is stale and should be dismissed.
    var onHoverStale: (() -> Void)?
    /// Whether a hit-test may deliver right now (the caller answers
    /// from the icon/panel state — no delivery while the icon or the
    /// panel is already up, so a hover never yanks another flow's icon).
    var shouldDetect: (() -> Bool)?

    /// Debounce between the last mouse move and the hit-test (ms) — from
    /// Settings (Manh 2026-11-21, `hoverBlockDelayMs`): how long the
    /// mouse must stay still over a text block before the icon appears.
    /// Long enough that sweeping the mouse across text does not flicker
    /// the icon or burn CPU; short enough that a deliberate pause feels
    /// instant. Default 400 ms.
    static var debounceMs: Int { Defaults[.hoverBlockDelayMs] }
    /// How often the hovered block's frame is re-read while the icon is
    /// up (seconds).
    static let followIntervalSec = 0.3
    /// Frame movement that counts as "the text scrolled away" (points).
    static let scrollThreshold: CGFloat = 10
    /// Suppression after a dismiss (ms) — same as SelectionMonitor, so
    /// a tiny mouse move right after dismissing does not re-summon the
    /// icon at once.
    static let suppressMs = 500

    nonisolated(unsafe) private var mouseMovedMonitor: Any?
    private var debounceTask: Task<Void, Never>?
    private var followTimer: Timer?
    private var isSuppressed = false
    private var suppressTask: Task<Void, Never>?
    /// The latest mouse position (screen coordinates, bottom-left
    /// origin). The debounce task hit-tests this, not the position at
    /// event time, so a fast mouse move is tested where it ended up.
    private var lastMousePoint: CGPoint?
    /// The block the icon is currently up for (if any): its text, frame
    /// (AX coordinates) and element, for same-block dedup and the
    /// follow poll.
    private var currentBlock: HoverBlock?

    /// The block the icon is currently up for, for the Step 2 chaining
    /// start (Manh 2026-11-24): the chaining controller reads the block
    /// once at Speak time and keeps its own copy — the detector may
    /// forget it (stopFollowing) while speaking, so the controller must
    /// not depend on it after start. Read-only; the detector still
    /// owns the value.
    var currentBlockForReading: HoverBlock? { currentBlock }

    deinit {
        if let monitor = mouseMovedMonitor { NSEvent.removeMonitor(monitor) }
        debounceTask?.cancel()
        followTimer?.invalidate()
        suppressTask?.cancel()
    }

    func start() {
        guard mouseMovedMonitor == nil else { return }
        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            let screenPoint = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseMoved(at: screenPoint)
            }
        }
    }

    func stop() {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
        debounceTask?.cancel()
        debounceTask = nil
        stopFollowing()
        suppressTask?.cancel()
        suppressTask = nil
    }

    /// Suppress detection briefly — called after the icon/panel is
    /// dismissed, so the mouse still sitting over the same text does
    /// not re-summon the icon at once.
    func suppressBriefly() {
        isSuppressed = true
        suppressTask?.cancel()
        suppressTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.suppressMs))
            guard !Task.isCancelled else { return }
            self?.isSuppressed = false
        }
    }

    /// Cancel a pending debounced hit-test — called on mouse-down, so a
    /// hit-test scheduled while hovering never fires mid-drag and fights
    /// the selection flow.
    func cancelPendingHover() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    /// Stop following the hovered block (icon dismissed): the follow
    /// poll ends and the block is forgotten, so a later mouse move
    /// re-detects it from scratch.
    func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
        currentBlock = nil
    }

    private func handleMouseMoved(at point: CGPoint) {
        // The feature gates: master auto-detect + this feature's own
        // toggle (default ON) + not suppressed.
        guard Defaults[.isAutoDetectEnabled],
              Defaults[.isHoverBlockDetectionEnabled],
              !isSuppressed else { return }
        // While a mouse button is down the user is dragging (a selection
        // is in progress) — the selection flow owns the mouse-up, so the
        // hover path stays out of the way.
        guard NSEvent.pressedMouseButtons == 0 else { return }
        // Hovering TransPeek's own windows must not summon the icon.
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        // Respect the user's excluded-apps list, same as selection.
        guard !Defaults[.excludedAppBundleIDs].contains(frontApp.bundleIdentifier ?? "") else { return }

        lastMousePoint = point
        // Debounce: only the last position in the debounce window is
        // hit-tested, so sweeping the mouse costs one AX call, not one
        // per mouse-move event.
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.debounceMs))
            guard let self, !Task.isCancelled else { return }
            guard let point = self.lastMousePoint else { return }
            self.hitTest(at: point)
        }
    }

    private func hitTest(at point: CGPoint) {
        // Second drag guard (the first is at event time): a drag can
        // start during the debounce, before the mouse-down
        // handler cancels the pending task — never hit-test mid-drag.
        guard NSEvent.pressedMouseButtons == 0 else { return }

        // Convert the mouse point (bottom-left origin) to AX coordinates
        // (top-left origin) — same conversion as AccessibilityGrabber.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let axPoint = CGPoint(x: point.x, y: screenHeight - point.y)

        // Still inside the block the icon is already up for — nothing new.
        if let current = currentBlock, current.frame.contains(axPoint) { return }

        // No delivery while the icon or the panel is already up — a
        // hover must never yank another flow's icon. Checked here (not
        // only at event time) because the icon/panel state can change
        // during the debounce.
        guard shouldDetect?() != false else { return }

        guard let hit = HoverBlockText.element(at: axPoint),
              let block = HoverBlockText.blockText(from: hit) else {
            // Nothing hoverable here — forget the old block so moving
            // back onto it re-detects.
            currentBlock = nil
            return
        }

        // Same block as the one already showing (same frame + same text
        // start) — a re-layout, not a new hover.
        if let current = currentBlock,
           HoverBlockText.isSameBlock(text: block.text, frame: block.frame, otherText: current.text, otherFrame: current.frame) {
            return
        }

        currentBlock = block
        startFollowing()
        onBlockHovered?(block.text, point)
    }

    /// Poll the hovered block's frame while the icon is up: if the
    /// frame moved (the text scrolled away) or the element is gone,
    /// the icon is stale. The poll stops the moment the icon is
    /// dismissed.
    private func startFollowing() {
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: Self.followIntervalSec, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkStillThere()
            }
        }
    }

    private func checkStillThere() {
        guard let current = currentBlock else {
            stopFollowing()
            return
        }
        guard let frame = HoverBlockText.frame(of: current.element) else {
            // The element is gone — the icon's text no longer exists.
            stopFollowing()
            onHoverStale?()
            return
        }
        let moved = abs(frame.origin.x - current.frame.origin.x) > Self.scrollThreshold
            || abs(frame.origin.y - current.frame.origin.y) > Self.scrollThreshold
        guard moved else { return }
        // The text scrolled away from where the icon was shown — the
        // icon's text is stale, dismiss it; moving the mouse re-detects.
        stopFollowing()
        onHoverStale?()
    }
}
