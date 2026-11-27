# Highlight Colors — UX Spec

> Status: **settled design** (approved by Manh 2026-11-27, implemented on
> branch `feature/continuous-reading`) — the user can change the reading
> indicator's 5 layer colors in Settings, and pick what the vertical
> line follows (sentence / paragraph / block). The branch draws all
> five layers; main draws only sentence + word (see the overlay's
> `Layers`).

## 1. Where it lives

Settings → **Audio** tab → section **"Highlight colors"**, after
"Voices (EN / VI)" and before "Test". It sits in the Audio tab because
the indicator belongs to the listen-on-page flow (click-to-listen /
chaining), not to the Read window's theme.

## 2. Layout — 5 rows + presets + toggles + Reset all

Each layer gets one block: a settings row, then a preset swatch row
underneath it. The Vertical line row has one extra control under its
presets: the "Line follows" picker (§4).

```
Highlight colors
┌──────────────────────────────────────────────────────────────────┐
│ Vertical line                    #8CBFFF  Show [on] [swatch] Reset│
│ Solid bar beside the text — its height follows the unit below    │
│ ( ) ( ) ( ) ( ) ( ) ( )   <- 6 preset swatches                     │
│ Line follows: [Sentence | Paragraph | Block]  <- segmented       │
│                                                                  │
│ Block                          #BFF2B3  Show [off] [swatch] Reset│
│ Highlight for the whole block being read                         │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Cluster                        #FFC2D1  Show [on] [swatch] Reset│
│ Highlight for the paragraph (group of sentences) being read      │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Sentence                       #ABB3FE  Show [on] [swatch] Reset│
│ Highlight for the sentence being read                            │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Word                           #5666F0  Show [on] [swatch] Reset│
│ Highlight for the word being spoken                              │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Hide highlights while scrolling                        [on]      │
│ Show underline                                         [off]     │
│                                                                  │
│ [Reset all to default]                                           │
│                                                                  │
│ Colors for the reading indicator shown over the page while       │
│ listening. Changes apply at once — no restart needed.            │
│ Opacity is fixed so the text underneath stays readable.          │
│ Turn a layer off with its Show switch to hide it. The vertical   │
│ line's height follows the unit picked in its row (sentence,      │
│ paragraph, or block).                                            │
└──────────────────────────────────────────────────────────────────┘
```

Each row, left to right:

- **Name + subtitle** — the layer name ("Vertical line", "Block",
  "Cluster", "Sentence", "Word") and one line saying what it marks.
- **Hex** — the current color as `#RRGGBB` (monospaced, secondary
  colour). Display-only: it shows the exact value for users who want
  it, it is not an input field.
- **Show toggle** — a native `Toggle` labelled "Show" for that one
  layer (see §4). Off hides the layer from the overlay; the layer's
  colour is kept, so turning it back on restores the same colour.
- **Colour well** — the native macOS colour picker (`ColorPicker`,
  `supportsOpacity: false`). Clicking it opens the system colour panel
  (colour wheel, sliders, palettes, eyedropper).
- **Reset** — restores that one layer to its default colour (the Show
  toggle is untouched — hiding a layer is a separate choice from its
  colour).

Under each row, **6 preset swatches** (22 pt circles): tap one
to set that layer's colour at once. The current colour gets a strong
ring, so the user can see which preset (if any) is active.

Under the Vertical line row's presets, the **"Line follows" picker**
(a native segmented control): Sentence / Paragraph / Block. It picks
which unit the line's height follows (§4) — the Show toggle still
decides whether the line shows at all.

After the five layer rows, the **"Hide highlights while scrolling"
toggle** (a native `Toggle`, default ON — see §4). It is not a layer:
it decides whether the highlight content hides while the page scrolls.

After it, the **"Show underline" toggle** (a native `Toggle`,
default OFF — branch-only trial, see §4). It is not a layer either:
it draws a thin solid underline under the word + sentence being
read, in each layer's colour — a try-out alternative to the
rectangle fills. Like the scroll toggle it is a behaviour
preference, so "Reset all to default" does not touch it.

