# Window Read — Theme & Reading Style

Design spec for the Window Read (and Fast Read Lite) visual theme and reading
styles. Settled 2026-11-21 (Manh). Style 1 is the current, locked design;
Style 2 is planned, not built yet.

## 1. Naming — Theme vs Style

Two independent axes. Do not conflate them.

- **Theme** = colours only: the reading background and the text colour
  (light / dark / sepia, …). A theme changes colours, never layout.
- **Style** = the reading mode + layout: where the focus text sits, where the
  around text sits, whether there is a focus line, and the buttons + button
  positions that belong to that mode. Each style defines its own controls.

Any style works with any theme. In Settings these are two separate picks:
"Reading style" and "Theme".

## 2. Theme (current)

The only theme that exists today is `RSVPColorScheme`
(`Sources/Utilities/Constants.swift`, Defaults key
`transpeek_rsvpColorScheme`, default `.light`). It applies to **both** the
Window Read window and the Fast Read Lite panel — they share the same view
model colour scheme.

| Scheme | Display name | Background | Focus text | Around text |
| --- | --- | --- | --- | --- |
| `.light` (default) | Black on White | White | Black | Black 60% |
| `.dark` | White on Black | Black | White | White 60% |

- Picked in the Window Read Settings popover, segmented picker
  "Color Scheme" (`RSVPView.settingsPopover`). It also drives
  `.preferredColorScheme`, so the whole window follows the scheme.
- It is a theme preference: "Reset to default" does **not** reset it
  (only speed, focus size, context size, context display and auto-play
  reset).
- Future themes (e.g. sepia) add cases to `RSVPColorScheme`; the picker
  lists `allCases`, so no UI change is needed.

## 3. Style 1 — RSVP focus (current, default, locked)

The current Window Read. Treat as locked; do not keep revising it.

- **Focus:** one chunk (1–6 words, default 1) pinned at the vertical centre
  of the window, ORP (optimal recognition point) on the middle character.
  The focus line is fixed at the centre; the two halves above/below share
  the rest of the height.
- **Around text:** the words before the current chunk (top half, anchored
  to the bottom) and after it (bottom half, anchored to the top), so the
  words nearest the focus line sit just above/below it. Overflow is
  clipped, not scrolled. The around text is selectable (for translate);
  selection still works with scrolling disabled (see §6).
- **Controls:** Play/Pause, Rewind, Restart (left of Rewind), speed,
  focus size, context size, context display, colour scheme, share row on
  completion ("Congratulations!" + "Reading time").
- **Defaults:** speed 500 WPM (50–2000, step 50); focus size 80
  (40–450); context size 40% (25–100%); context display "Only show when
  paused"; auto-play ON; colour scheme Light. All persisted in `Defaults`
  (`rsvpWPM`, `rsvpFontSize`, `rsvpContextSizeRatio`,
  `rsvpContextDisplayStyle`, `rsvpAutoPlay`, `rsvpColorScheme`).
- **Context display** (`RSVPContextDisplayStyle`): Always / Only show
  when paused (default) / Never. This is when the around text shows, not
  a theme.
- **Input:** trackpad horizontal = previous/next word, vertical = font
  size; fast vertical swipe = 4x. The same view model drives the Fast
  Read Lite panel (compact form).

## 4. Style 2 — "basic reading" (future, planned)

Temporary name: "basic reading". A plain reading page, not an RSVP window.
Settled direction (Manh 2026-11-21); **not built yet**. Do not start it
without Manh's go-ahead.

- **Layout:** a scrollable page — read the whole text by scrolling, like a
  normal document. No focus line by default (pure page). Font zoom adjusts
  the text size for comfortable reading.
- **Focus line (merged into Style 2, not a separate Style 3):** Style 2
  has a focus line like Style 1's focus word, but per line — the button
  advances the focus line one line at a time (Style 1 advances one
  word/chunk at a time). The focus line is Style 2's way of displaying
  focus, so it belongs to Style 2; splitting it out would make a Style 3
  that is 95% identical to Style 2.
- **Highlight current line:** a separate on/off toggle inside Style 2
  (not a style of its own). Default OFF (pure page); it turns itself on
  while TTS is playing, so the spoken line stays visible.
- **Play + TTS (read-along):** the Play button still works, but runs the
  text differently — normal reading plus audio. Modelled on
  Speechify / NaturalReader (see `docs/RESEARCH/tts-speechify-naturalreader/`):
  highlight the line being read **and** the word being read, with the
  audio synced to the displayed text (word-sync).
- **Speaker / TTS is available in every style** (a universal option, not
  tied to a style). The styles differ only in how highlight / focus is
  displayed.
- **Deferred to the Style 2 build:** the exact split between "focus
  line" (the line the focus advances along) and "highlight line+word"
  (the line + word highlight during TTS sync) — how they overlap and
  which one drives which. Decide when Style 2 is implemented, not now.

## 5. Settings model (target)

Two independent picks, any combination valid:

- **Reading style:** Style 1 (RSVP focus, default) / Style 2 (basic
  reading, when built).
- **Theme:** Light (default) / Dark (more later).

Each style keeps its own settings (Style 1: speed, focus size, context
size, context display; Style 2: font zoom, highlight toggle). The theme
is shared across styles.

## 6. Known issue (Style 1)

Clicking the around text still zooms it (the trackpad font-size gesture
reaches the selectable context text). The `.scrollDisabled(true)` fix
(2026-11-21) stopped the around text scrolling, but not the zoom-on-click.
Do **not** deeply disable scrolling to fix this if it would affect future
styles — the current Style 1 look is approved as-is. Fix it only if there
is a clean, style-safe way; otherwise leave it.

## Source references

- Theme enum + Defaults keys: `Sources/Utilities/Constants.swift`
  (`RSVPColorScheme`, `RSVPContextDisplayStyle`, `rsvpColorScheme`,
  `rsvpContextDisplayStyle`).
- Window Read view + settings popover: `Sources/FastRead/RSVPView.swift`
  (`RSVPViewModel`, `settingsPopover`, `bookPage`).
- Lite panel view (shares the colour scheme):
  `Sources/FocusTimer/PanelFastReadView.swift` (`CompactReadingView`).
- TTS read-along research:
  `docs/RESEARCH/tts-speechify-naturalreader/`.
