# Fast Read (Window Read RSVP) — Design + Logic (as-built)

> Status: **as-built, 2026-11-18** — the current Window Read design and its
> logic, after feedback rounds 1–6 on the `feature/fast-read-feedback`
> branch (CI #235/#236). The UX layout is **locked in as Style 1** (Manh
> 2026-11-18); a different style may be tried later as a separate variant.
> Original design spec: `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`
> §14. The window is called **"Window Read RSVP"** (short: "Read"); the
> popup panel's tabs are **panel left** (shortcuts), **panel center**
> (translate, settled), **panel right** (Fast Read placeholder).

## 1. What it is

- A **separate window** for RSVP speed reading (not a tab of the translate
  panel — the panel is ~400px wide, far too narrow for 50–110px reading
  text, and a tab risks an accidental swipe out mid-read).
- **Read-only.** No TTS inside the Read window (listening is the icon's
  click action, not part of reading). It copies SwiftRead's UX.
- Window: `NSWindow`, title "Fast Read - RSVP", min **880×550**, default
  ~70% of screen width × ~55% of screen height, frame autosaved
  (`TransPeekRSVPWindow`) so macOS remembers size/position. Maximize =
  zoom (not fullscreen).

## 2. Layout — Style 1 (locked in, Manh 2026-11-18)

Top to bottom:

- **Top bar** (compact: padding top 8, bottom 6; label-to-picker spacing 1):
  - **Left:** Speed picker, Text size picker, Words-at-once picker (each a
    label above a menu Picker).
  - **Center:** "Rapid Serial Visual Presentation" — **truly centered** on
    the window via an overlay (it used to sit between two Spacers, so the
    wide left cluster pushed it right of center).
  - **Right:** Settings gear (Color Scheme + context display) and "?"
    (hotkeys popover).
- **Reading area** (fills the middle): the focus line while playing; the
  book page while paused (§3).
- **Completion line + share row** (above the progress bar, shown together
  when the read finishes): "Congratulations!" + share icons (Facebook,
  Threads, X, Reddit, LinkedIn, Mail).
