# Highlight Colors — UX Spec

> Status: **settled design** (approved by Manh 2026-11-27, implemented on
> branch `feature/continuous-reading`) — the user can change the reading
> indicator's 4 layer colors in Settings. The branch draws all four
> layers; main draws only sentence + word (see the overlay's `Layers`).

## 1. Where it lives

Settings → **Audio** tab → section **"Highlight colors"**, after
"Voices (EN / VI)" and before "Test". It sits in the Audio tab because
the indicator belongs to the listen-on-page flow (click-to-listen /
chaining), not to the Read window's theme.

## 2. Layout — 4 rows + presets + Reset all

Each layer gets one block: a settings row, then a preset swatch row
underneath it.

```
Highlight colors
┌──────────────────────────────────────────────────────────────┐
│ Vertical line                    #8CBFFF  [swatch]  Reset   │
│ Solid bar at the block's left edge                           │
│ ( ) ( ) ( ) ( ) ( ) ( )   <- 6 pastel presets                │
│                                                              │
│ Block                          #BFF2B3  [swatch]  Reset   │
│ Highlight for the whole block being read                     │
│ ( ) ( ) ( ) ( ) ( ) ( )                                      │
│                                                              │
│ Sentence                       #FFF2A6  [swatch]  Reset   │
│ Highlight for the sentence being read                        │
│ ( ) ( ) ( ) ( ) ( ) ( )                                      │
│                                                              │
│ Word                           #D9BFFA  [swatch]  Reset   │
│ Highlight for the word being spoken                          │
│ ( ) ( ) ( ) ( ) ( ) ( )                                      │
│                                                              │
│ [Reset all to default]                                       │
│                                                              │
│ Colors for the reading indicator shown over the page while   │
│ listening. Changes apply at once — no restart needed.        │
│ Opacity is fixed so the text underneath stays readable.      │
└──────────────────────────────────────────────────────────────┘
```

Each row, left to right:

- **Name + subtitle** — the layer name ("Vertical line", "Block",
  "Sentence", "Word") and one line saying what it marks.
- **Hex** — the current color as `#RRGGBB` (monospaced, secondary
  colour). Display-only: it shows the exact value for users who want
  it, it is not an input field.
- **Colour well** — the native macOS colour picker (`ColorPicker`,
  `supportsOpacity: false`). Clicking it opens the system colour panel
  (colour wheel, sliders, palettes, eyedropper).
- **Reset** — restores that one layer to its default colour.

Under each row, **6 pastel preset swatches** (22 pt circles): tap one
to set that layer's colour at once. The current colour gets a strong
ring, so the user can see which preset (if any) is active.

At the end of the section, **"Reset all to default"** restores all four
layers at once.

## 3. The 4 layers + default colours

| Layer | What it marks | Default | Opacity |
|---|---|---|---|
| Vertical line | Solid bar at the block's left edge (in the 8 pt strip beside the text) | `#8CBFFF` (light blue) | 1.0 (solid) |
| Block | Fill for the whole block being read | `#BFF2B3` (light green) | 0.30 |
| Sentence | Fill for the sentence being read | `#FFF2A6` (light yellow) | 0.30 |
| Word | Fill for the word being spoken | `#D9BFFA` (light purple) | 0.30 |

The defaults are the pastel palette from the trial (Manh 2026-11-24
00:38), as `#RRGGBB` hex — the rounded equivalents of the RGB values
the overlay used before (word 0.85/0.75/0.98, sentence 1.0/0.95/0.65,
block 0.75/0.95/0.70, line 0.55/0.75/1.0), so the defaults look
identical to the old hardcoded colours. Draw order (bottom to top):
block, sentence, word, then the line — the fills are translucent, so
overlapping levels blend instead of hiding each other.

## 4. Behaviour

- **Change applies at once — no restart.** The overlay reads the
  colours from Defaults at draw time, and its follow timer redraws
  every 0.3 s while showing, so a colour picked in Settings shows on
  the next draw (immediately if the indicator is up, otherwise on the
  next listen).
- **Stored as hex strings** in Defaults (`transpeek_highlightLineHex`,
  `transpeek_highlightBlockHex`, `transpeek_highlightSentenceHex`,
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

## 6. Implementation (file map)

- `Sources/UI/ReadingIndicator/HighlightColors.swift` — the 4 default
  hexes, fixed opacities, the 6 pastel presets, hex ↔ `NSColor`
  conversion (parse `#RRGGBB`, format, fallback to default).
- `Sources/Utilities/Constants.swift` — the 4 `Defaults.Keys`
  (`transpeek_highlight*Hex`, `String`, default = the palette above).
- `Sources/UI/ReadingIndicator/ReadingIndicatorOverlay.swift` — the 4
  layer colours are computed properties reading Defaults live (was 4
  hardcoded `NSColor` constants); `draw` is unchanged.
- `Sources/UI/Settings/TTSSettingsView.swift` — the "Highlight colors"
  section + `HighlightColorRow` (row + presets + Reset + the
  `Color`-to-hex binding).

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