At the end of the section, **"Reset all to default"** restores all
five layers' colours at once — and restores the branch defaults for
the Show toggles (line, cluster, sentence, word on; block off) and
for "Line follows" (Paragraph). It does not touch the two behaviour
toggles ("Hide highlights while scrolling", "Show underline").

## 3. The 5 layers + default colours

| Layer | What it marks | Default | Opacity | Shown by default (branch) |
|---|---|---|---|---|
| Vertical line | Solid bar beside the text, in the 8 pt strip at the block's left edge — its height follows the unit picked in "Line follows" | `#8CBFFF` (light blue) | 1.0 (solid) | Yes |
| Block | Fill for the whole block being read | `#BFF2B3` (light green) | 0.30 | **No** (hidden by default since 2026-11-27 — the cluster is the broad fill now; still available to turn back on) |
| Cluster | Fill for the paragraph (group of sentences) being read | `#FFC2D1` (light pink) | 0.30 | Yes |
| Sentence | Fill for the sentence being read | `#ABB3FE` (light periwinkle — Speechify `highlight30`) | 0.30 | Yes |
| Word | Fill for the word being spoken | `#5666F0` (indigo — Speechify `highlight50`) | 0.30 | Yes |

The word + sentence defaults follow **Speechify** (Manh 2026-11-27),
traced from its real extension source (`highlight50` `#5666F0` for
the word, `highlight30` `#ABB3FE` for the sentence). Speechify itself
paints the word solid indigo with white text and the sentence solid
pale lavender `#E0E3FF` (`highlight20`) at opacity 1.0 — but it
highlights the text itself (CSS Highlight API) and recolors the text,
so its fills can be opaque. The overlay draws *over* the page and
cannot recolor the text, and an opaque fill would hide the dark text
underneath — so the Speechify hues are used as translucent fills at
the fixed 0.30 opacity instead. `#E0E3FF` was not used for the
sentence because at 0.30 it is nearly invisible on a white page;
`#ABB3FE` is the next step in Speechify's own palette. Block + line
keep the pastel palette from the trial (Manh 2026-11-24 00:38). The
cluster default (light pink `#FFC2D1`, from the preset palette) was
chosen by the parent — Manh did not name a colour for it; it is
changeable in Settings like the rest. Draw order (bottom to top):
block, cluster, sentence, word, then the line — the fills are
translucent, so overlapping levels blend instead of hiding each
other.

**What a "cluster" is.** A cluster is one paragraph inside the block:
a run of sentences separated from the next group by a blank line
(Enter / an empty line). A block with no blank line is a single
cluster (the whole block) — the common case for short paragraphs. A
long block (several paragraphs) has one cluster per paragraph, and
the highlight follows the cluster around the sentence being read.

## 4. Behaviour

- **Change applies at once — no restart.** The overlay reads the
  colours from Defaults at draw time, and its follow timer redraws
  every 0.3 s while showing, so a colour picked in Settings shows on
  the next draw (immediately if the indicator is up, otherwise on the
  next listen).
- **Stored as hex strings** in Defaults (`transpeek_highlightLineHex`,
  `transpeek_highlightBlockHex`, `transpeek_highlightClusterHex`,
  `transpeek_highlightSentenceHex`,
  `transpeek_highlightWordHex`), one key per layer. A malformed stored
  value (only possible by hand-editing UserDefaults) falls back to
  that layer's default colour.
- **Opacity is fixed and never editable.** Fills are always 0.30, the
  line is always solid (1.0) — the picker has no opacity control, and
  no opacity is stored. A fully opaque fill would hide the text, and
  the line must read as a marker, not a tint.
- **Hex is display-only.** The hex text next to each well shows the
  current value; the colour is changed with the well (system panel) or
  a preset swatch, never by typing hex.