- **Progress bar** (click to seek): "current / total" + a capsule bar.
- **Bottom row:** **"Reading time"** at the **left** (moved from the top
  bar, 2026-11-18); the four controls **centered** (Rewind, Play/Pause,
  Fast-forward, Maximize); the **hint** at the **right** ("Space play/pause
  • ←/→ step • ↑/↓ speed • Swipe ↑/↓ font size"). The controls stay truly
  centered (their own HStack, centered on the full width); the two side
  texts overlay at the leading/trailing edges.
- **Future style idea (NOT implemented, recorded 2026-11-18):** "Reading
  time" stays at the top bar left, and the pickers move to the bottom-left.
  Try as a separate variant later.

## 3. The reading view — focus line pinned at the center (SwiftRead behavior)

This is the core of the design (Manh 2026-11-18, from SwiftRead):

- **The focus line is ALWAYS fixed at the vertical center.** Only the
  number of visible context lines above/below it changes as the read
  progresses. It never drifts.
- **How:** the book page is NOT a ScrollView. The before-text and
  after-text each fill **one half** of the reading area and are **anchored
  to the focus line** (before = bottom-aligned, after = top-aligned);
  overflow is **clipped**, not scrolled. So as the before-text grows, it
  extends upward from the focus line; the focus line stays put. (Before
  this fix the page was a ScrollView, so as the before-text grew the focus
  line drifted down off-center.)
- **Playing (focus mode):** only the focus line, same size, centered.
- **Paused (book page):** the focus line keeps its size on its own
  centered row; the context words above/below are **half the focus size**
  (default focus 64pt → context 32pt) and scale with the chosen size.
  Stepping ←/→ (or swiping trackpad ←/→) while paused moves the focus
  line to the new slide and the context re-renders around it.
- **Context display setting** ("Show context around focus word",
  SwiftRead's `contextDisplayStyle`, in Settings under Color Scheme):
  **Always** (book page even while playing) / **Only show when paused**
  (default, as before) / **Never** (focus line only, even when paused).
  Defaults key `rsvpContextDisplayStyle`.
- **Context:** ±150 words around the current chunk (SwiftRead).

## 4. Engine logic (`Sources/FastRead/RSVPEngine.swift`)

- **Tokenize** (paragraph-aware). **Chunk** 1–6 words at once (default 1).
  **WPM** default 275, max 2000.
- **Delay per slide:** `60000 / WPM × words × (1 + extras) − 30ms`, floored
  at 50ms. Micro-pause extras: digit +0.5, `,;:` +0.9, `.!?` +1.1, long
  word +0.5, paragraph end +1.1. Extras are off when chunk × WPM ≤ 100.
- **ORP pivot:** the middle character of the focus word (`floor(n/2)`),
  highlighted.
- **Reading time label:** "Reading time" (short label; full "Estimated
  reading time" is the tooltip). "Reading time: 2mins"; under a minute →
  "0min".

## 5. Controls, keyboard, and trackpad

- **Buttons (bottom, centered):** Rewind (←), Play/Pause (Space,
  prominent), Fast-forward (→), Maximize (zoom).
- **Keyboard (window focused):** Space = play/pause; ←/→ = step one slide
  (Shift+←/→ = step one sentence); ↑/↓ = speed ±10 WPM; Esc = close.
  (The blue focus ring is hidden with `.focusEffectDisabled()` — the view
  stays focusable so the keys work, just without the ring.)
- **Trackpad (`RSVPTrackpadMonitor`):** horizontal swipe = **one word per
  scroll event** (page-turn convention, SwiftRead-style; a longer swipe
  moves more words); vertical swipe = **font ±2pt** per 50pt of accumulated
  vertical movement (remainder carries); momentum-phase events are
  ignored; mouse-wheel events pass through. **While paused, a vertical
  swipe ONLY changes the text size and NEVER scrolls the block text** (all
  dominant-vertical `.changed` events are consumed).
- **Pickers (menu style, show the nearest option):** Speed
  `[100,150,200,250,275,300,350,400,450,500,600,700,800,1000,1200,1500,2000]`;
  Text size `[40,48,56,64,72,80,88,96,104,110]` (default 64).
  Keyboard/trackpad can set in-between values; the label shows the true
  value.
- **Hint (bottom-right of the controls row, temporary):** "Space
  play/pause • ←/→ step • ↑/↓ speed • Swipe ↑/↓ font size". (It used to
  say "Esc close" — replaced 2026-11-18 because the swipe is the gesture
  a reader wouldn't discover; Esc still closes, it just isn't listed.)

## 6. Share (on completion)

- A row of share icons appears beside the completion line
  ("Congratulations!"), sharing the TransPeek repo link with copy that
  carries the real word count and time: "I just read X words in Y with
  TransPeek Fast Read…".
- Mail pre-fills subject "TransPeek" + body; X / Threads / Reddit
  pre-fill; **Facebook and LinkedIn share the link only** (they cannot
  carry prefilled text — Facebook's `sharer.php` accepts only `u=`; the
  `quote` param was removed in 2017).

## 7. Entries (how to open the window)

- **Option+Click** (Mac) / Alt+Click (Windows) on the float icon.
- Right-click the icon → "Fast Read".
- "Fast Read" button in the translate panel (hides the panel first).
- Menubar → "Reading" section; global shortcut `.fastRead` (no default
  key, fallback).
- Settings toggle swaps Click between Speak and Fast Read (default Speak);
  the icon glyph shows what the click will do (see the icon spec).

## 8. Color schemes

- **White on Black** / **Black on White** (Settings → Color Scheme,
  Defaults `rsvpColorScheme`). Controls render with the chosen scheme
  (`.preferredColorScheme`) so buttons and pickers stay visible on the
  black background.

## References

- Implementation (mac): `Sources/FastRead/RSVPView.swift` (layout, book
  page, controls), `RSVPViewModel` (state), `RSVPEngine.swift`
  (tokenize/chunk/timing/ORP), `RSVPWindowController.swift` (window),
  `RSVPTrackpadMonitor.swift` (swipes), `RSVPShare.swift` (share URLs).
- Original design spec:
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md` §14.
- Icon (entries + glyph): `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md`.
- Panel (the "Fast Read" button):
  `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` §9.
