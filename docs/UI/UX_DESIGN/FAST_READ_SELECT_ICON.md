# Fast Read — Select Shows Icon (alternative icon in Read mode)

Design spec for the icon that appears when the user selects text inside
Fast Read. Settled 2026-11-21 (Manh). **Implemented 2026-11-21** (main):
`Sources/UI/AlternativeIcon/` (`ReadSelectionMonitor`,
`AlternativeIconController`, `AlternativeIconView`), wired in
`AppDelegate.setupAlternativeIcon()`. The reminder Space fix (panel
opens keyed via `onShowPanel`) shipped in the same push.

## 1. Name — "alternative icon"

One unified name: **alternative icon**. It is an alternative to the main
float icon, used only in Read mode. The name avoids confusion with the
Read action (Fast Read) — this icon does NOT start a Read session.

## 2. Why a separate icon

The float icon (`TriggerIconController`) works well today and its logic is
delicate (glyph state machine, Option-key polling, hover debounce, the
panel-visible guard). The Fast Read select case must **not** touch that
logic. So it gets its own separate path: an **alternative icon** that looks
like the float icon but is a different object with its own wiring.
Hovering/clicking the alternative icon calls into the existing trigger
callbacks (`onTranslateRequested` / `onSpeakRequested`) — it reuses the
translate and speak behaviour, it does not duplicate or modify the icon's
internals.

"Alternative" means *separate path that delegates*, not *non-interactive*.
The alternative icon is a real floating window that receives mouse events,
so **hover and click both work on it**, exactly like the real icon.

## 3. Appearance — blue A in a chat bubble, same on hover

- The icon is a **blue "A" inside a chat (speech) bubble** — the earlier
  icon design, reused here. Windows uses this same icon later.
- It displays the **same** normally and on hover — it does NOT change
  glyph on hover (unlike the main float icon, which changes glyph with
  hover/Option). No hover-state icon swap is needed.

## 4. Behaviour — hover + click both work

| Action | What happens | Notes |
| --- | --- | --- |
| **Hover** | Translate (look up the selected word) | Per surface (see §5). |
| **Click** | Speak — listen to the selected text (speaker glyph, as normal) | Uses its OWN separate system-TTS audio path (see §6). No Read. |

There is **no Read action** on this icon. Pressing Read here is meaningless:
the user selected one word inside a long passage, so starting a Fast Read
session on that fragment would lose the long context. The user only wants
to look up one word or listen to it.

The icon shows the **speaker glyph** on click (listen), and hover still opens
the translate flow for lookup. The global "Click icon for:" setting is
ignored here — the icon is always speaker + hover in Read mode.

## 5. Hover differs per surface

- **Fast Read Lite** (panel right, panel already open): hover only switches
  the panel to the **center (translate) tab**. It must NOT call
  `showAtCursor()` — that would move the panel to the cursor. The tab
  switch happens automatically because the panel follows `sourceText`.
- **Window Read** (separate window, panel closed): hover **opens the panel**
  (normal icon flow: panel opens at the cursor on the translate tab).

## 6. Click uses a SEPARATE system-TTS audio path

Clicking the alternative icon speaks the selected text through its **own
separate system TTS path**. It does NOT share the Read-mode speaker
button's audio path: the Read speaker button is tied to RSVP playback
sync (TTS drives the chunk advance), while the alternative icon's click
is a quick, independent "speak this selected text" that does not touch
RSVP playback state.

## 7. When the icon appears

Only when the user is in a Fast Read surface:

- The Window Read window is open, or
- The panel is on the Fast Read (right) tab.

It does **not** appear when selecting text in the translate input or in
Settings. The local mouse-up monitor + `AccessibilityGrabber` read the
selection from TransPeek's own window (the global `SelectionMonitor` only
sees other apps, so it cannot catch a selection inside TransPeek itself).

Auto-detect (block-text hover) is not a conflict: it already turns itself
off while the panel or the icon is visible.

## 8. Scope (what is NOT in this feature)

- No change to the real float icon's logic, glyphs, or settings.
- No Read action from a Fast Read selection.
- No icon in the translate input or Settings.
- TTS word-sync is a separate, later Style 2 follow-up, not part of this.

## Related docs

- [Float Icon (feature)](../../FEATURES/FLOAT_ICON.md) — the real float icon this fake icon delegates to.
- [Float Icon UX spec](FLOAT_ICON_UX_SPEC.md) — glyphs, hover = translate, click = listen.
- [Fast Read — Theme & Reading Style](FAST_READ_THEME_STYLE.md) — Style 1 / Style 2, Theme = colours only.
- [Fast Read (feature)](../../FEATURES/FAST_READ.md) — the Fast Read surfaces this icon lives in.
