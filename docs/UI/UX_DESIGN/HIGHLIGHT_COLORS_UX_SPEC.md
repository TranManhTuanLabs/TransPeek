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

## 2. Layout — 5 rows + presets + Reset all

Each layer gets one block: a settings row, then a preset swatch row
underneath it. The Vertical line row has one extra control under its
presets: the "Line follows" picker (§4).

```
Highlight colors
┌──────────────────────────────────────────────────────────────────┐
│ Vertical line                    #8CBFFF  Show [on] [swatch] Reset│
│ Solid bar beside the text — its height follows the unit below    │
│ ( ) ( ) ( ) ( ) ( ) ( )   <- 6 pastel presets                    │
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
│ Sentence                       #FFF2A6  Show [on] [swatch] Reset│
│ Highlight for the sentence being read                            │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Word                           #D9BFFA  Show [on] [swatch] Reset│
│ Highlight for the word being spoken                              │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
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

Under each row, **6 pastel preset swatches** (22 pt circles): tap one
to set that layer's colour at once. The current colour gets a strong
ring, so the user can see which preset (if any) is active.

Under the Vertical line row's presets, the **"Line follows" picker**
(a native segmented control): Sentence / Paragraph / Block. It picks
which unit the line's height follows (§4) — the Show toggle still
decides whether the line shows at all.

At the end of the section, **"Reset all to default"** restores all
five layers' colours at once — and restores the branch defaults for
the Show toggles (line, cluster, sentence, word on; block off) and
for "Line follows" (Paragraph).

## 3. The 5 layers + default colours

| Layer | What it marks | Default | Opacity | Shown by default (branch) |
|---|---|---|---|---|
| Vertical line | Solid bar beside the text, in the 8 pt strip at the block's left edge — its height follows the unit picked in "Line follows" | `#8CBFFF` (light blue) | 1.0 (solid) | Yes |
| Block | Fill for the whole block being read | `#BFF2B3` (light green) | 0.30 | **No** (hidden by default since 2026-11-27 — the cluster is the broad fill now; still available to turn back on) |
| Cluster | Fill for the paragraph (group of sentences) being read | `#FFC2D1` (light pink) | 0.30 | Yes |
| Sentence | Fill for the sentence being read | `#FFF2A6` (light yellow) | 0.30 | Yes |
| Word | Fill for the word being spoken | `#D9BFFA` (light purple) | 0.30 | Yes |

The defaults are the pastel palette from the trial (Manh 2026-11-24
00:38), as `#RRGGBB` hex — the rounded equivalents of the RGB values
the overlay used before (word 0.85/0.75/0.98, sentence 1.0/0.95/0.65,
block 0.75/0.95/0.70, line 0.55/0.75/1.0), so the defaults look
identical to the old hardcoded colours. The cluster default (light
pink `#FFC2D1`, from the preset palette) was chosen by the parent —
Manh did not name a colour for it; it is changeable in Settings like
the rest. Draw order (bottom to top): block, cluster, sentence, word,
then the line — the fills are translucent, so overlapping levels blend
instead of hiding each other.

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
  so a tap applies at once. If the chosen unit has no frame yet (no
  word spoken yet, or the app hides range bounds), the line falls
  back to the full block height — the line is never lost. The Show
  toggle still decides whether the line shows at all; the picker
  only decides how tall it is. An unknown stored value falls back
  to Paragraph.

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

## 6. Implementation (file map)

- `Sources/UI/ReadingIndicator/HighlightColors.swift` — the 5 default
  hexes, fixed opacities, the 6 pastel presets, hex ↔ `NSColor`
  conversion (parse `#RRGGBB`, format, fallback to default), plus the
  `LineFollows` enum (sentence / paragraph / block, raw strings for
  Defaults) for the line-height picker.
- `Sources/Utilities/Constants.swift` — the 5 `Defaults.Keys`
  (`transpeek_highlight*Hex`, `String`, default = the palette above)
  plus the 5 visibility keys (`transpeek_highlight*Shown`, `Bool`,
  block default `false` on the branch, the rest `true`) plus
  `transpeek_highlightLineFollows` (`String`, default `"paragraph"`
  on the branch).
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
  (sentence / cluster / block, falling back to the full block height
  when the unit has no frame).
- `Sources/UI/Settings/TTSSettingsView.swift` — the "Highlight colors"
  section + `HighlightColorRow` (row + presets + Reset + the
  `Color`-to-hex binding), now with a Show `Toggle` per row, a
  "Cluster" row, a segmented "Line follows" picker in the Vertical
  line row, and "Reset all to default" restoring the branch defaults
  (5 colours, 5 toggles with block off, line follows Paragraph).

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