- **Show / hide per layer — applies at once.** Each layer has its own
  Show toggle, stored as a `Bool` in Defaults
  (`transpeek_highlightLineShown`, `transpeek_highlightBlockShown`,
  `transpeek_highlightClusterShown`,
  `transpeek_highlightSentenceShown`, `transpeek_highlightWordShown`),
  with the branch defaults in the table above (block off, the other
  four on). The overlay reads them at draw time (and its follow timer
  redraws every 0.3 s while showing), so flipping a toggle hides or
  shows that layer immediately — no restart, and it works while the
  indicator is already up. A hidden layer is never drawn, even when
  its frame arrives; hiding the line also removes the 8 pt strip the
  window extends left of the block (the window becomes exactly the
  block frame again). Hiding keeps the layer's colour — turning it
  back on restores the same colour. "Reset all to default" restores
  the branch defaults for all five toggles; a per-layer Reset only
  restores that layer's colour.
- **Cluster highlight — how the paragraph is found.** The controller
  splits the block's text into paragraphs by blank lines at block
  start (same precompute step as the sentences) and maps each spoken
  word to the paragraph around its sentence. The cluster frame is
  cached and only re-read from AX when the cluster actually changes
  (like the sentence frame); the word frame is still read on every
  word. If the app does not expose range bounds, the cluster fill is
  simply not drawn (the other levels still show) — never a crash,
  never a wrong rectangle. A block with no blank line is one cluster,
  so the cluster fill then covers the whole block (same area the
  block fill would cover, in pink instead of green).
- **Line follows — what the vertical line marks.** The "Line follows"
  picker in the Vertical line row stores one string in Defaults
  (`transpeek_highlightLineFollows`: `"sentence"`, `"paragraph"`, or
  `"block"`; branch default `"paragraph"`). The line is drawn in the
  same 8 pt strip, but its height is the chosen unit's height:
  Sentence = the sentence being read (the line moves with the voice);
  Paragraph = the cluster around it (the branch default — the line
  marks the paragraph being read); Block = the whole block (the
  original behaviour). The overlay window stays the block frame
  (the fills still need it) — only the line's height changes. The
  picker is read live (the follow timer re-lays out every 0.3 s),
  so a tap applies at once. Fallback chain (Manh 2026-11-27, revised
  03:07): chosen unit → sentence → cluster. The block is NOT a
  fallback — it is only the unit when the picker is Block. If none of
  the three has a frame yet (no word spoken yet, or the app hides
  range bounds), the line is not drawn at all — losing the line is
  fine, the other highlights still show. The Show toggle still
  decides whether the line shows at all; the picker only decides how
  tall it is. An unknown stored value falls back to Paragraph.
- **Hide highlights while scrolling — the phase 2 fallback.** The
  follow timer (0.3 s) compares each poll's block frame with the
  previous one. A frame that moved (more than 1 pt, so AX jitter does
  not count as scrolling) means the page is scrolling: the overlay
  draws nothing — no fills, no line — while the window still follows
  (reposition runs every poll), so the highlight comes back in the
  right place. Two stable polls in a row (~0.6 s) mean the scroll
  stopped: the highlight shows again. No extra AX reads — the frame
  is the one the poll already read for repositioning. The toggle
  (`transpeek_highlightHideWhileScrolling`, `Bool`, default `true` on
  the branch) is read live, so flipping it applies at once (the next
  poll re-evaluates). Off keeps the old follow-only behaviour: the
  highlight stays up while scrolling, which can read as jerkiness
  because the 0.3 s poll lags behind the text. "Reset all to default"
  does not touch this toggle — it is a behaviour preference, not a
  colour or a layer default.
- **Show underline — branch-only trial (Manh 2026-11-27).** A
  "Show underline" toggle (`transpeek_highlightUnderlineShown`,
  `Bool`, default `false` on the branch — not on main) draws a thin
  solid bar (2.5 pt, opacity 1.0) at the bottom edge of the word
  frame and of the sentence frame, each in its layer's colour
  (word colour under the word, sentence colour under the sentence).
  Only the word + sentence are underlined — not the block, cluster,
  or line — so the page never shows several parallel lines. The
  underline is **independent of the layers' Show toggles**: turning
  all fills off while the underline is on still shows the two
  underlines, so the underline-only style can be compared with the
  fill style. It is read live (the next draw applies it), and it
  hides while scrolling together with the fills + line (the same
  scroll guard — see §7 for why the fills have hard edges and the
  underline does not). "Reset all to default" does not touch this
  toggle — it is a behaviour preference, not a colour or a layer
  default. If the trial is rejected, the toggle + the drawing code
  go away; if it is kept, it may replace the fills or extend to
  more layers.

