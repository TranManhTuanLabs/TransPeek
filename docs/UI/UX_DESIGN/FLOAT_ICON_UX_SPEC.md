# Float Icon — UX Spec

> Status: **settled design** (as-built, 2026-11-18) — the icon's shape, gestures,
> glyph states, and the Option-key preview. Windows: implement the same
> behavior; see §6 for the Windows notes (Alt instead of Option, and the
> global key-state read).

## 1. Shape

- A **32×32** window, truly transparent, no bubble. A circle (fill
  `controlBackgroundColor`, border `separatorColor`) with one glyph centered
  at 14pt, weight medium.
- The icon appears near the selected text (offset 8pt right and below the
  cursor, clamped to the visible screen frame) and fades in over 0.15s.

## 2. Gestures and flow (settled)

- **Select text → icon appears.**
- **Hover (default activation mode) → translate.** After the hover delay,
  the translate panel opens.
- **Click → the configured click action.** Settings → "Click icon" chooses
  what a plain click does: **Fast Read** (default — open the reading
  window) or **Speak** (hear it read aloud). A third action, Translate,
  is available in code.
- **Option + Click (Mac) / Alt + Click (Windows) → the OTHER action.**
  When plain click speaks, Option+Click opens Fast Read; when plain click
  opens Fast Read, Option+Click speaks. (The translate action is reachable
  from the right-click menu instead.)
- **In click-activation mode, a click ALWAYS translates** (Option is
  ignored); that mode's whole point is click-to-translate.
- **Right-click → context menu**, including "Fast Read".

## 3. Glyph states — the icon always previews the NEXT click (Style B, Manh 2026-11-18)

### Settled glyph mapping (Manh 2026-11-19 — do NOT change without asking Manh)

The icon has exactly three glyphs, one per action:

- **Plain A** (the main icon, regular weight — **NOT bold**) = **Translate**.
- **A+** (bold "A" + small bold "+", turmeric) = **Fast Read**.
- **Speaker** (`speaker.wave.2.fill`) = **TTS / Speak**.

Two styles of the translate icon (Manh 2026-11-19):

- **Style 1 — the standard / main template:** the plain A, regular weight
  (**NOT bold**), **blue** — "blue highlight/border" means the letter A
  itself is blue (Manh 2026-11-19: like the Style 2 chat icon, where the
  A is blue and the chat-box border wrapping the A is also blue). This is
  the correct translate icon.
- **Style 2 — temporary stand-in:** the chat / speech-bubble icon
  (`character.bubble`). It is **NOT** the translate icon; it is only
  used temporarily in place of Style 1, and kept as a backup style (in
  code and in docs) in case it is ever needed. Windows changed the plain
  A to the chat icon by mistake 1–2 builds ago; Manh caught it testing
  build 191 and had it reverted to the plain A (2026-11-19). This mapping
  is the same on Windows (Alt instead of Option).

The icon's glyph shows what the next click will do, not what the icon "is":

| Click setting | No Option held | Option held | While speaking |
| --- | --- | --- | --- |
| Fast Read (default) | **A+** (turmeric) | speaker (Speak preview) | speaker (`speaker.wave.2.fill`, accent) |
| Speak | speaker | **A+** (turmeric, Fast Read preview) | speaker |
| Translate | **A** (plain, not bold) | **A+** | speaker |

- **The default icon is A+** (Manh 2026-11-18, round 7): because the
  default click is Fast Read, the icon shows A+ by default — the user
  can tell at a glance that a plain click reads, without opening
  Settings. Holding Option flips it to the speaker (Speak preview).
- **Speaking always wins the glyph** (Manh 2026-11-18, round 7): while
  TTS is playing the icon shows the speaker, so the user can click
  again to stop it — even when the click action is Read. Before this
  fix, an Option+click to Speak (with Click = Read) left the icon on
  A+ once Option was released, because the Read-preview branch returned
  before the speaking check; the user had no way to tell speech was
  playing.

- **The plain A glyph (Style 1)** is the letter "A" drawn as text (like
  A+, not an SF Symbol), regular weight — **NOT bold** — and **blue**
  (the letter itself is blue; that is what "blue highlight/border"
  means). It is the main icon: the icon's identity is "translate", and
  A+ / speaker are the same "A" family showing the other two actions.
- **The A+ glyph** is custom-drawn (not an SF Symbol): a bold "A" (15pt)
  with a small bold "+" (8pt) centered on the A's top-right corner, in
  turmeric — a deep golden amber (`NSColor` red 0.78, green 0.50, blue
  0.05) chosen to read on both light and dark backgrounds. It replaces
  the old `book.pages` glyph for Fast Read.

> **Code gap (2026-11-19):** the Mac code (`TriggerTrackingView.draw()`
> in `Sources/UI/TriggerIcon/TriggerIconController.swift`) still draws
> `character.bubble` (Style 2) for the translate/speak preview — the
> settled mapping above (Style 1 plain A for translate, speaker for speak
> preview) is not in the code yet. Changing it is a small fix (draw the
> plain A / speaker instead of the bubble); do it only when Manh says so.
- **The 2.5s A+ linger:** after any Fast Read click (plain click,
  Option+Click, or right-click menu), the icon shows A+ for 2.5 seconds
  while the Read window opens, then hides — a confirmation so the user
  knows Fast Read was triggered even before the window appears. During
  those 2.5s further clicks are ignored (no double window, no speaking
  over the Read window). The 2.5s applies to ALL Read triggers, not just
  plain clicks.

