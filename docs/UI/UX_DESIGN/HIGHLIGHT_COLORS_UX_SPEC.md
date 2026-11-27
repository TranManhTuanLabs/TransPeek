# Highlight Colors — UX Spec

> Status: **settled design** (approved by Manh 2026-11-27, implemented on
> `main`) — the user can change the reading indicator's 6 layer colors
> in Settings, and show/hide each layer with its own switch. The overlay
> is created with all six layers; which ones actually show is the
> user's per-layer Show toggle (main defaults: only the word and the
> underline on — see §5). The vertical line can follow the sentence, the paragraph
> (cluster) or the whole block (main default: sentence, see §6), and
> the highlight hides while the page scrolls (toggle, default on, see
> §7). The underline (sixth layer) marks the word + sentence with a
> thin solid line under the text, instead of a rectangle fill.

## 1. Where it lives

Settings → **Audio** tab → section **"Highlight colors"**, after
"Voices (EN / VI)" and before "Test". It sits in the Audio tab because
the indicator belongs to the listen-on-page flow (click-to-listen /
chaining), not to the Read window's theme.

## 2. Layout — 6 rows + presets + Reset all

Each layer gets one block: a settings row, then a preset swatch row
underneath it. The Vertical line row also carries the "Line follows"
picker (see §6). Row order (Manh 2026-11-27 15:57): Underline,
Vertical line, then the fills smallest → largest (Word, Sentence,
Paragraph, Block) — the narrow marks first, the broad fills last.

```
Highlight colors
┌──────────────────────────────────────────────────────────────────┐
│ Underline [i]              #5666F0 Show [x]  [swatch]  Reset     │
│ Underline under the word + sentence being read                   │
│ ( ) ( ) ( ) ( ) ( ) ( )   <- 6 preset swatches                   │
│                                                                  │
│ Vertical line [i]          #8CBFFF Hide [ ]  [swatch]  Reset     │
│ Solid bar at the block's left edge                               │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│ Line follows: [ Sentence | Paragraph | Block ]                   │
│                                                                  │
│ Word [i]                     #5666F0 Show [x]  [swatch]  Reset   │
│ Highlight for the word being spoken                              │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Sentence [i]                 #ABB3FE Hide [ ]  [swatch]  Reset   │
│ Highlight for the sentence being read                            │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Paragraph [i]                #FFC2D1 Hide [ ]  [swatch]  Reset   │
│ Highlight for the paragraph (cluster) being read                 │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Block [i]                    #BFF2B3 Hide [ ]  [swatch]  Reset   │
│ Highlight for the whole block being read                         │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ [Reset all to default]                                           │
│                                                                  │
│ Colors for the reading indicator shown over the page while       │
│ listening. Changes apply at once — no restart needed.            │
│ Opacity is fixed so the text underneath stays readable.          │
│ Use the Show/Hide switch on each row to hide a layer             │
│ you don't want.                                                  │
│ The underline marks the word and sentence with a thin solid      │
│ line under the text, instead of a rectangle fill. The vertical   │
│ line can follow the sentence, the paragraph, or the whole        │
│ block — pick it in the line's row.                               │
└──────────────────────────────────────────────────────────────────┘
```

Each row, left to right:

- **Name + subtitle** — the layer name ("Underline", "Vertical line",
  "Word", "Sentence", "Paragraph", "Block") and one line saying what it marks.