## 5. Why this design

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
- **Cluster as its own level.** A block can hold several paragraphs,
  and the sentence alone is a thin mark — the paragraph is the
  natural middle unit: big enough to see at a glance, small enough
  to follow the voice. It replaces the block as the broad fill by
  default (the block fill stays one toggle away), so a long block no
  longer paints the whole thing pink-green while only one paragraph
  is being read.
- **Line follows, not a fixed height.** The line used to span the
  whole block — too broad once the voice moves sentence by sentence.
  Letting it follow the sentence, the paragraph, or the block covers
  the three ways a reader tracks the voice (word-by-word is already
  the word fill), and the paragraph default matches the cluster
  highlight, so the line and the fill mark the same unit.
- **Hide while scrolling, instead of polling faster.** The 0.3 s poll
  cannot keep up with a fast scroll — the highlight would lag behind
  the text however fast the poll runs, and a faster poll just burns
  more AX reads. Hiding while the frame moves removes the jerkiness
  entirely, and the highlight comes back by itself once the text
  stops. It is a toggle, not a fixed behaviour, because some readers
  would rather see the highlight track (roughly) than vanish.

## 6. Implementation (file map)

- `Sources/UI/ReadingIndicator/HighlightColors.swift` — the 5 default
  hexes, fixed opacities, the 6 preset swatches, hex ↔ `NSColor`
  conversion (parse `#RRGGBB`, format, fallback to default), plus the
  `LineFollows` enum (sentence / paragraph / block, raw strings for
  Defaults) for the line-height picker.
- `Sources/Utilities/Constants.swift` — the 5 `Defaults.Keys`
  (`transpeek_highlight*Hex`, `String`, default = the palette above)
  plus the 5 visibility keys (`transpeek_highlight*Shown`, `Bool`,
  block default `false` on the branch, the rest `true`) plus
  `transpeek_highlightLineFollows` (`String`, default `"paragraph"`
  on the branch) plus `transpeek_highlightHideWhileScrolling`
  (`Bool`, default `true` on the branch) plus
  `transpeek_highlightUnderlineShown` (`Bool`, default `false` on
  the branch — the underline trial, not on main).
- `Sources/Core/TextSelection/ContinuousSpeakController.swift` —
  precomputes the block's paragraph (cluster) ranges at block start
  (same step as the sentence ranges), maps each spoken word to the
  cluster around its sentence, and passes the cluster frame to the
  overlay in `update` (cached, re-read only when the cluster
  changes, like the sentence frame).
