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
- **Read-only, with a speaker button for read-along (§10).** Listening
  is also the icon's click action, but the speaker here reads the text
  aloud in sync with the focus. It copies SwiftRead's UX.
- Window: `NSWindow`, title "Fast Read - RSVP", min **880×550**, default
  ~70% of screen width × ~55% of screen height, frame autosaved
  (`TransPeekRSVPWindow`) so macOS remembers size/position. Maximize =
  zoom (not fullscreen).

## 2. Layout — Style 1 (locked in, Manh 2026-11-18)

Top to bottom:

- **Top bar** (compact: padding top 8, bottom 6; label-to-picker spacing 1):
  - **Left:** Speed picker, **Focus size** picker, **Context size** picker,
    Words-at-once picker (each a label above a menu Picker). "Text size"
    was renamed "Focus size" (Manh 2026-11-18, round 7) to distinguish it
    from the new Context size picker, which sits right next to it.
  - **Center:** "Rapid Serial Visual Presentation" — **truly centered** on
    the window via an overlay (it used to sit between two Spacers, so the
    wide left cluster pushed it right of center).
  - **Right:** Settings gear (Color Scheme + context display + Reset to
    default) and "?" (hotkeys popover).
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
  centered row; the context words above/below are the **"Context size"
  percent of the focus size** (default **40%** — Manh 2026-11-18, round 7;
  was a fixed half) and scale with the chosen size. Stepping ←/→ (or
  swiping trackpad ←/→) while paused moves the focus line to the new slide
  and the context re-renders around it.
- **The block text is selectable** (Manh 2026-11-18, round 7): the reader
  can select a word in the context to translate it on the spot (the float
  icon appears on the selection), instead of only reading it. The focus
  line itself is not selectable — it is a single chunk rendered with a
  custom ORP layout.
