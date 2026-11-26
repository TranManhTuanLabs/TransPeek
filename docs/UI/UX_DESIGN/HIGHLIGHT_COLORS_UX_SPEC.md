# Highlight Colors — UX Spec

> Status: **settled design** (approved by Manh 2026-11-27, implemented on
> `main`) — the user can change the reading indicator's 5 layer colors
> in Settings, and show/hide each layer with its own switch. The overlay
> is created with all five layers; which ones actually show is the
> user's per-layer Show toggle (main defaults: sentence + word +
> paragraph on, line + block off). The vertical line can follow the
> sentence, the paragraph (cluster) or the whole block (main default:
> sentence).

## 1. Where it lives

Settings → **Audio** tab → section **"Highlight colors"**, after
"Voices (EN / VI)" and before "Test". It sits in the Audio tab because
the indicator belongs to the listen-on-page flow (click-to-listen /
chaining), not to the Read window's theme.

## 2. Layout — 5 rows + presets + Reset all

Each layer gets one block: a settings row, then a preset swatch row
underneath it. The Vertical line row also carries the "Line follows"
picker (see §6).

```
Highlight colors
┌──────────────────────────────────────────────────────────────────┐
│ Vertical line              #8CBFFF  Show [ ]  [swatch]  Reset   │
│ Solid bar at the block's left edge                               │
│ ( ) ( ) ( ) ( ) ( ) ( )   <- 6 pastel presets                    │
│ Line follows: [ Sentence | Paragraph | Block ]                   │
│                                                                  │
│ Block                        #BFF2B3  Show [ ]  [swatch]  Reset │
│ Highlight for the whole block being read                         │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Paragraph                    #FFC2D1  Show [x]  [swatch]  Reset │
│ Highlight for the paragraph (cluster) being read                 │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Sentence                     #FFF2A6  Show [x]  [swatch]  Reset │
│ Highlight for the sentence being read                            │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ Word                         #D9BFFA  Show [x]  [swatch]  Reset │
│ Highlight for the word being spoken                              │
│ ( ) ( ) ( ) ( ) ( ) ( )                                          │
│                                                                  │
│ [Reset all to default]                                           │
│                                                                  │
│ Colors for the reading indicator shown over the page while       │
│ listening. Changes apply at once — no restart needed.            │
│ Opacity is fixed so the text underneath stays readable.          │
│ Use the Show switch on each row to hide a layer you don't want.  │
│ The vertical line can follow the sentence, the paragraph, or     │
│ the whole block — pick it in the line's row.                     │
└──────────────────────────────────────────────────────────────────┘
```

Each row, left to right:

- **Name + subtitle** — the layer name ("Vertical line", "Block",
  "Paragraph", "Sentence", "Word") and one line saying what it marks.
- **Hex** — the current color as `#RRGGBB` (monospaced, secondary
  colour). Display-only: it shows the exact value for users who want
  it, it is not an input field.
- **Show switch** — a native `Toggle` labelled "Show", next to the
  colour well. It hides/shows this layer (see §5). The colour stays
  editable while the layer is hidden, so the user can set it first
  and show it after.
- **Colour well** — the native macOS colour picker (`ColorPicker`,
  `supportsOpacity: false`). Clicking it opens the system colour panel
  (colour wheel, sliders, palettes, eyedropper).
- **Reset** — restores that one layer to its default colour.

Under each row, **6 pastel preset swatches** (22 pt circles): tap one
to set that layer's colour at once. The current colour gets a strong
ring, so the user can see which preset (if any) is active.

Under the Vertical line row only, a **segmented "Line follows"
picker** (see §6): Sentence / Paragraph / Block.

At the end of the section, **"Reset all to default"** restores all five
layers' colours at once (it does not touch the Show switches or the
"Line follows" picker).

## 3. The 5 layers + default colours

| Layer | What it marks | Default | Opacity | Shown by default (main) |
|---|---|---|---|---|
| Vertical line | Solid bar at the block's left edge (in the 8 pt strip beside the text); its length follows the unit picked in §6 | `#8CBFFF` (light blue) | 1.0 (solid) | No |
| Block | Fill for the whole block being read | `#BFF2B3` (light green) | 0.30 | No |
| Paragraph (cluster) | Fill for the paragraph around the sentence being read — the group of sentences with no blank line between them | `#FFC2D1` (light pink) | 0.30 | Yes |
| Sentence | Fill for the sentence being read | `#FFF2A6` (light yellow) | 0.30 | Yes |
| Word | Fill for the word being spoken | `#D9BFFA` (light purple) | 0.30 | Yes |

The defaults are the pastel palette from the trial (Manh 2026-11-24
00:38), as `#RRGGBB` hex — the rounded equivalents of the RGB values
the overlay used before (word 0.85/0.75/0.98, sentence 1.0/0.95/0.65,
block 0.75/0.95/0.70, line 0.55/0.75/1.0), so the defaults look
identical to the old hardcoded colours. The paragraph default is light
pink — a preset already in the palette, distinct from the other four
fills; Manh did not pick a colour for it (parent agent's choice,
2026-11-27), change it in Settings if another pink reads better. Draw
order (bottom to top): block, paragraph, sentence, word, then the
line — the fills are translucent, so overlapping levels blend instead
of hiding each other.

## 4. Behaviour

- **Change applies at once — no restart.** The overlay reads the
  colours from Defaults at draw time, and its follow timer redraws
  every 0.3 s while showing, so a colour picked in Settings shows on
  the next draw (immediately if the indicator is up, otherwise on the
  next listen).