### Future idea — translate-first icon (NOT implemented, Manh 2026-11-19)

The current A+ default above has a real advantage: the user can tell at a
glance that Click is set to Fast Read, without opening Settings. A possible
future change — **not to be done now** — is to follow the translate-first
concept instead. When the Click setting is Fast Read:

- the icon shows the plain translate **A** as normal (hover = translate
  is the icon's primary job);
- a plain click shows **A+** (Fast Read);
- Option+Click shows the **speaker** (Speak).

So the icon's idle state stays "translate", and A+ / speaker appear as the
feedback for the action that was just triggered — instead of Style B's
preview of the *next* click. Recorded here so the idea is not lost;
implement only when Manh asks. The same note applies to Windows (Alt
instead of Option).

## 4. Auto-hide

- The icon hides by itself after the auto-hide delay (Settings → General,
  Slider 3–10s, default **5s**, Defaults key `autoHideDelaySec`;
  `TriggerIconController.startAutoDismissTimer()` reads it).
- The auto-hide is **PAUSED** while: the cursor is over the icon; the icon
  is speaking; **Option is held** (so the A+ preview doesn't vanish before
  the user can click it); a Read open is pending (the 2.5s linger has its
  own timer). On Option release, the auto-hide restarts (fresh 5s).

## 5. How Option is detected — the correct mechanism (and the bug it replaces)

This is the part another implementation (and Windows) must get right.

### The bug (found by Manh testing build #235, 2026-11-18)

The first implementation used a **local** flags monitor:
`NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)`. It did not
work: holding Option while the icon was visible changed nothing; the glyph
only flipped to A+ when the mouse hovered the icon. Cause: the user selects
text in **another app**, so the Option key press is delivered to **that
app**, not to TransPeek — a local monitor only sees events for its own app,
so it never fires. The hover worked only because the mouse-enter handler
re-reads the key state directly (see below).

### The correct mechanism (fix, round 6, 2026-11-18)

**Poll the global modifier state** while the icon is visible:

- Every **0.1s**, read `NSEvent.modifierFlags.contains(.option)`.
  `NSEvent.modifierFlags` returns the **global hardware modifier state**,
  so it works no matter which app is frontmost.
- Only act when the state **actually changed** (keep a `lastOptionHeld`;
  compare each poll). A no-change poll must never restart the auto-hide
  timer — otherwise the icon would never auto-hide (the 5s timer would
  keep resetting).
- Start the poll timer in `show()`; stop it in `cleanup()`. Set the
  initial state from `NSEvent.modifierFlags` at show time (the user may
  already be holding Option when the icon appears), and if Option is
  already held, pause the auto-hide immediately.
- Safety nets: re-check the Option state on mouse-enter (in case a poll
  was missed), and update the glyph through `updateOptionPreview(optionHeld:)`
  which both flips the glyph and pauses/resumes the auto-hide.
- The poll only runs while the icon is visible, so the cost is negligible.

### What NOT to do

- Do **not** use a local-only key/flags monitor to detect Option/Alt held
  in another app — it will silently never fire (the bug above).
- Do **not** restart the auto-hide timer on every poll — only on a real
  state change.
- Do **not** use a global event monitor that requires Accessibility unless
  the app is guaranteed to have it; polling `NSEvent.modifierFlags` needs
  no special permission.

## 6. Windows notes (for TransPeek-Windows)

- **Alt replaces Option** everywhere (Alt+Click = the other action, Alt
  held = preview flip).
- The same bug applies on Windows: a key handler that only fires when the
  TransPeek window is focused will **not** see Alt held while the user is
  in another app. Read the **global** Alt state instead (e.g.
  `GetAsyncKeyState(VK_MENU)` / the keyboard-state API, polled on a short
  timer while the icon is visible), and only act on a real state change.
- The A+ glyph, the 2.5s linger, the auto-hide pause while Alt is held,
  and the glyph table in §3 are identical on Windows.
- Hover delay and auto-hide defaults match mac: hover 500ms, auto-hide
  **5s** (Windows changed 3s → 5s, 2026-11-18).

## 7. Settings (Defaults keys)

- `triggerClickAction`: `.read` (default, Manh 2026-11-18, round 7 — was
  `.speak`) / `.speak` / `.translate`.
- `triggerActivationMode`: `.hover` (default) / `.click`.
- `hoverDelayMs`: default 500 (Slider 300–800).
- `autoHideDelaySec`: default 5 (Slider 3–10).

## References

- Implementation (mac):
  `Sources/UI/TriggerIcon/TriggerIconController.swift`
  (`TriggerTrackingView` draws the glyph; `updateOptionPreview` +
  `startOptionPollTimer` are the Option mechanism).
- Feature doc: `docs/FEATURES/FLOAT_ICON.md`.
- Window Read: `docs/FEATURES/FAST_READ.md`.
- Original flow decisions:
  `docs/RESEARCH/tts-speechify-naturalreader/recommendation.md`.