- **Info button ("i")** — a small native `info.circle` button after the
  row's text (Manh 2026-11-27 16:21). Tapping it opens a popover that
  explains how this layer works and how it is detected, in 2–3
  sentences (English, same wording as the popovers in Settings). The
  Vertical line and Paragraph popovers add a "How it works" section
  with the detail (see below); the other four show the explanation
  alone:
  - Underline: "A thin line under the word and sentence being read, in
    the underline color. It shows even when the fills are off, so you
    can use it instead of the fills. No rectangle, so no hard edge."
    (see §4).
  - Vertical line: "A thin vertical bar left of the block, as tall as
    the unit it follows (see 'Line follows': sentence / paragraph /
    block). It helps the eye find the unit being read at a glance."
    Its popover adds a "How it works" section: the "Line follows"
    picker (Sentence / Paragraph / Block, default Sentence on main);
    fallback chosen unit → sentence → cluster, never back to block;
    no frame anywhere means no line; the line still follows the unit
    even when that unit's fill is hidden. (see §6).
  - Word: "Highlights the word being spoken. It needs the app to
    provide the word's position (AXBoundsForRange); if the app does
    not provide it, the word highlight is skipped." (see §4).
  - Sentence: "Highlights the sentence containing the word being
    spoken. It needs the app to provide the sentence's position; if
    the app does not provide it, the sentence highlight is skipped."
    (see §4).
  - Paragraph: "Highlights the paragraph containing the current
    sentence. A paragraph is detected by a blank line, a single line
    break, or an indented line. If the block has no paragraph break,
    the cluster is not shown — the block has its own Show toggle."
    Its popover adds a "How it works" section: the cluster is the
    paragraph containing the sentence being read (blank line, single
    line break, or indented line — an indented line means a tab or 2+
    spaces at the start of the next sentence; a single space does not
    count); a block with no paragraph break has no cluster fill — use
    the block's Show toggle to highlight the whole block. (see §4).
  - Block: "Highlights the whole text block being read. It is always
    available when a block is detected." (see §3).
  The button sits between the text and the hex/Show/picker/Reset
  controls, so it does not move any of them.
- **Hex** — the current color as `#RRGGBB` (monospaced, secondary
  colour). Display-only: it shows the exact value for users who want
  it, it is not an input field. It sits in a tight group with the
  Show/Hide label and the switch immediately left of the switch
  ([hex] [Show/Hide] [switch], Manh 2026-11-27 16:26), so the three
  read as one control, separate from the colour well.
- **Show/Hide switch** — a native `Toggle` next to the colour well.
  Its label follows the state (Manh 2026-11-27 16:24): "Show" while
  the layer is on, "Hide" while it is off, so it always says whether
  the layer is shown or hidden. It hides/shows this layer (see §5).
  The colour stays editable while the layer is hidden, so the user
  can set it first and show it after.
- **Colour well** — the native macOS colour picker (`ColorPicker`,
  `supportsOpacity: false`). Clicking it opens the system colour panel
  (colour wheel, sliders, palettes, eyedropper).
- **Reset** — restores that one layer to its default colour.

Under each row, **6 preset swatches** (22 pt circles): tap one
to set that layer's colour at once. The current colour gets a strong
ring, so the user can see which preset (if any) is active.

Under the Vertical line row only, a **segmented "Line follows"
picker** (see §6): Sentence / Paragraph / Block.

At the end of the section, **"Reset all to default"** restores all six
layers' colours, Show/Hide switches and the "Line follows" picker to the
main defaults (it does not touch the "Hide highlights while scrolling"
toggle below — that is a behaviour preference, not a layer default).

## 3. The 6 layers + default colours

| Layer | What it marks | Default | Opacity | Shown by default (main) |
|---|---|---|---|---|
| Underline | 2.5 pt solid bar under the word + sentence being read | `#5666F0` (indigo, same as the word) | 1.0 (solid) | Yes |
| Vertical line | 1.75 pt wide solid bar at the block's left edge (in the 8 pt strip beside the text); its length follows the unit picked in §6 | `#8CBFFF` (light blue) | 1.0 (solid) | No |
| Word | Fill for the word being spoken | `#5666F0` (Speechify indigo) | 0.30 | Yes |
| Sentence | Fill for the sentence being read | `#ABB3FE` (Speechify light periwinkle) | 0.30 | No |
| Paragraph (cluster) | Fill for the paragraph around the sentence being read — the group of sentences with no paragraph boundary between them (blank line, single line break, or indented next sentence). A block with no boundary has no cluster fill (its single paragraph IS the whole block) | `#FFC2D1` (light pink) | 0.30 | No |
| Block | Fill for the whole block being read | `#BFF2B3` (light green) | 0.30 | No |

