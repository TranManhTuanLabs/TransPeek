# Fast Read — Select Shows Icon (fake icon in Read mode)

Design spec for the icon that appears when the user selects text inside
Fast Read. Settled 2026-11-21 (Manh). **Not implemented yet** — planned
branch `feature/select-shows-icon-fastread` (from main `9b0816b8`).

## 1. Why a separate "fake" icon

The float icon (`TriggerIconController`) works well today and its logic is
delicate (glyph state machine, Option-key polling, hover debounce, the
panel-visible guard). The Fast Read select case must **not** touch that
logic. So it gets its own separate path: a **fake icon** that looks exactly
like the current float icon but is a different object with its own wiring.
Hovering/clicking the fake icon calls into the existing trigger callbacks
(`onTranslateRequested` / `onSpeakRequested`) — it reuses the translate and
speak behaviour, it does not duplicate or modify the icon's internals.

"Fake" means *separate path that delegates*, not *non-interactive*. The fake
icon is a real floating window that receives mouse events, so **hover and
click both work on it**, exactly like the real icon.

## 2. Behaviour — hover + click both work

| Action | What happens | Notes |
| --- | --- | --- |
| **Hover** | Translate (look up the selected word) | Per surface (see §3). |
| **Click** | Speak — listen to the selected text (TTS) | Uses the source text. No Read. |

There is **no Read action** on this icon. Pressing Read here is meaningless:
the user selected one word inside a long passage, so starting a Fast Read
session on that fragment would lose the long context. The user only wants
to look up one word or listen to it.

The icon shows the **speaker glyph** (click = listen), and hover still opens
the translate flow for lookup. The global "Click icon for:" setting is
ignored here — the icon is always speaker + hover in Read mode.

## 3. Hover differs per surface

- **Fast Read Lite** (panel right, panel already open): hover only switches
  the panel to the **center (translate) tab**. It must NOT call
  `showAtCursor()` — that would move the panel to the cursor. The tab
  switch happens automatically because the panel follows `sourceText`.
- **Window Read** (separate window, panel closed): hover **opens the panel**
  (normal icon flow: panel opens at the cursor on the translate tab).

## 4. When the icon appears

Only when the user is in a Fast Read surface:

- The Window Read window is open, or
- The panel is on the Fast Read (right) tab.

It does **not** appear when selecting text in the translate input or in
Settings. The local mouse-up monitor + `AccessibilityGrabber` read the
selection from TransPeek's own window (the global `SelectionMonitor` only
sees other apps, so it cannot catch a selection inside TransPeek itself).

Auto-detect (block-text hover) is not a conflict: it already turns itself
off while the panel or the icon is visible.

## 5. Scope (what is NOT in this feature)

- No change to the real float icon's logic, glyphs, or settings.
- No Read action from a Fast Read selection.
- No icon in the translate input or Settings.
- TTS word-sync is a separate, later Style 2 follow-up, not part of this.
