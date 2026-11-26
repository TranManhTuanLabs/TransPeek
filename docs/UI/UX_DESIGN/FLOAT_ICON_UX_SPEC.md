# Float Icon — UX Spec

> Status: **settled design** (as-built, 2026-11-18) — the icon's shape, gestures,
> glyph states, and the Option-key preview. Windows: implement the same
> behavior; see §6 for the Windows notes (Alt instead of Option, and the
> global key-state read).

## 1. Shape

- A floating window, truly transparent, no bubble. A circle (fill
  `controlBackgroundColor`, border `separatorColor`) with one glyph
  centered inside. The glyph scales with the circle ("A" = half the
  diameter, speaker ~44%, "+" badge a quarter), so a smaller circle
  still shows a proportional letter.
- **Sizes are user-adjustable (Manh 2026-11-21, default changed
  2026-11-22):** the selection icon defaults to **24 pt** (Picker
  18/20/22/24/26/28/30/32 — recommend 20-24pt) and the block-text
  hover icon defaults to **24 pt** (Picker 18/20/22/24 — recommend
  20, 22pt). The hover icon appears on every text block, so it is
  smaller by default and stays out of the mouse's way. Both sizes are
  read live at each show, so a Settings change applies to the next
  icon. (Before 2026-11-22 the selection icon was a fixed 32 pt and
  the hover icon a fixed 24 pt.)
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
  (`character.bubble`). It is **NOT** the translate icon; it was only
  used temporarily in place of Style 1, and is now kept only as a backup
  style **in this doc** (the code no longer draws it since 0.1.5 — see the
  code-gap note below). Windows changed the plain A to the chat icon by
  mistake 1–2 builds ago; Manh caught it testing build 191 and had it
  reverted to the plain A (2026-11-19). This mapping is the same on
  Windows (Alt instead of Option).

The icon's glyph shows what the next click will do, not what the icon "is":

| Click setting | No Option held | Option held | While a playback session is active (playing or paused) |
| --- | --- | --- | --- |
| Fast Read (default) | **A+** (turmeric) | speaker (Speak preview) | speaker (`speaker.wave.2.fill`, accent) |
| Speak | speaker | **A+** (turmeric, Fast Read preview) | speaker |
| Translate | **A** (plain, not bold) | **A+** | speaker |

- **The default icon is A+** (Manh 2026-11-18, round 7): because the
  default click is Fast Read, the icon shows A+ by default — the user
  can tell at a glance that a plain click reads, without opening
  Settings. Holding Option flips it to the speaker (Speak preview).
- **Speaking always wins the glyph** (Manh 2026-11-18, round 7; updated 2026-11-26): while
  a TTS playback session is active — playing or paused — the icon shows
  the speaker, so the user can click again to pause/resume it — even
  when the click action is Read. The icon stays visible for the whole
  session and only hides once the session fully stops (end of unit or
  Esc); it does not hide on pause, so the user can always resume. Before this
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

> **Code gap — ĐÃ SỬA (2026-11-19, 0.1.5):** the Mac code
> (`TriggerTrackingView.draw()` in
> `Sources/UI/TriggerIcon/TriggerIconController.swift`) now draws the
> settled mapping above: plain blue A (Style 1, regular weight, drawn as
> text) for translate, speaker (`speaker.wave.2.fill`, accent) for the
> speak preview. The chat bubble (`character.bubble`, Style 2) is no
> longer drawn anywhere in the icon — it stays only as a backup style in
> this doc, not in code. Manh caught the gap testing v0.1.4 (Click = Read
> + hold Option showed the bubble instead of the speaker) and ordered the
> fix as part of the 0.1.5 batch.
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
- The auto-hide is **PAUSED** while: the cursor is over the icon; a TTS
  playback session is active (playing **or paused** — the icon must stay
  visible until the session fully stops, so the user can pause/resume it);
  **Option is held** (so the A+ preview doesn't vanish before the user can
  click it); a Read open is pending (the 2.5s linger has its own timer).
  On Option release, the auto-hide restarts (fresh 5s).

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
- `hoverDelayMs`: default 500 (Picker: 300 / 400 / 500 / 600 / 700 / 800 ms —
  changed from Slider 2026-11-20, Manh). This is the delay before the
  translate panel opens on hover — NOT the block-text detection delay
  (see §8).
- `autoHideDelaySec`: default 5 (Picker: 3–10 s — changed from Slider
  2026-11-20, Manh).
- `floatIconSize`: default 24 (Picker: 18 / 20 / 22 / 24 / 26 / 28 / 30 /
  32 pt — recommend 20-24pt; default was 26 before 2026-11-22, Manh).