The defaults are `#RRGGBB` hex. Block, paragraph and line keep the
pastel palette from the trial (Manh 2026-11-24 00:38): the hex values
are the rounded equivalents of the RGB values the overlay used before
(block 0.75/0.95/0.70, line 0.55/0.75/1.0), so those defaults look
identical to the old hardcoded colours. The paragraph default is light
pink — a preset already in the palette, distinct from the other four
fills; Manh did not pick a colour for it (parent agent's choice,
2026-11-27), change it in Settings if another pink reads better.
Word and sentence follow Speechify (Manh 2026-11-27 03:41 — read from
the Speechify extension source: default theme, light page): the word
is Speechify's highlight50 indigo `#5666F0`, the sentence is
Speechify's highlight30 light periwinkle `#ABB3FE`. Speechify's own
sentence is `#e0e3ff` (highlight20), but at fill 0.30 that is so pale
it is nearly invisible, so the sentence uses the next step up. And
Speechify draws opaque (1.0) while recolouring the text; this overlay
draws over the page and cannot recolour the text, so the fills stay
translucent (0.30) and the text underneath stays readable — the
Speechify hues are adopted, not its opacity. The underline default is
the word's indigo `#5666F0` — the underline marks the word + sentence,
so it shares the word's colour (parent agent's choice, 2026-11-27;
Manh did not pick a colour for it). Draw
order (bottom to top): block, paragraph, sentence, word, then the
line, then the underline — the fills are translucent, so overlapping
levels blend instead of hiding each other; the line and the underline
are solid, so they read on top.

## 4. Behaviour

- **Change applies at once — no restart.** The overlay reads the
  colours from Defaults at draw time, and its follow timer redraws
  every 0.3 s while showing, so a colour picked in Settings shows on
  the next draw (immediately if the indicator is up, otherwise on the
  next listen).
- **Stored as hex strings** in Defaults (`transpeek_highlightLineHex`,
  `transpeek_highlightBlockHex`, `transpeek_highlightClusterHex`,
  `transpeek_highlightSentenceHex`, `transpeek_highlightWordHex`,
  `transpeek_highlightUnderlineHex`), one key per layer. A malformed
  stored value (only possible by hand-editing UserDefaults) falls back
  to that layer's default colour.
- **Opacity is fixed and never editable.** Fills are always 0.30, the
  line is always solid (1.0) — the picker has no opacity control, and
  no opacity is stored. A fully opaque fill would hide the text, and
  the line must read as a marker, not a tint.
- **Hex is display-only.** The hex text next to each well shows the
  current value; the colour is changed with the well (system panel) or
  a preset swatch, never by typing hex.
- **The paragraph (cluster) is the group of sentences around the
  sentence being read, split on paragraph boundaries.** The controller
  splits the block's text into paragraphs at a blank line (2+ line
  breaks between sentences), a single line break (1), or an indented
  next sentence (a tab, or 2+ spaces — a single space is just the
  separator between sentences); books/PDFs often separate paragraphs
  with just one line break or an indented first line, no blank line
  (Manh 2026-11-27 16:14). The cluster fill covers the paragraph
  holding the current sentence and moves with the voice. A block with
  no boundary has NO cluster fill — its single paragraph IS the whole
  block, so there is no cluster to highlight (turn on the block layer
  to mark the whole block; drawing the cluster over it would just
  double the fill — Manh 2026-11-27 16:09). When the app does not
  expose the paragraph's bounds (`AXBoundsForRange` unsupported), the
  cluster fill is simply not drawn — the other layers keep showing.
  The cluster fill is read live from Defaults like the other fills
  (colour + Show toggle). The split rule was verified with a 9-case
  simulation: blank line splits, a single line break splits, a tab
  indent splits, a single space does not split, a CRLF counts as one
  break; a CRLF blank line splits, 3 mixed paragraphs split into 3,
  and a block with only a single space stays 1 paragraph, so it has
  no cluster fill.
- **The line follows its picked unit (§6).** Its length is the picked
  unit's vertical span in the 8 pt strip; it moves with the voice
  when the unit is the sentence or the paragraph. When the picked
  unit has no frame (bounds unsupported) the line falls back to the
  sentence, then to the paragraph; when none of the three has a frame
  there is no line at all — the block is only a chosen unit, never a
  fallback, and losing the line is fine because the fills still mark
  the text. The line still tracks its unit when that unit's fill is
  hidden — hiding the sentence fill does not make a
  sentence-following line jump back to the block.
