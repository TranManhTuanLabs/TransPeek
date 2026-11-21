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
  The Lite Settings popover (`CompactReadingView.settingsPopover`)
  has the same segmented picker, by the same names.
- **Theme 2 is Dark, already here (Manh 2026-11-21):** the two
  themes are Light ("Black on White") and Dark ("White on Black").
  There is no new theme to build — "Theme 2" is the Dark scheme
  that already exists. Both are selectable by NAME in both Settings
  popovers; they are never labelled "Theme 1" / "Theme 2" in the UI.
  No layout change to the theme picker was needed (it already sits
  at the top of both popovers, shown by name).
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

## 4. Style 2 — "basic reading" (first version shipped 2026-11-21)

Temporary name: "basic reading". A plain reading page, not an RSVP window.
Settled direction (Manh 2026-11-21); approved to build 2026-11-21. It
applies to both surfaces the same way Style 1 does (Window Read gets the
full page, Lite gets the compact page).

### Shipped (2026-11-21, first version)

- **Reading Style picker** in both Settings popovers (Window Read and
  Lite): "RSVP Focus" (Style 1, default) / "Basic Reading" (Style 2),
  persisted in Defaults (`transpeek_rsvpReadingStyle`, default Style 1).
  Named, not numbered. "Reset to default" does not reset it (a mode
  preference, like the theme).
- **Layout:** a scrollable page — the whole text in a `ScrollView`,
  read by scrolling like a normal document. No focus line by default
  (pure page). Font zoom reuses the existing focus-size control
  (body size = focus size × 0.4, so the default 80 reads as 32pt).
- **Focus line (merged into Style 2, not a separate Style 3):** Style 2
  has a focus line like Style 1's focus word, but per line — Play
  advances the focus line one line at a time (Style 1 advances one
  word/chunk at a time), each line timed by its word count and the WPM
  setting. The page scrolls to keep the focused line in view. The
  focus line is Style 2's way of displaying focus, so it belongs to
  Style 2; splitting it out would make a Style 3 that is 95% identical
  to Style 2.
- **Highlight current line:** a separate on/off toggle inside Style 2
  (not a style of its own). Default OFF (pure page); it turns itself on
  while TTS is playing, so the spoken line stays visible.
- **Lines are logical, not visual:** paragraphs are split into lines of
  at most 12 words (`RSVPViewModel.style2Lines`). The split does not
  follow the visual wrap (which depends on font size and window width).
- **Shared controls:** progress bar, position label ("3 / 42" counts
  lines in Style 2), seek, Restart, Play/Pause, Rewind, Forward and the
  speaker button all work in Style 2. Switching style mid-read keeps
  the fractional position and restarts playback in the new unit.
- **Speaker / TTS is available in every style** (a universal option, not
  tied to a style). The styles differ only in how highlight / focus is
  displayed. The speaker button works in Style 2 too.
- **Style 1 is pixel-identical** when Style 2 is not selected (the Style
  1 body path is untouched; Style 2 branches before it).

### Speaker button (shipped 2026-11-21, both surfaces; synced 2026-11-21)

- One shared component (`Sources/FastRead/SpeakerButton.swift`), in the
  Window Read control row and in both Lite control rows (compact and
  full-size): Restart, **Speaker**, Play, **Rewind**, Forward, Maximize
  (Lite: X first). Rewind moved left of Forward (mirroring a media
  player's ◀ ▶ pair).
- The speaker is a **TTS on/off toggle for the read-along** (Manh
  2026-11-21, CI314 fix — it is NOT a separate "speak the whole text"
  action): when TTS is on, Play/Space speaks each slide (Style 1) or
  line (Style 2) as it shows, and the reader advances ONLY when that
  unit finishes speaking — the speech is the clock, so audio and text
  stay in sync (SwiftRead / Speechify read-along model). When TTS is
  off, the read is silent (WPM timer). Persisted
  (`transpeek_rsvpTTSEnabled`, default OFF). Icon:
  `speaker.wave.2.fill` while TTS is on, `speaker.slash.fill` while
  off. Pausing, restarting or switching style stops the audio, so it
  never keeps running after the reader stops.
- Hovering the speaker shows a voice picker (installed EN/VI system
  voices, same source and same stored keys `ttsVoiceEN` / `ttsVoiceVI`
  as Settings → TTS). The picker is a **non-modal overlay attached to
  the button, not a popover** (Manh 2026-11-21, CI314 fix): a popover
  swallowed the first click to dismiss itself, so the user had to click
  the speaker twice. Clicking the speaker now toggles sound at once
  while the picker stays open.
- Hidden in the Rest window (no TTS coordinator is wired there), so it
  never shows a dead button.

### Fast hints (shipped 2026-11-21, both surfaces)

- One shared custom hover-tooltip component
  (`Sources/UI/Components/HoverTooltip.swift`, `.hoverTooltip(...)`),
  300 ms delay (matching the app's registered `NSInitialToolTipDelay`),
  used on the control-row buttons in both `RSVPView` and
  `CompactReadingView`. The system `.help()` tooltip is kept on every
  button as a fallback. The custom tooltip was needed because `.help()`
  never fires in the non-activating Lite panel and is slow in the
  Window Read — the app already registers `NSInitialToolTipDelay: 300`,
  which was not enough on its own.

### Deferred (not in this round)

- **Full TTS word-sync highlighting** (line + word highlight synced to
  audio, Speechify / NaturalReader model — see
  `docs/RESEARCH/tts-speechify-naturalreader/`): the highlight here is
  the current-line highlight only. Word-sync is the deeper Style 2
  follow-up.
- **Visual line matching:** Style 2 lines are logical 12-word chunks,
  not the visual wrapped lines. Matching the visual lines is a later
  refinement.
- **The exact split between "focus line" (the line the focus advances
  along) and "highlight line+word" (the line + word highlight during
  TTS sync)** — how they overlap and which one drives which. Partially
  settled in this round (the focus line is the line Play advances; the
  highlight is the visual marker on the current line); the full split
  is decided when word-sync is built.
- **Rest window speaker:** TTS is not wired into the Rest window, so
  its speaker button stays hidden. Wiring it is a separate decision.

## 5. Settings model (shipped 2026-11-21)

Two independent picks, any combination valid:

- **Reading style:** Style 1 (RSVP focus, default) / Style 2 (basic
  reading). Persisted (`transpeek_rsvpReadingStyle`); "Reset to default"
  does not reset it.
- **Theme:** Light (default) / Dark. Persisted
  (`transpeek_rsvpColorScheme`); "Reset to default" does not reset it.

Each style keeps its own settings (Style 1: speed, focus size, context
size, context display; Style 2: font zoom via focus size, highlight
toggle). The theme is shared across styles and across both surfaces.
The speaker button and the fast hover tooltips are shared across both
styles and both surfaces.

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