- `autoShowFloatIconSize`: default 24 (Picker: 18 / 20 / 22 / 24 pt —
  recommend 20, 22pt; Manh 2026-11-21).
- `isHoverBlockDetectionEnabled`: default `true` — the "Show icon when
  hovering text" toggle (Settings → General → Translation, inside "Show
  floating icon on text selection"; Manh 2026-11-21). Master
  auto-detect (`isAutoDetectEnabled`) must also be on.
- `hoverBlockDelayMs`: default 400 (Picker: 200 / 300 / 400 / 500 / 700 ms,
  shown in Settings as 0.2 / 0.3 / 0.4 / 0.5 / 0.7 s — Manh 2026-11-21).
  How long the mouse must stay still over a text block before the hover
  icon appears (see §8).

## 8. Block-text detection — auto-show on hover (settled, Manh 2026-11-21)

What auto-detect has achieved (verified: Manh tested it and confirmed
"auto nhận block text ngon rồi", 2026-11-21). The full behaviour is in
the feature doc (`docs/FEATURES/FLOAT_ICON.md` §3); this section is the
UX-spec record of the same settled behaviour.

- **Hovering a text block in another app shows the float icon without
  selecting the text first.** After the icon appears, the flow is the
  normal icon flow (§2): hover → translate panel; click → Speak / Fast
  Read per "Click icon for:"; Option+Click → the other action.
- **Model A (how a block is found):** one Accessibility hit-test per
  hover point (`AXUIElementCopyElementAtPosition`), then read the text
  of the element under the cursor — or its nearest text-bearing ancestor,
  at most 5 levels up (was 3; raised to 5 in step 1, 2026-11-23 — the
  hit-test usually lands on the text itself, so 3 was enough, but 5
  costs almost nothing and covers deeply nested inline spans). One
  point, one parent chain, never a tree scan. A link is climbed past,
  not stopped at (step 1, 2026-11-23): a link is part of its sentence,
  so hovering a link inside a paragraph summons the icon for that
  paragraph; the link's own text is never taken. Every other control
  still stops the walk. Model B (scan the whole accessibility tree /
  show the icon on every block) is NOT done — too expensive on CPU
  and does not follow scrolling.
- **Debounce:** the icon appears only after the mouse has stayed still
  over a text block for the "Hover text delay" (`hoverBlockDelayMs`,
  default 400 ms; Picker 200–700 ms). Sweeping the mouse across text
  costs one hit-test (only the last position in the window is tested),
  so it does not flicker the icon or burn CPU.