- `Sources/UI/ReadingIndicator/ReadingIndicatorOverlay.swift` — the 5
  layer colours are computed properties reading Defaults live (was 4
  hardcoded `NSColor` constants); the 5 visibility flags are computed
  properties the same way, and every place that gates on `layers`
  (`leftPad`, `update`, `layoutHighlightRects`, `draw`) also requires
  the layer to be shown. `Layers` gains `.cluster`; `draw` order is
  block, cluster, sentence, word, then the line. The line's rect is
  laid out in `layoutHighlightRects` from the chosen unit's frame
  (sentence / cluster / block, with the fallback chain chosen unit →
  sentence → cluster; no frame for any of the three means no line). Hide-during-scroll: `reposition`
  compares each poll's block frame with the previous one (1 pt
  tolerance) and sets the view's `isScrollingHidden` flag; `draw`
  paints nothing while the flag is set, and two stable polls clear it.
  The underline trial: `update` also stores the word/sentence frames
  without the Show gate, `layoutHighlightRects` reduces each to a
  2.5 pt bar at its bottom edge, and `draw` paints those bars solid
  (opacity 1.0, each layer's colour) when the underline toggle is on
  — gated only on the toggle, never on the fill toggles. The vertical
  line is 1.75 pt wide (halved from 3.5 on 2026-11-27 — it read as
  too thick); the 8 pt strip it sits in is unchanged.
- `Sources/UI/Settings/TTSSettingsView.swift` — the "Highlight colors"
  section + `HighlightColorRow` (row + presets + Reset + the
  `Color`-to-hex binding), now with a Show `Toggle` per row, a
  "Cluster" row, a segmented "Line follows" picker in the Vertical
  line row, a "Hide highlights while scrolling" toggle after the rows,
  a "Show underline" toggle after that (branch trial, default off),
  and "Reset all to default" restoring the branch defaults
  (5 colours, 5 toggles with block off, line follows Paragraph —
  the two behaviour toggles are preferences and are not reset).

## 7. Technical limitations

What the overlay can and cannot do is set by how it is built — an
`NSPanel` that draws rectangles over another app's window. These
limits are not bugs to fix later; they are the reason the design
above looks the way it does.

- **Every highlight is a rectangle with hard edges.** The overlay
  draws `NSBezierPath(rect:).fill()` over the page — a solid
  rectangle whose edge is a sharp colour step against the page
  behind it. That edge is the nature of the drawing, not a bug:
  with several translucent fills stacked (block + cluster +
  sentence + word) the edges read as nested borders, which is what
  Manh saw on the branch build (2026-11-27). Paler colours make
  the step smaller (which is why the word/sentence defaults follow
  Speechify's pale palette), but they cannot remove it — only not
  drawing a rectangle can. The underline trial (§4) is exactly
  that: a thin solid bar under the text has no broad rectangle, so
  it has no border to see.
- **The overlay cannot recolor the page's text.** Speechify
  highlights the text itself (CSS Highlight API) and sets both the
  background and the text colour — its word is solid indigo with
  white text. The overlay draws *over* the page and never touches
  the page's text, so it cannot turn the text white. That is why
  Speechify's opacity (1.0, solid) cannot be copied: an opaque
  fill would hide the dark text underneath it. The fills stay
  translucent (0.30) so the text stays readable, and the solid
  elements (vertical line, underline) are thin bars, not fills —
  a solid bar beside or under the text never covers it.
- **The overlay cannot follow the shape of the letters.** Speechify
  paints exactly the glyphs (its highlight hugs each character).
  The overlay only gets rectangles from Accessibility
  (`AXBoundsForRange`): one box per word, sentence, or paragraph.
  So a highlight is always the box around the text, never the text
  shape itself — it includes the gaps between words and the space
  above/below the letters, and it can never be rounded to the
  letters. Rounded corners on the box would soften the corners
  only; the straight edges would stay.
- **A layer only draws when the app exposes its frame.** The
  word/sentence/cluster frames come from `AXBoundsForRange` on the
  host app. An app that does not expose range bounds gives no
  frame, and that level is simply not drawn — no fill, no
  underline, no line for it; the other levels still show. This is
  by app, not by setting: the same build can show word + sentence
  in Preview and only the block in another app.
- **The line and the underline are rectangles too — thin ones.**
  The vertical line (1.75 pt wide, in the 8 pt strip) and the
  underline (2.5 pt tall, under the word/sentence) are the same
  `NSBezierPath(rect:).fill()` as the fills, only narrow and solid
  (opacity 1.0). A thin solid bar reads as a line, not a box, which
  is why neither of them has the border problem the fills do.

## Links

- [Speech Player](../../FEATURES/SPEECH_PLAYER.md) — the speaker law
  (play/pause/resume, separate indicator) the overlay belongs to.
- [TTS word-sync highlight spec](../../FEATURES/TTS_WORD_SYNC_HIGHLIGHT.md)
  — the word/sentence highlight the colours mark (on `main`; not yet
  on this branch).
- [Step 2 trial plan](../../RESEARCH/tts-speechify-naturalreader/step2-trial-plan.md)
  — the chaining + overlay trial (colours, layers, scroll behaviour).
- [Float Icon UX](FLOAT_ICON_UX_SPEC.md) — the icon whose Speak starts
  the session the indicator marks.
- [Alternative icon](FAST_READ_SELECT_ICON.md) — the in-Read icon whose
  Speak uses the same flow and indicator.
