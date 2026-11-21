# Fast Read — Theme & Reading Style

Design spec for the Fast Read reading theme and reading styles, shared by
both reading surfaces: the **Window Read** window and the **Fast Read Lite**
panel (panel right). Settled 2026-11-21 (Manh). Style 1 is the current,
locked design; Style 2 is being built (approved 2026-11-21).

## 1. Naming — Theme vs Style

Two independent axes. Do not conflate them. These definitions are the
reference for anyone (and any AI) working on the reading UI — use these
words, not "theme" for a layout or "style" for a colour.

- **Theme** = colours only: the reading background and the text colour
  (light / dark / sepia, …). This is the standard meaning of "theme" in
  reading apps (Kindle, Apple Books both call it that). A theme changes
  colours, never layout.
- **Style** = the reading mode + layout. Style 1 is the current mode
  (focus line, around text above/below, focus in the middle). Style 2 is
  the plain-page reading mode (scroll the whole page, zoom the text,
  focus / highlight line optional). The buttons + button positions follow
  each Style, because each reading mode has its own controls.

Any style works with any theme. In Settings these are two separate picks:
"Reading style" and "Theme".

## 2. Theme (current)

The only theme that exists today is `RSVPColorScheme`
(`Sources/Utilities/Constants.swift`, Defaults key
`transpeek_rsvpColorScheme`, default `.light`). It applies to **both**
surfaces — the Window Read window and the Fast Read Lite panel share the
same view model colour scheme, so one pick colours both.

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

The current Fast Read. Treat as locked; do not keep revising it. One style,
two surfaces — the same reading core, different chrome.

**Shared core (both surfaces):** one chunk (1–6 words, default 1) pinned
at the vertical centre, ORP (optimal recognition point) on the middle
character. The focus line is fixed at the centre; the two halves
above/below share the rest of the height. The around text is the words
before the current chunk (top half, anchored to the bottom) and after it
(bottom half, anchored to the top), so the words nearest the focus line sit
just above/below it. Overflow is clipped, not scrolled. The around text is
selectable (for translate); selection still works with scrolling disabled
(see §6). Both surfaces share only the reading logic (`RSVPEngine` +
`RSVPViewModel` — chunking, timing, ORP, current slide, settings); the
focus line uses the shared `ORPLineView`, so the two can never drift apart.

**Window Read** (`Sources/FastRead/RSVPView.swift`): the full window.
Horizontal padding 32pt. Full chrome — top bar with the four pickers
(Speed / Focus size / Context size / Words at once), progress, the
control row (Restart left of Rewind, then Play / Forward), completion
("Congratulations!" + "Reading time") + share row.

**Fast Read Lite** (`Sources/FocusTimer/PanelFastReadView.swift`,
`CompactReadingView`): the compact in-panel version. Horizontal padding
12pt (the panel is narrow). The focus font is NOT capped — the user swipes
up/down freely and fits the size to the frame. The chrome adapts to the
available size:
- While PLAYING: only the focus line (+ context when the style is
  Always) and the shortcut hint — no buttons, no descriptions.
- While PAUSED at the panel's default size: the book page, then compact
  chrome — the same four pickers + Settings + "?" at the top-right, a
  small progress bar above bottom-centre X / Restart / Rewind / Play /
  Forward / Maximize buttons.
- While PAUSED at (near-)maximum panel size (content width ≥ 540, i.e.
  panel width ≈ 580+ of the 600 max): the full window chrome — pickers
  top bar, progress, the 6-button control row (X first, then Restart /
  Rewind / Play / Forward / Maximize) with Reading time + hint,
  completion + share.

**Defaults (shared):** speed 500 WPM (50–2000, step 50); focus size 80
(40–450); context size 40% (25–100%); context display "Only show when
paused"; auto-play ON; colour scheme Light. All persisted in `Defaults`
(`rsvpWPM`, `rsvpFontSize`, `rsvpContextSizeRatio`,
`rsvpContextDisplayStyle`, `rsvpAutoPlay`, `rsvpColorScheme`).
**Context display** (`RSVPContextDisplayStyle`): Always / Only show
when paused (default) / Never. This is when the around text shows, not
a theme.
**Input:** trackpad horizontal = previous/next word, vertical = font
size; fast vertical swipe = 4x.

## 4. Style 2 — "basic reading" (being built)

Temporary name: "basic reading". A plain reading page, not an RSVP window.
Settled direction (Manh 2026-11-21); approved to build 2026-11-21. It
applies to both surfaces the same way Style 1 does (Window Read gets the
full page, Lite gets the compact page).

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
is shared across styles and across both surfaces.

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
- Lite panel view (shares the colour scheme and the reading logic):
  `Sources/FocusTimer/PanelFastReadView.swift` (`CompactReadingView`,
  `bookPage`).
- TTS read-along research:
  `docs/RESEARCH/tts-speechify-naturalreader/`.

## Related docs

- [Fast Read — Select Shows Icon](FAST_READ_SELECT_ICON.md) — the fake
  icon that appears when selecting text inside Fast Read.
- [Fast Read (feature)](../../FEATURES/FAST_READ.md) — the reading
  surfaces this theme/style spec applies to.
