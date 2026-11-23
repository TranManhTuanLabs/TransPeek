import SwiftUI

/// The one shared keyboard + focus behaviour for every reading surface
/// (Manh 2026-11-22, `docs/FEATURES/FAST_READ.md` §11).
///
/// WHY IT EXISTS: Space/focus used to live in two places — `RSVPView`
/// (Window) owned its own `@FocusState` + `onAppear` + `.onKeyPress`,
/// and `CompactReadingView` (Lite) owned a second copy plus an
/// `.onChange(of: isPlaying)` patch. Every entry path (user opens Fast
/// Read, Pomodoro reminder, rest-eyes reminder) had to remember the
/// focus dance itself, and when a path forgot, Space broke — twice: the
/// reminder path forgot `makeKey` (fixed `b6388f20`), and a reminder
/// read starting in an already-visible panel never fired `onAppear`
/// again, so the focus stayed lost from the previous read (fixed
/// `1ca40268`). Now the rule "read starts playing → its surface is
/// focused → Space works at once" lives HERE, once, and both surfaces
/// apply this modifier — no entry path remembers anything.
///
/// WHAT IT DOES (all three in one place):
/// 1. Knows when a read starts playing — it watches
///    `viewModel.isPlaying` and re-takes focus the moment a read
///    starts, even when the view never leaves the hierarchy (the
///    already-visible-panel case above).
/// 2. Takes SwiftUI focus — `.focusable()` + `.focused()` on the
///    reading root, focus grabbed on appear and on every play start.
///    (Making the WINDOW key is the controllers' job: the window
///    always opens keyed in `RSVPWindowController.show`, the Rest
///    window in `RestWindowController.show`, and the panel through
///    `PopupPanelController.showForFastRead()` — the one keyed opener
///    every Lite entry path uses, so no path passes `makeKey: true`
///    itself.)
/// 3. Handles the read keys — Space play/pause, ←/→ step (Shift =
///    sentence), ↑/↓ speed ±50 WPM. Esc is the ONE surface difference:
///    the Window closes on Esc (`onEscape` set), Lite ignores it
///    (`onEscape` nil) so the key propagates to the host — the panel's
///    dismiss monitor (two-stage Esc) or the Rest window's own Esc
///    closer. The modifier never swallows a key its surface doesn't
///    own.
///
/// SAFE DIRECTION (Manh 2026-11-22, §5): focused-only, never global.
/// This only makes focus RELIABLE while a read is playing — it never
/// captures keys system-wide. When the user clicks into another app
/// (Chrome, Word), the reading surface loses focus and every keystroke
/// goes to that app; the read keeps running but never pauses/resumes
/// from typing elsewhere. That is what makes Space safe as an
/// emergency mute: it works the instant a read starts, and only while
/// the read surface is focused.
struct ReadKeyboardFocus: ViewModifier {
    /// The reader whose playback state drives focus (one shared
    /// `RSVPViewModel` per surface — the Window and Lite never share
    /// one, Manh 2026-11-21, so each surface's modifier watches its
    /// own view model).
    @ObservedObject var viewModel: RSVPViewModel
    /// What Esc does on this surface (`nil` = ignore it and let the
    /// host handle it — Lite; non-nil = run it, e.g. close the
    /// Window). Space/arrows never differ between surfaces, so they
    /// need no parameter.
    var onEscape: (() -> Void)? = nil

    /// This modifier's own focus state — one per surface, owned here
    /// so neither reading view keeps its own `@FocusState` copy.
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            // Hide the blue focus ring (Manh 2026-11-18): the focusable
            // root used to draw a blue border framing the whole
            // surface. The view stays focusable — Space / arrows / Esc
            // still work — just without the ring.
            .focusEffectDisabled()
            // Grab focus the moment the reading surface appears, so
            // Space works at once without a first click.
            .onAppear {
                isFocused = true
            }
            // Re-take focus whenever a read starts playing (the
            // 2026-11-22 reminder bug, `1ca40268`): a read that starts
            // in an already-visible surface never fires `onAppear`
            // again, so without this the focus stays lost from the
            // previous read and Space never reaches the new one.
            .onChange(of: viewModel.isPlaying) { _, isPlaying in
                if isPlaying { isFocused = true }
            }
            .onKeyPress(action: handleKeyPress)
    }

    /// The read keys, shared by Full and Lite. Same keys as before —
    /// moved here whole, so a key change is made once and both
    /// surfaces get it.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .space:
            viewModel.togglePlayPause()
            return .handled
        case .leftArrow:
            if press.modifiers.contains(.shift) {
                viewModel.stepSentence(forward: false)
            } else {
                viewModel.stepBack()
            }
            return .handled
        case .rightArrow:
            if press.modifiers.contains(.shift) {
                viewModel.stepSentence(forward: true)
            } else {
                viewModel.stepForward()
            }
            return .handled
        case .upArrow:
            viewModel.wpm = min(RSVPEngine.maxWPM, viewModel.wpm + RSVPEngine.wpmStep)
            return .handled
        case .downArrow:
            viewModel.wpm = max(50, viewModel.wpm - RSVPEngine.wpmStep)
            return .handled
        case .escape:
            // Esc belongs to the host on Lite (panel dismiss monitor /
            // Rest window closer), so it must propagate — returning
            // `.ignored` lets the host's own `.onKeyPress(.escape)`
            // see it. The Window owns Esc itself and closes.
            if let onEscape {
                onEscape()
                return .handled
            }
            return .ignored
        default:
            return .ignored
        }
    }
}

extension View {
    /// Apply the shared read keyboard + focus behaviour to a reading
    /// root view (Window `RSVPView` or Lite `CompactReadingView`).
    /// `onEscape` is the Window's close action; Lite leaves it `nil`
    /// so Esc propagates to its host.
    func readKeyboardFocus(
        viewModel: RSVPViewModel,
        onEscape: (() -> Void)? = nil
    ) -> some View {
        modifier(ReadKeyboardFocus(viewModel: viewModel, onEscape: onEscape))
    }
}