- **The underline is a thin solid bar (2.5 pt) under the word +
  sentence being read, in its own colour.** It is its own layer: it
  has a colour row in Settings like the other five, with its own Show
  switch, and "Reset all to default" restores it like them. It draws
  even when the word/sentence fills are off — the underline is gated
  only by its own Show/Hide switch — so turning all fills off leaves just
  the underline. When the app does not expose a unit's bounds
  (`AXBoundsForRange` unsupported), that unit gets no underline; the
  other one still shows.

## 5. Show/hide per layer

Each layer has its own **Show/Hide switch** in its colour row (a native
`Toggle` labelled "Show", next to the colour well). Flipping it
hides/shows that layer at once — no restart.

- **Stored as booleans** in Defaults (`transpeek_highlightLineShown`,
  `transpeek_highlightBlockShown`, `transpeek_highlightClusterShown`,
  `transpeek_highlightSentenceShown`, `transpeek_highlightWordShown`,
  `transpeek_highlightUnderlineShown`),
  one key per layer.
- **Main defaults (Manh 2026-11-27 03:03, underline 2026-11-27
  15:57): only the word and the underline on.** Line,
  block, sentence and paragraph are off — a first launch shows just
  the word highlight and its underline until the user turns more layers on. That
  replaces the earlier default (sentence + word + paragraph on):
  Manh wants the first-launch indicator as quiet as possible, with
  the user opting in to the bigger fills.
- **The toggles decide what shows.** The overlay is created with all
  six layers (`.all`); a layer draws only when it is in the creation
  set AND its toggle is on (`ReadingIndicatorOverlay.isShown`). The
  overlay reads the toggles live at draw/update time (the follow timer
  redraws every 0.3 s while showing, and `update` re-lays out on the
  next word), so a flip applies immediately — including mid-speech.
  Turning the line off also drops the 8 pt left strip, so the window
  shrinks to exactly the block frame.
- **Colour stays editable while hidden.** Hiding a layer does not
  disable its row: the user can pick the colour first and show the
  layer after, without losing the pick. "Reset all to default"
  restores all six layers' colours, Show/Hide switches and the "Line
  follows" picker to the main defaults — it does not touch the "Hide
  highlights while scrolling" toggle.
- **All six off is allowed.** The overlay window simply draws
  nothing (transparent) until a layer is turned back on — no error,
  no stale box.

## 6. Line follows — how long the vertical line is

The vertical line used to span the whole block. Now the user picks
what it marks, in a segmented picker in the line's row ("Line
follows"): **Sentence / Paragraph / Block**.

| Choice | The line is as tall as… | Main default |
|---|---|---|
| Sentence | The sentence being read — it moves with the voice, like the sentence fill | Yes |
| Paragraph | The paragraph (cluster) around the sentence being read | No |
| Block | The whole block being read (the old behaviour) | No |

- **Stored as a string** in Defaults (`transpeek_highlightLineFollows`,
  `"sentence"` / `"paragraph"` / `"block"`; main default
  `"sentence"`). An unknown stored value (only possible by
  hand-editing UserDefaults) falls back to `"sentence"`.
- **Applies at once, even mid-speech.** The overlay reads the value
  live; the follow timer redraws every 0.3 s and `update` re-lays out
  on the next word, so flipping the picker moves the line on the next
  draw.
- **Fallback to the sentence, then the paragraph — never the block.**
  When the picked unit has no frame (the app did not expose its
  bounds), the line falls back to the sentence, then to the paragraph;
  when none of the three has a frame there is no line at all. The
  block is only a chosen unit (picker = Block), never a fallback —
  losing the line is fine, the fills still mark the text.
- **Independent of the fill toggles.** The line tracks its picked unit
  even when that unit's fill is hidden (hiding the sentence fill does
  not make a sentence-following line jump back to the block). The
  line's own Show/Hide switch still decides whether the line shows at all;
  the picker only decides how long it is.

## 7. Hide highlights while scrolling

The overlay follows the block with a 0.3 s poll. While the page
scrolls, the block moves every poll and the highlight chases it — that
reads as jerk. So the highlight hides while scrolling and comes back
when the text stops (phase 2 of the Step 2 trial plan, built now that
scrolling jerkiness is confirmed).

- **Toggle in the section** — "Hide highlights while scrolling", a
  native `Toggle` at the end of the "Highlight colors" section (after
  "Reset all to default"). Default **on** (main).