- **What counts as a block (v1 limits):** at least 4 characters and at
  most 2000 characters, carrying at least one letter or digit (not just
  punctuation) — short enough that headings and short phrases work, long
  enough that stray 1–3 letter UI labels do not summon the icon, and
  capped so a whole document is never treated as a block (the user can
  still select manually). Buttons, links and other controls never summon
  the icon, and neither does anything above one (a button inside a big
  text container must not surface the container's text). Window chrome
  (window/dialog/menu) is never read as text. TransPeek's own windows
  are skipped, and the excluded-apps list applies, same as selection.
- **Same block, no re-show:** a hit with the same frame and the same
  text start (first 40 characters, prefix match) counts as the same
  block — a re-layout or a second hit-test does not re-show the icon.
- **Follow / stale:** while the icon is up, the block's frame is re-read
  every 0.3 s. If it moved more than 10 pt (the text scrolled away) or
  the element is gone, the icon is dismissed as stale; moving the mouse
  re-detects. The poll stops the moment the icon is dismissed. While a
  playback session is active (playing or paused), the icon is never
  dismissed as stale (the user needs it to pause/resume/stop playback).
- **Suppress after dismiss:** 500 ms after a dismiss, a tiny mouse move
  does not re-summon the icon at once.
- **Gates (never fire):** no hit-test while dragging (a selection is in
  progress — the selection flow owns the mouse); no delivery while the
  icon or the panel is already up (a hover never yanks another flow's
  icon); the master auto-detect and the feature toggle must both be on.
- **Scope:** only apps that expose text via Accessibility work. Apps or
  places that do not expose text are out of scope (separate research) —
  hovering there simply does nothing.
- **Tests:** the pure decision rules (`shouldAccept`, `isSameBlock`) are
  unit-tested; the AX calls only run on a real Mac.

### Spec snapshot — thresholds (v1, recorded 2026-11-23)

The current tuning, in one place, so a later change can be compared
against it. Note: the 2000 limit counts **characters, not words** —
2000 characters ≈ 300–400 words.

| Threshold | Value | Where |
|---|---|---|
| Max parent levels to climb | 5 (was 3; raised in step 1, 2026-11-23) | `HoverBlockText.maxParentLevels` |
| Block length | ≥ 4 and ≤ 2000 characters (trimmed), ≥ 1 letter/digit | `HoverBlockText.shouldAccept` |
| Hover delay (debounce) | default 400 ms; Picker 200/300/400/500/700 ms | `hoverBlockDelayMs`, Settings → General → Translation |
| Follow poll | every 0.3 s | `HoverTextDetector` |
| Stale move | > 10 pt | `HoverTextDetector` |
| Suppress after dismiss | 500 ms | `HoverTextDetector` |
| Same-block dedup | same frame + same first 40 chars (prefix match) | `HoverBlockText.isSameBlock` |
| Hover icon size | default 24 pt; Picker 18/20/22/24 pt | `autoShowFloatIconSize` |
| Text source order | value → title → description (first non-empty) | `HoverBlockText` |

### Decisions — done / not doing / not yet done (2026-11-23)

- **ĐÃ LÀM (done, settled):** Model A (one hit-test, ≤ 5 levels up
  since step 1, 2026-11-23 — was ≤ 3; links are climbed past, other
  controls still stop the walk); 4–2000 char limits (2000 kept —
  research 2026-11-23 measured real news paragraphs at median
  116–189 chars, longest 316, none over 500, so 2000 has 6–10x
  headroom; raising it would let whole pages through as "blocks");
  debounce 400 ms; follow/stale poll; suppress 500 ms; same-block
  dedup; gates (no drag, no delivery while icon/panel up, master +
  feature toggles); Settings toggle (default ON), delay + icon size
  pickers; unit tests for the pure rules.
  (Manh confirmed "auto nhận block text ngon rồi", 2026-11-21.)
- **KHÔNG LÀM (not doing, no plan):** Model B (scan the whole tree /
  icon on every block) — too expensive, and it does not follow
  scrolling.
- **CHƯA LÀM (not yet, separate work):** apps that do not expose text
  via Accessibility — out of scope for now, separate research task
  (hovering there does nothing today). Threshold review — research
  DONE 2026-11-23 (3→5, keep 2000, Speechify/Natural Reader read
  the whole article continuously, TransPeek reads one block then
  stops); step 1 is the ĐÃ LÀM above. Step 2 — "đọc nối tiếp"
  (after Speak finishes one block, find the next block and keep
  reading until the end or the user stops) — frame approved 2026-11-24
  (branch `feature/continuous-reading`, work in the next session);
  trial plan (vertical line + sentence/block highlight + scroll
  fallback + 2 test phases):
  `docs/RESEARCH/tts-speechify-naturalreader/step2-trial-plan.md`.
  Step 3 — "Đọc cả bài" (extract
  the article's main content into Fast Read + TTS) — later, its own
  feature, frame to be presented first. Manh 2026-11-23 (revised
  16:55): step 3 is the FILE reader only — the RSVP window becomes
  a reader like Apple Books, opening local files in various formats
  (PDF, Word, Markdown, ...) and reading them in the RSVP interface.
  Web articles do NOT go into the reader: extracting them would leave
  a copy to delete and break the on-page reading flow. Web is read
  continuously ON the page instead (step 2 "đọc nối tiếp" — chain
  blocks, like Speechify). Reading PDF is Pro for sure; free vs Pro
  for the other formats undecided; PDF is NOT done now — later. Still open: does the icon show in Word for Mac (unknown
  what Word returns via AX — if it returns the whole document, the
  2000 cap blocks the icon) — needs a real-Mac test.

## References

- Implementation (mac):
  `Sources/UI/TriggerIcon/TriggerIconController.swift`
  (`TriggerTrackingView` draws the glyph; `updateOptionPreview` +
  `startOptionPollTimer` are the Option mechanism).
  Block-text detection: `Sources/Core/TextSelection/HoverTextDetector.swift`
  (`HoverBlockText` rules + `HoverTextDetector` mouse watch, debounce,
  follow/stale poll).
- Feature doc: `docs/FEATURES/FLOAT_ICON.md`.
- Step 2 trial plan: `docs/RESEARCH/tts-speechify-naturalreader/step2-trial-plan.md`.
- Window Read: `docs/FEATURES/FAST_READ.md`.
- Original flow decisions:
  `docs/RESEARCH/tts-speechify-naturalreader/recommendation.md`.