- **Stored as hex strings** in Defaults (`transpeek_highlightLineHex`,
  `transpeek_highlightBlockHex`, `transpeek_highlightClusterHex`,
  `transpeek_highlightSentenceHex`, `transpeek_highlightWordHex`),
  one key per layer. A malformed stored value (only possible by
  hand-editing UserDefaults) falls back to that layer's default colour.
- **Opacity is fixed and never editable.** Fills are always 0.30, the
  line is always solid (1.0) — the picker has no opacity control, and
  no opacity is stored. A fully opaque fill would hide the text, and
  the line must read as a marker, not a tint.
- **Hex is display-only.** The hex text next to each well shows the
  current value; the colour is changed with the well (system panel) or
  a preset swatch, never by typing hex.
- **The paragraph (cluster) is the group of sentences around the
  sentence being read, split on blank lines.** The controller splits
  the block's text into paragraphs at blank lines (2+ line breaks
  between sentences); the cluster fill covers the paragraph holding
  the current sentence and moves with the voice. A block with no
  blank line is a single paragraph, so the cluster then covers the
  whole block. When the app does not expose the paragraph's bounds
  (`AXBoundsForRange` unsupported), the cluster fill is simply not
  drawn — the other layers keep showing. The cluster fill is read
  live from Defaults like the other fills (colour + Show toggle).
- **The line follows its picked unit (§6).** Its length is the picked
  unit's vertical span in the 8 pt strip; it moves with the voice
  when the unit is the sentence or the paragraph. When the picked
  unit has no frame (bounds unsupported) the line falls back to the
  whole block, so it never disappears for a missing frame. The line
  still tracks its unit when that unit's fill is hidden — hiding the
  sentence fill does not make a sentence-following line jump back to
  the block.

## 5. Show/hide per layer

Each layer has its own **Show switch** in its colour row (a native
`Toggle` labelled "Show", next to the colour well). Flipping it
hides/shows that layer at once — no restart.

- **Stored as booleans** in Defaults (`transpeek_highlightLineShown`,
  `transpeek_highlightBlockShown`, `transpeek_highlightClusterShown`,
  `transpeek_highlightSentenceShown`, `transpeek_highlightWordShown`),
  one key per layer.
- **Main defaults: sentence + word + paragraph on, line + block off.**
  That keeps main's previous behaviour (only sentence + word showed)
  plus the new paragraph fill, until the user turns a layer on —
  porting the colours does not change what the user sees on first
  launch, except for the paragraph fill Manh asked to be on by
  default.
- **The toggles decide what shows.** The overlay is created with all
  five layers (`.all`); a layer draws only when it is in the creation
  set AND its toggle is on (`ReadingIndicatorOverlay.isShown`). The
  overlay reads the toggles live at draw/update time (the follow timer
  redraws every 0.3 s while showing, and `update` re-lays out on the
  next word), so a flip applies immediately — including mid-speech.
  Turning the line off also drops the 8 pt left strip, so the window
  shrinks to exactly the block frame.
- **Colour stays editable while hidden.** Hiding a layer does not
  disable its row: the user can pick the colour first and show the
  layer after, without losing the pick. "Reset all to default" resets
  colours only — it does not touch the Show switches or the "Line
  follows" picker.
- **All five off is allowed.** The overlay window simply draws
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
- **Fallback to the block.** When the picked unit has no frame (the
  app did not expose its bounds), the line spans the whole block —
  it never disappears for a missing frame.
- **Independent of the fill toggles.** The line tracks its picked unit
  even when that unit's fill is hidden (hiding the sentence fill does
  not make a sentence-following line jump back to the block). The
  line's own Show switch still decides whether the line shows at all;
  the picker only decides how long it is.

## 7. Why this design

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

## 8. Implementation (file map)

- `Sources/UI/ReadingIndicator/HighlightColors.swift` — the 5 default
  hexes, fixed opacities, the 6 pastel presets, hex ↔ `NSColor`
  conversion (parse `#RRGGBB`, format, fallback to default).
- `Sources/Utilities/Constants.swift` — the 5 `Defaults.Keys` for
  colours (`transpeek_highlight*Hex`, `String`, default = the palette
  above), the 5 for visibility (`transpeek_highlight*Shown`,
  `Bool`; main defaults: sentence + word + cluster `true`, line +
  block `false`), and `transpeek_highlightLineFollows` (`String`,
  `"sentence"` / `"paragraph"` / `"block"`, main default
  `"sentence"`).
- `Sources/UI/ReadingIndicator/ReadingIndicatorOverlay.swift` — the 5
  layer colours are computed properties reading Defaults live (was 4
  hardcoded `NSColor` constants); `isShown(_:in:)` intersects the
  creation layers with the Show toggles, and every draw/update/layout
  check goes through it. The overlay is created with `.all`
  (`AppDelegate`), so the toggles are the deciding source. The
  cluster frame is converted in `layoutHighlightRects` like the
  sentence/word frames; the line rect follows `LineFollows` (sentence
  / paragraph / block, falling back to the block when the unit has no
  frame).
- `Sources/Core/TextSelection/ContinuousSpeakController.swift` —
  `paragraphRanges(for:sentences:)` splits a block into paragraphs on
  blank lines (derived from the sentence ranges), `paragraph(containing:in:)`
  maps a word to its paragraph, and `handleWordRange` passes the
  cluster frame to `overlay.update` alongside the word/sentence
  frames (cached like the sentence frame — re-read only when the
  paragraph changes).
- `Sources/UI/Settings/TTSSettingsView.swift` — the "Highlight colors"
  section + `HighlightColorRow` (row + Show toggle + presets + Reset
  + the `Color`-to-hex binding), the Paragraph row, and the segmented
  "Line follows" picker in the Vertical line row.

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