- **Info button ("i")** — a small native `info.circle` button next to
  the toggle (Manh 2026-11-27 16:39), same pattern as the layer rows.
  Its popover explains the toggle and adds a "How it works" section:
  default ON; while scrolling (block frame moves > 1pt) the fills,
  line and underline hide but the window keeps following; 2 still
  polls (~0.6s) bring the highlights back; no extra accessibility
  reads.
- **Stored as a boolean** in Defaults
  (`transpeek_highlightHideWhileScrolling`, default `true`).
- **How it works.** Each follow poll compares the block frame it just
  read with the previous poll's frame (no extra AX reads — it reuses
  the frame the poll already read). A move of more than one point on
  any edge means scrolling (Manh 2026-11-27 19:38 — 1pt, not 0.5pt: a
  real scroll moves the frame far more than 1pt per 0.3s poll, so
  hiding stays fast; AX jitter under 1pt is ignored, so the highlight
  comes back at the new position without lag): the fills, line and
  underline hide at once. The window keeps repositioning while hidden,
  so the highlight reappears in the right place. It takes **2 still
  polls (~0.6 s)** to show again, so a brief pause mid-scroll does not
  flash the highlight back.
- **Toggle off = the old follow-only behaviour.** The highlight stays
  visible while scrolling, and may jerk — the user's choice.
- **The window never stops following.** Hiding only skips drawing;
  the 0.3 s repositioning, the off-screen hide, and the word/sentence/
  cluster updates all keep running while hidden.

## 8. Why this design

- **Native picker + presets, not hex input.** The app's users are
  English learners and older readers — most do not know what a hex
  code is, and typing one wrong produces an ugly or unreadable colour
  with no easy way back. The native picker is the macOS standard
  (wheel, sliders, palettes, eyedropper), and one tap on a preset is
  the fastest path for most users. Hex stays visible for the few who
  want an exact colour, and the system panel already has a hex field
  in its RGB Sliders tab for them.
- **Fixed opacity.** The whole point of the highlight is marking text
  that stays readable. Letting the user pick an opaque fill would
  defeat it — so opacity is a code constant, not a setting.
- **Reset per layer + Reset all.** A wrong pick must be undoable in
  one tap, without forcing the user to remember the default hex. The
  per-layer Reset fixes one mistake; Reset all restores the whole
  tried palette.

## 9. Technical limitations

What the overlay can and cannot do is set by how it is built — a
floating `NSPanel` that draws `NSBezierPath` rectangles over the page.
These limits are inherent to that approach, not bugs.

- **Every highlight is a rectangle with a hard edge.** The overlay
  draws one filled rectangle per layer (block, paragraph, sentence,
  word) over the text — so each highlight has a straight, sharp
  border, and overlapping layers stack their edges. Pale colours
  (the Speechify hues in §3) make the edge fainter, but they cannot
  remove it.
- **The overlay cannot change the text colour.** Speechify highlights
  the text itself (CSS Highlight API), so it sets both the background
  and the text colour — a dark word background with light text. This
  overlay draws over the page and cannot recolour the text underneath,
  so it cannot use Speechify's opaque (1.0) fills: an opaque fill
  would hide the text. The fills stay translucent (0.30) so the dark
  text stays readable.
- **The overlay cannot follow the shape of the letters.** Speechify
  highlights each character exactly. This overlay only gets a
  rectangle per unit from the app's accessibility tree
  (`AXBoundsForRange`), so the highlight is always a rectangle — it
  never hugs the glyphs, and a multi-line unit is one tall box, not
  a shape that follows the lines.
- **A layer draws only when the app exposes its bounds.** The
  word/sentence/paragraph frames come from `AXBoundsForRange`. An app
  that does not support it for a unit gives no frame — that layer is
  simply not drawn (no fill, and the line falls back as in §6 or is
  not drawn at all).
- **The vertical line is a thin solid rectangle too.** It is the same
  drawing primitive as the fills, only 1.75 pt wide (halved from 3.5
  on 2026-11-27 — Manh found 3.5 too thick), so it reads as a line
  rather than a frame. The 8 pt strip it lives in is unchanged.