- **Context display setting** ("Show context around focus word",
  SwiftRead's `contextDisplayStyle`, in Settings under Color Scheme):
  **Always** (book page even while playing) / **Only show when paused**
  (default, as before) / **Never** (focus line only, even when paused).
  Defaults key `rsvpContextDisplayStyle`.
- **Context:** ±150 words around the current chunk (SwiftRead).

## 4. Engine logic (`Sources/FastRead/RSVPEngine.swift`)

- **Tokenize** (paragraph-aware). **Chunk** 1–6 words at once (default 1).
  **WPM** default **500** (Manh 2026-11-18, round 7 — was 275), min 50,
  max 2000.
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
  (Shift+←/→ = step one sentence); ↑/↓ = speed ±50 WPM (Manh 2026-11-18,
  round 7 — was ±10, matching the picker's 50-step); Esc = close.
  (The blue focus ring is hidden with `.focusEffectDisabled()` — the view
  stays focusable so the keys work, just without the ring.)
- **Trackpad (`RSVPTrackpadMonitor`):** horizontal swipe = **one word per
  scroll event** (page-turn convention, SwiftRead-style; a longer swipe
  moves more words); **Style 2 (Basic Reading, Manh 2026-11-21): the
  horizontal swipe is a slow page flip — one line per 100pt of
  accumulated horizontal movement, so a swipe has to travel to turn the
  page. Style 1 keeps the fast one-step-per-event and is unaffected; the
  monitor follows the view model's reading style live.** Vertical swipe
  = **font ±16pt** per 50pt of accumulated
  vertical movement (Manh 2026-11-19, 0.1.5 — was ±8pt, which still felt
  too slow; 8pt was the 2026-11-18 round-7 value, ±2pt before that);
  remainder carries;
  momentum-phase events are ignored; mouse-wheel events pass through. **While paused, a vertical
  swipe ONLY changes the text size and NEVER scrolls the block text** (all
  dominant-vertical `.changed` events are consumed).
- **Pickers (menu style, show the nearest option):** Speed **50–2000 in
  steps of 50** (Manh 2026-11-18, round 7 — was 17 uneven values);
  **Focus size 40–450** (default 80; was 40–110, default 64; steps grow
  past 110 so the menu stays short); **Context size 25%–100%** of the
  focus size (default 40%; options 25, 30, 35, 40, 50, 60, 75, 100).
  Keyboard/trackpad can set in-between values; the label shows the true
  value.
- **Settings → "Reset to default" button** (Manh 2026-11-18, round 7):
  restores speed 500, focus size 80, context size 40%, context display
  "Only show when paused". Color scheme is a theme preference and is NOT
  reset.
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
- Settings toggle swaps Click between Speak and Fast Read (default **Fast
  Read** — Manh 2026-11-18, round 7, was Speak); the icon glyph shows what
  the click will do (see the icon spec).

## 8. Color schemes

- **White on Black** / **Black on White** (Settings → Color Scheme,
  Defaults `rsvpColorScheme`). Controls render with the chosen scheme
  (`.preferredColorScheme`) so buttons and pickers stay visible on the
  black background.

## 9. In-panel reading + Rest window (focus timer, Manh 2026-11-20)

Same engine and view model as the window, rendered by the panel's
own lite view (`CompactReadingView` in `Sources/FocusTimer/
PanelFastReadView.swift`) — embedded in panel right and in the
separate Rest window. No second reading implementation, and the
window file `RSVPView.swift` is never edited for panel work (Manh
2026-11-20, 05:36).

- **Panel right** (`Sources/FocusTimer/PanelFastReadView.swift`):
  idle = "Fast Read — coming soon" + focus demo ("reading", the "a"
  in yellow, half-bars above/below, via the shared `ORPLineView`) +
  "Read in panel" button for the translate tab's text; reading =
  the reading view only (coming-soon + book icon hidden). Display
  adapts to panel size: while playing, only focus + context + the
  shortcut hint; while paused at the default size, compact chrome
  (speed + compact Settings top-right, small progress bar, centered
  Rewind / Play / Forward / Maximize); while paused near maximum
  size (content width ≥ 540pt), the full window chrome (4-picker top
  bar, progress, 5-button control row, completion + share). Focus
  font is capped for the panel (48pt default size, 64pt near max) —
  the setting itself is unchanged. Vertical trackpad swipe changes
  font size (±16pt / 50pt, vertical-only monitor so horizontal swipes
  still switch panels); Space / ←/→ / ↑/↓ work (Shift+←/→ = sentence);
  Esc is ignored by the reading view so the panel's Esc-to-dismiss
  still works. **Space works at once when the Lite opens from the float
  icon (Manh 2026-11-21): the panel opens keyed for a Fast Read
  (`showAtCursor(makeKey: true)`) — a non-activating open would not
  route keystrokes to the reader until the user clicked into the panel
  first. The translate quick-peek stays non-activating.** The panel
  auto-pins when a panel read starts (pin button in the panel-right
  header toggles it off); auto-fit freezes while reading; Maximize
  toggles default (420×450) ↔ max (600×800).
- **Rest window** (`Sources/FocusTimer/RestWindowController.swift`,
  "TransPeek — Rest", 560×400, min 480×320): opens when a work /
  eye-rest interval ends and "Run reminder in:" is "New Fast Read
  Window". RSVP-reads the reminder, then shows the rest countdown
  (5 min / 20 s) and closes itself; Done closes early. Never touches
  an open Fast Read window.
- **Focus timer** (`Sources/FocusTimer/FocusTimerStore.swift`,
  card `Sources/UI/PopupPanel/FocusTimerCard.swift` in panel left):
  Pomodoro standard (Work 25 / Rest 5, long break 15 after 4 cycles)
  + rest eyes 20-20-20 (fixed), each with its own Start / Stop.
  "Run reminder in:" ("New Fast Read Window" / "Right Panel") applies
  ONLY to the reminder — Fast Read has its OWN separate setting, "Run
  FastRead in:" in panel right (Manh 2026-11-20, 05:27): "New Fast
  Read Window" (default) / "Right Panel", applying globally to every
  Fast Read launch (panel button, float icon, menubar, shortcut).
  A reminder to panel right opens the panel on the Fast Read tab and
  starts reading; after the read, the panel shows the rest countdown
  and returns to the demo. **The countdown screen's Done button has a
  blue border (Manh 2026-11-21) so it is easy to see and tap.** If a reminder fires while reading (window
  or panel), it does NOT interrupt — it waits as a banner + system
  notification ("Take a break" / "Snooze 5 min", orange dot on the
  Focus-Rest card) and shows when the read stops (Manh 2026-11-20,
  05:33).

## 10. Speaker button — read-along (continuous, word-sync)

- **Speaker = TTS on/off toggle for the read-along** (Manh 2026-11-21):
  a speaker button in the control row, with a voice picker (voice +
  speed 0.6x–4x). Play advances slide-by-slide (Style 1) or
  line-by-line (Style 2) in sync with the voice. TTS off → the WPM
  timer path is unchanged. The speed slider writes the global
  `ttsSpeechRate` (same key Settings → TTS uses); it takes effect from
  the next utterance.
- **Continuous speech, word-sync (Manh 2026-11-21, Option B):** the
  whole remaining text is spoken as ONE utterance (no gap between
  words, so the voice never stutters), and the focus follows the voice
  word by word via `AVSpeechSynthesizerDelegate
  .willSpeakRangeOfSpeechString` — each spoken word's range maps to the
  slide (Style 1) or line (Style 2) containing it. The speed is the
  TTS rate (1x–4x), not the WPM setting. Pausing stops the
  synthesizer; resuming speaks again from the current slide/line's
  first word. (This replaced the earlier chunk-by-chunk read-along,
  where each slide/line was a separate utterance and the finish-then-
  speak-next cycle left an audible gap.)
- **Lite + Full keep SEPARATE speaker state (Manh 2026-11-21):** each
  surface has its own on/off flag — they do not share it, which keeps
  the code simpler. Toggling the speaker on one surface does not change
  the other. (An earlier shared-state sync in `play()` was reverted.)
- **Pro gate for word-sync (Manh 2026-11-21):** word-sync was listed
  as a Pro feature in the internal Pro plan, but it ships FREE for now.
  The cut-off is a single flag, `ProGate.wordSyncEnabled` in
  `RSVPViewModel` (`Sources/FastRead/RSVPView.swift`): set it to
  `false` to disable word-sync (the read falls back to the silent WPM
  timer even with the speaker on), or wire it to a real Pro check
  (purchase / licence key) later. Future demo idea (NOT built yet):
  when gated, pressing the speaker plays a short DEMO — a different
  TTS voice reading a different text than the user's content, with a
  "this is a Pro feature" note — so the user hears the feature before
  buying.
- The speaker is hidden where there is no coordinator (Rest window).

## References

- Implementation (mac): `Sources/FastRead/RSVPView.swift` (window
  layout, book page, controls — window-only, never edited for panel
  work, Manh 2026-11-20, 05:36), `Sources/FocusTimer/
  PanelFastReadView.swift` (`CompactReadingView`, the panel-right /
  Rest-window lite reading view — shares only `RSVPViewModel` +
  `RSVPEngine` with the window), `RSVPViewModel` (state),
  `RSVPEngine.swift` (tokenize/chunk/timing/ORP + `wordRanges(for:)` for
  the read-along), `ORPReadingLine.swift`
  (shared focus line), `RSVPWindowController.swift` (window),
  `RSVPTrackpadMonitor.swift` (swipes), `RSVPShare.swift` (share URLs),
  `Sources/FocusTimer/` (store, Rest window, panel-right view).
- Speaker / TTS: `Sources/Core/TTSCoordinator.swift`
  (`speakContinuous` — one utterance + word ranges), `Sources/Services/
  TTSProvider.swift` (`speakWithWordTracking`), `Sources/Services/TTS/
  AppleTTSProvider.swift` (word tracking via
  `willSpeakRangeOfSpeechString`), `Sources/FastRead/SpeakerButton.swift`
  (speaker toggle + voice picker + speed slider).
- Original design spec:
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md` §14.
- Icon (entries + glyph): `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md`.
- Panel (the "Fast Read" button):
  `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` §9.
- Theme vs Style (Theme = colours, Style = reading mode + layout):
  `docs/UI/UX_DESIGN/FAST_READ_THEME_STYLE.md`.
- Select shows icon in Read mode (fake icon, speaker + hover, no Read):
  `docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md`.