- **The underline avoids the rectangle entirely.** It is a thin solid
  bar (2.5 pt) under the word + sentence, not a box around them, so
  it has no border edge — that is why it reads better than the fills
  (Manh 2026-11-27 15:57), and why it is a proper layer with its own
  colour and Show/Hide switch, default on. It is still a rectangle in
  code (the same drawing primitive), only too thin to read as one.

## 10. Implementation (file map)

- `Sources/UI/ReadingIndicator/HighlightColors.swift` — the 6 default
  hexes, fixed opacities, the 6 presets, hex ↔ `NSColor`
  conversion (parse `#RRGGBB`, format, fallback to default).
- `Sources/Utilities/Constants.swift` — the 6 `Defaults.Keys` for
  colours (`transpeek_highlight*Hex`, `String`, default = the palette
  above), the 6 for visibility (`transpeek_highlight*Shown`,
  `Bool`; main defaults: word + underline `true`, the other four `false`),
  `transpeek_highlightLineFollows` (`String`,
  `"sentence"` / `"paragraph"` / `"block"`, main default
  `"sentence"`), and `transpeek_highlightHideWhileScrolling`
  (`Bool`, default `true`).
- `Sources/UI/ReadingIndicator/ReadingIndicatorOverlay.swift` — the 6
  layer colours are computed properties reading Defaults live (was 4
  hardcoded `NSColor` constants); `isShown(_:in:)` intersects the
  creation layers with the Show toggles, and every draw/update/layout
  check goes through it. The overlay is created with `.all`
  (`AppDelegate`), so the toggles are the deciding source. The
  vertical line is 1.75 pt wide (`lineWidth`, halved from 3.5 on
  2026-11-27) in the 8 pt left strip. The cluster frame is converted in `layoutHighlightRects` like the
  sentence/word frames; the line rect follows `LineFollows` (sentence
  / paragraph / block, falling back down the chain chosen unit →
  sentence → cluster, and drawing no line when none has a frame —
  the block is only a chosen unit, never a fallback). The underline
  rects are computed in `layoutHighlightRects` too
  (`underlineRect`, a 2.5 pt bar at the bottom of the word/sentence
  frames, from the ungated AX frames) and drawn in
  `ReadingIndicatorView.draw` with the underline's own solid colour,
  gated only on `isShown(.underline, in:)` — so the underline shows
  even when the word/sentence fills are off. The
  hide-during-scroll state (`previousBlockScreenFrame`,
  `stablePolls`, `hideForScroll`) lives here: the follow timer
  compares the frame it just read with the previous poll's, and
  `ReadingIndicatorView.draw` skips everything while scrolling.
- `Sources/Core/TextSelection/ContinuousSpeakController.swift` —
  `paragraphRanges(for:sentences:)` splits a block into paragraphs on
  blank lines (derived from the sentence ranges), `paragraph(containing:in:)`
  maps a word to its paragraph, and `handleWordRange` passes the
  cluster frame to `overlay.update` alongside the word/sentence
  frames (cached like the sentence frame — re-read only when the
  paragraph changes).
- `Sources/UI/Settings/TTSSettingsView.swift` — the "Highlight colors"
  section + `HighlightColorRow` (row + Show toggle + presets + Reset
  + the `Color`-to-hex binding), the Underline row first, then the
  Vertical line row, then Word, Sentence, Paragraph, Block (row order
  2026-11-27 15:57), the segmented "Line follows" picker in the
  Vertical line row, "Reset all to default" (restores all six colours,
  Show/Hide switches and the line's unit), and the "Hide highlights while
  scrolling" toggle at the end of the section.

## Links

- [Speech Player](../../FEATURES/SPEECH_PLAYER.md) — the speaker law
  (play/pause/resume, separate indicator) the overlay belongs to.
- [TTS word-sync highlight spec](../../FEATURES/TTS_WORD_SYNC_HIGHLIGHT.md)
  — the word/sentence highlight the colours mark.
- [Step 2 trial plan](../../RESEARCH/tts-speechify-naturalreader/step2-trial-plan.md)
  — the chaining + overlay trial (colours, layers, scroll behaviour).
- [Float Icon UX](FLOAT_ICON_UX_SPEC.md) — the icon whose Speak starts
  the session the indicator marks.
- [Alternative icon](FAST_READ_SELECT_ICON.md) — the in-Read icon whose
  Speak uses the same flow and indicator.
