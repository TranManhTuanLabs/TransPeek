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

### Style 2 — Basic Reading (full-page scroll, Manh 2026-11-21)

- **What it is:** a second reading style, picked in the Window Read /
  Lite Settings popover alongside the color scheme. Style 1 is the RSVP
  focus window (§2 above); Style 2 is a scrollable page where the focus
  advances line by line. The two styles are independent of the Theme
  (color scheme) — any style works with any theme. Picker shows the
  names ("RSVP Focus" / "Basic Reading"), never "Style 1" / "Style 2".
- **Lines:** paragraphs are split into short logical lines of at most
  **12 words** (`RSVPViewModel.lines(for:maxWordsPerLine:)`), long
  enough to read as a phrase, short enough that the highlight moves at
  a readable pace. This is a logical split, not the visual wrap (which
  depends on font size and window width); matching visual lines is a
  later refinement.
- **"Highlight current line" toggle** (Settings, key
  `transpeek_rsvpHighlightCurrentLine`, default OFF): highlights the
  line the focus is on. While TTS is playing the highlight turns itself
  on (computed in the view, not stored).
- **Text is selectable (Manh 2026-11-22):** each line has
  `.textSelection(.enabled)`, so the reader can select a word to
  translate it (the alternative icon appears on the selection).
  Selection is a click-drag, so it never conflicts with the trackpad
  swipe (font size) — the page stays a ScrollView and scrolls the same.
- **Swipe contract — one gesture, one action (Manh 2026-11-22):**
  vertical swipe = font size ONLY, horizontal swipe = turn the page.
  - **Reason:** a vertical swipe that both changes the font AND scrolls
    the page is a conflict — the user gets two actions at once (the font
    jumps and the page moves), which feels broken. One gesture must do
    exactly one thing.
  - **Logic:** a trackpad swipe arrives as scroll-wheel events. The
    monitors classify by dominant axis — vertical-dominant
    (|deltaY| > |deltaX| × 1.5) → font size, ±16pt per 50pt of movement
    (fingers up = bigger, down = smaller); horizontal-dominant
    (|deltaX| > |deltaY| × 1.5) → turn the page, one line per 100pt of
    movement (the slow page flip; see the lẻ gộp note below). A diagonal
    swipe (neither axis dominant) passes through untouched.
  - **Behaviour:** swiping up/down changes only the font size — the page
    does NOT move. Swiping left/right turns the page (next/previous
    line). The focused line stays centered by auto-scroll (see below);
    the reader never scrolls the page by hand with a vertical swipe.
  - **Handling:** the page's `ScrollView` has user scrolling disabled
    (`.scrollDisabled(true)`) — it only scrolls programmatically, when
    Play advances the focus line (`ScrollViewReader.scrollTo`). The
    trackpad monitors consume the swipe events (return nil), so a swipe
    never reaches the ScrollView: Window uses `RSVPTrackpadMonitor`
    (vertical → font, horizontal → step), Lite uses
    `PanelReadTrackpadMonitor` (vertical → font, horizontal passes to
    the panel tab switch). The font-size step (16pt/50pt) matches Style 1
    and the window.
  - **Lẻ gộp (pending):** the Style 2 horizontal flip (1 line/100pt)
    feels slow — when the batch is big enough, lower the threshold to
    ~50pt/line. Style 1 keeps 1 step/event.
- **Setting:** key `transpeek_rsvpReadingStyle`, default `.style1`
  ("RSVP Focus"). A mode preference like the color scheme, so "Reset to
  default" does NOT reset it.
- **Trackpad in Style 2:** the swipe contract above (vertical = font
  size only, never scroll; horizontal = turn the page, one line per
  100pt). Style 1 keeps one step per event.

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
  custom ORP layout. **No scroll on the context text — custom component
  (Manh 2026-11-22):**
  - **Reason:** a selectable SwiftUI `Text` is backed by an NSTextView
    inside a scroll view. `.scrollDisabled(true)` (on the Group, then
    also on the Text) did NOT stop it: as soon as the user clicks into
    the text, the text view becomes the focused editor and turns into a
    scroll box for the above/below text. Native SwiftUI has no
    "selectable but never scrollable" text — so this needs a custom
    component (Manh was told before building it).
  - **Logic:** `NonScrollingSelectableText` wraps an `NSTextView`
    directly, with NO scroll view around it (`isSelectable = true`,
    `isEditable = false`, not vertically resizable). Without a scroll
    view there is nothing to scroll — overflow is clipped, exactly like
    the old `.clipped()` book page.
  - **Behaviour:** the reader can click-drag to select a word (the
    alternative icon appears on the selection, as before), but the
    context text never becomes a scroll box and never moves — the focus
    line stays pinned at the center.
  - **Handling:** the component replaces the 4 context `Text` views
    (Window + Lite, before + after). Font, color and alignment are
    passed in, so the look is unchanged.
  - **Verified (Manh 2026-11-22, CI342):** Full read works in BOTH
    styles — the context text is selectable and never becomes a scroll
    box. **Lite fix (same build round):** in the Lite panel the reading
    area also needs an `InteractiveMarker` (`.background` on the book
    page + the Style 2 page) — without it `PopupPanel.sendEvent`
    treats a click-drag over the text as a window drag, so the panel
    moves instead of selecting text (selection works only sometimes,
    and the cursor flickers between I-beam and arrow). The marker is
    the established pattern for "this area handles its own drag". The
    container also sets an I-beam cursor rect over the whole read
    half, so the cursor stays an I-beam throughout.
- **Context display setting** ("Show context around focus word",
  SwiftRead's `contextDisplayStyle`, in Settings under Color Scheme):
  **Always** (book page even while playing) / **Only show when paused**
  (default, as before) / **Never** (focus line only, even when paused).
  Defaults key `rsvpContextDisplayStyle`.
- **Context:** ±150 words around the current chunk (SwiftRead).
- **Known nit — clicking in the reading area still zooms the text
  (Manh 2026-11-21):** clicking around the text triggers the trackpad
  font-size gesture, so the text grows. The scroll itself is already
  disabled (§3, `.scrollDisabled`), but do NOT deep-disable scrolling
  to fix this — it could affect future styles. Current look approved.

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

- **Buttons (bottom, centered, in order):** Restart (read from the
  beginning), Speaker (TTS on/off, §10), Play/Pause (Space, prominent),
  Rewind (←), Fast-forward (→), Maximize (zoom). Lite adds a close (X)
  button first.
- **Keyboard (window focused):** Space = play/pause; ←/→ = step one slide
  (Shift+←/→ = step one sentence); ↑/↓ = speed ±50 WPM (Manh 2026-11-18,
  round 7 — was ±10, matching the picker's 50-step); Esc = close.
  (The blue focus ring is hidden with `.focusEffectDisabled()` — the view
  stays focusable so the keys work, just without the ring.)
- **Keyboard is focused-only — never global (Manh 2026-11-22, safe
  direction):** the keys above only work while the reading surface
  (window or panel) is the key/focused window. When the user clicks
  into another app (Chrome, Word, Notepad), the read surface loses
  focus and every keystroke goes to that app — the read keeps running
  in the background but receives no keys and never pauses/resumes.
  This is standard macOS key-window behaviour. A global key capture
  (polling Space system-wide, as Windows' `GlobalSpaceTracker` does)
  is NOT used: typing a Space in another app would also toggle the
  read, which is annoying — Manh asked Windows to switch to this same
  safe direction. The window/panel becomes key when a read opens
  (window: `makeKeyAndOrderFront`; panel: `showForFastRead()`), so Space
  works at once without a first click — and focus returns to the other
  app as soon as the user clicks away. (The 3 entry paths and the shared
  focus component are in §11.)
- **Trackpad (`RSVPTrackpadMonitor` window, `PanelReadTrackpadMonitor`
  Lite):** horizontal swipe = **one word per scroll event** (page-turn
  convention, SwiftRead-style; a longer swipe moves more words);
  **Style 2 (Basic Reading): the swipe contract in §2 — vertical =
  font size ONLY (never scroll), horizontal = turn the page, one line
  per 100pt of accumulated horizontal movement, so a swipe has to travel
  to turn the page. Style 1 keeps the fast one-step-per-event and is
  unaffected; the monitor follows the view model's reading style live.**
  Vertical swipe = **font ±16pt** per 50pt of accumulated
  vertical movement (Manh 2026-11-19, 0.1.5 — was ±8pt, which still felt
  too slow; 8pt was the 2026-11-18 round-7 value, ±2pt before that);
  remainder carries;
  momentum-phase events are ignored; mouse-wheel events pass through. **A vertical
  swipe ONLY changes the text size and NEVER scrolls anything** (all
  dominant-vertical `.changed` events are consumed; in Style 2 the page's
  ScrollView also has user scrolling disabled, so a swipe can never
  scroll it — see §2).
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
  two buttons for the translate tab's text under a "Read in:" title
  — "FastRead Lite" (always reads here) and "FastRead Full Window"
  (always opens the Window Read, Manh 2026-11-22). The buttons carry
  only the destination name — the "Read in" is already in the title,
  so repeating it on the buttons is redundant. Plus the "Run FastRead
  in:" picker ("FastRead Lite" / "FastRead Full Window (recommended)",
  renamed 2026-11-22 from "New FastRead Window" — "New" is wrong once
  the window is no longer new, and "Full" names the Lite-vs-Full
  contrast; same rename on Windows; "FastRead Lite" kept, "ReadMode"
  is not a term the app uses). The two buttons ignore the picker — it
  only decides where a LAUNCH (float icon, menubar, shortcut,
  reminder) goes. Reading = the reading view only (coming-soon + book icon
  hidden). Display adapts to panel size: while playing, only focus +
  context + the shortcut hint; while paused at the default size,
  compact chrome (speed + compact Settings top-right, small progress
  bar, centered Rewind / Play / Forward / Maximize); while paused near
  maximum size (content width ≥ 540pt), the full window chrome
  (4-picker top bar, progress, 5-button control row, completion +
  share). Focus
  font is capped for the panel (48pt default size, 64pt near max) —
  the setting itself is unchanged. Vertical trackpad swipe changes
  font size (±16pt / 50pt, vertical-only monitor so horizontal swipes
  still switch panels); Space / ←/→ / ↑/↓ work (Shift+←/→ = sentence);
  Esc is ignored by the reading view so the panel's Esc-to-dismiss
  still works. **Space works at once when the Lite opens from the float
  icon (Manh 2026-11-21): the panel opens keyed for a Fast Read
  (`showAtCursor(makeKey: true)`) — a non-activating open would not
  route keystrokes to the reader until the user clicked into the panel
  first. The same fix applies to a reminder that opens the panel
  (`onShowPanel`, Manh 2026-11-21): a reminder read in panel right
  also opens keyed, so Space pauses at once. The translate quick-peek
  stays non-activating. **And the keys are focused-only (see §5):**
  once the user clicks into another app, Space goes to that app and
  the panel read is untouched. **Focus is re-taken when a read starts
  playing (Manh 2026-11-22):** a reminder read that starts in an
  already-visible panel never fires `onAppear` again, so the SwiftUI
  focus stays lost from the previous read and Space never reaches the
  reader — `CompactReadingView` sets `isFocused = true` on every
  `isPlaying` → true, so Space works at once for the new read.** The panel auto-pins when a panel read starts
  (pin button in the panel-right header toggles it off); auto-fit
  freezes while reading; Maximize toggles default (420×450) ↔ max
  (600×800).
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
- **Alternative icon (Manh 2026-11-21):** selecting text inside Fast
  Read shows a fake float icon — a blue "A" in a chat bubble — for
  looking up one word or listening to it. It is a separate path
  (`Sources/UI/AlternativeIcon/`: `ReadSelectionMonitor` +
  `AlternativeIconController` + `AlternativeIconView`); it does not
  touch the real float icon's logic. A local mouse-up monitor +
  `AccessibilityGrabber` read the selection from TransPeek's own
  window (the global `SelectionMonitor` only sees other apps). Hover
  translates (Window Read opens the panel at the cursor; Lite only
  switches the already-open panel to the center tab — the panel
  follows `sourceText`); click speaks through the icon's own
  `AVSpeechSynthesizer` (separate from the Read speaker's
  TTSCoordinator path, so it never disturbs RSVP playback). No Read
  action. Only in Fast Read surfaces (Window Read open, or the panel
  on its Fast Read tab) — never for the translate input or Settings.
  **Speech delegate lifetime (crash fix, Manh 2026-11-22, build 342):**
  the delegate must stay alive until the framework's didFinish/didCancel
  fires — stopping (`stopSpeaking`) must NOT nil it at once, because
  Apple's TextToSpeech delivers didCancel asynchronously and retains
  the delegate in the pending callback; freeing it early crashes with
  EXC_BAD_ACCESS in objc_retain. Retired delegates are kept in
  `retiredDelegates` until their own callback fires. Design:
  `docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md`.

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
- **Comma pause — known issue (Manh 2026-11-22, NOT fixed yet):** the
  voice's pause at commas can break the reading rhythm. The pause is
  the Apple voice's built-in prosody inside the single utterance —
  the utterance text is passed verbatim (commas preserved) and Apple
  exposes no API to control intra-utterance punctuation pauses, so
  TransPeek cannot shorten it as-is; the highlight freezing during the
  pause is a consequence (no word callback fires while the voice is
  pausing), not a separate bug. Cause, what SwiftRead / jetzt / Sprint
  Reader / Speechify / NaturalReader do about pauses, and the proposed
  fix directions (split into phrase utterances with `postUtteranceDelay`,
  pre-process commas, or SSML `<break>`) are in the research report
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md` §6.5.
- **Lite + Full keep SEPARATE speaker state (Manh 2026-11-21) — SUPERSEDED 2026-11-23:** each
  surface had its own on/off flag — they did not share it, which kept
  the code simpler. Toggling the speaker on one surface did not change
  the other. (An earlier shared-state sync in `play()` was reverted.)
  Replaced by the shared + remembered speaker state below.
- **Speaker state is SHARED across Full + Lite and REMEMBERED (Manh 2026-11-23):** one
  on/off flag for all read surfaces (Full window + Lite panel + Rest
  window speaker, which follows the same flag), persisted across
  sessions. Default is still OFF on first run; toggling the speaker on
  one surface is remembered by the other, and the state survives app
  restarts. This supersedes the 2026-11-21 separate-state decision,
  which was a bug fix for the Lite button not toggling plus code
  simplicity — not a UX preference for separate states. Implementation:
  a single persisted setting, read when a read session starts and saved
  on toggle; no live sync between surfaces open at the same time (a
  surface picks up a change on its next read session).
- **Speaker in the Rest window (Manh 2026-11-23, BUILT):** the Rest
  window (reminder / rest-eyes countdown) now has a speaker button so
  the user can listen instead of reading while resting their eyes.
  Wired by giving `RestWindowController` the shared TTS coordinator
  (AppDelegate → `FocusTimerStore.ttsCoordinator` → `RestWindowController.ttsCoordinator`,
  injected into the SwiftUI environment as in the Fast Read window).
  The Rest window also installs an `RSVPTrackpadMonitor` (same as the
  Fast Read window), so vertical swipe changes the font size and
  horizontal swipe steps a slide — before this, the Rest window had no
  coordinator (speaker hidden) and no trackpad monitor (swipe did
  nothing), found by Manh's CI348 test on 2026-11-23. (The same gap was
  found on Windows the same day.)
- **Audio speed merges into WPM (Manh 2026-11-23, LATER — not scheduled yet):** the
  separate TTS speed slider (0.6x–4x, key `ttsSpeechRate`) will be
  merged into the WPM control — one speed control for reading, not
  two. Manh's sketch: 100 WPM ↔ 0.1x, 200 WPM ↔ 1.5x (recorded
  verbatim; the conversion table needs confirming before
  implementation — a normal TTS voice reads ~150 WPM at 1.0x, so
  100 WPM ≈ 0.6–0.7x).
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
- The speaker is hidden where there is no coordinator (Rest window) — a speaker will be added to the Rest window (Manh 2026-11-23, see above).

## 11. Read entry paths + keyboard focus (Manh 2026-11-22)

**The 3 paths that open a read** (user-visible triggers):

1. **User opens Fast Read** — Option+Click on the float icon, right-click
   the icon → "Fast Read", the "Fast Read" button in the translate panel,
   menubar → "Reading" section, or the global shortcut. Entry code:
   `AppDelegate.showFastRead` → window `RSVPWindowController.show`
   (`makeKeyAndOrderFront` + `NSApp.activate`) or panel
   `showAtCursor(makeKey: true)`, depending on Settings ("Run FastRead
   in:").
2. **Focus timer (Pomodoro) reminder** — when a focus interval ends,
   `FocusTimerStore.fireReminder(.workBreak(minutes:), countdownSeconds:
   rest minutes × 60)` → `showReminder` → if nothing is reading, opens a
   read in the panel right (`panelRightRequest` + `onShowPanel`) or a new
   Rest window, per `focusReminderDestination`. If a read is already
   running, the reminder waits (banner + system notification + orange
   dot) and never interrupts it.
3. **Rest-eyes (20-20-20) reminder** — the same `fireReminder`, with kind
   `.eyeRest` and a 20s countdown → the same `showReminder` path as the
   focus timer. Only the message text and the countdown differ; the code
   path is shared.

**Shared component — implemented on branch `feature/shared-read-focus`
(Manh 2026-11-22, after the v0.1.11 release):** the rule "read starts
playing → its surface becomes key + focused → Space works at once" now
lives in ONE place, `ReadKeyboardFocus` (`Sources/FastRead/
ReadKeyboardFocus.swift`, a SwiftUI `ViewModifier` + the
`.readKeyboardFocus(viewModel:onEscape:)` helper). It owns, once:

- the focus state (`@FocusState`, no longer one copy per view);
- focus on appear AND on every play start (`.onChange(of:
  viewModel.isPlaying)` — the 2026-11-22 reminder fix, which used to
  live only in Lite; the Window gets it too now, so a reused window
  re-takes focus on a new read);
- the key handling (Space play/pause, ←/→ step, Shift+←/→ sentence,
  ↑/↓ speed ±50). Esc is the one surface difference, passed as
  `onEscape`: the Window closes on Esc; Lite leaves it `nil` so Esc
  propagates to its host (panel dismiss monitor / Rest window closer).

**Wiring:** `RSVPView` applies `.readKeyboardFocus(viewModel:,
onEscape: { onClose?() })`; `CompactReadingView` applies
`.readKeyboardFocus(viewModel:)` (Esc `nil`). Both views deleted their
own `@FocusState` / `.onKeyPress` copies (Lite also deleted its
`handleKeyPress` and its own `.onChange(isPlaying)`); each kept only
its `onAppear` TTS-coordinator handoff. The Rest window's own
`.onKeyPress(.escape)` closer is untouched — it relies on Lite
ignoring Esc.

**Window keying (the AppKit half):** the Window always opens keyed in
`RSVPWindowController.show`, the Rest window in
`RestWindowController.show`; the panel opens keyed through the one
opener `PopupPanelController.showForFastRead()` (a thin wrapper over
`showAtCursor(makeKey: true)`), which both Lite entry paths use —
`AppDelegate.showFastRead` (`.rightPanel`) and the reminder's
`onShowPanel`. No entry path passes `makeKey: true` itself any more,
so a future path cannot forget the flag (the `b6388f20` bug).
`showAtCursor(makeKey:)` itself is unchanged — the translate
quick-peek keeps its non-activating default.

**The 3 entry paths now:** user opens Fast Read → `showFastRead` →
window `show` / `showForFastRead` + `panelRightRequest` →
`startPanelReading` → `play()` → `isPlaying` → the modifier re-takes
focus; Pomodoro / rest-eyes reminder → `fireReminder` → `showReminder`
→ Rest window `show` / `panelRightRequest` + `onShowPanel` →
`showForFastRead` → same modifier. Every path funnels through the
same focus rule; no path remembers the focus dance on its own.

**Why Space must work at once (Manh 2026-11-22):** a read can auto-start
(reminder / rest-eyes) and play the speaker out loud. If Manh is in a
crowded place or at the company and forgot to turn the speaker off, it
disturbs the people around him — he must be able to press Space
immediately to pause. That is the emergency-mute requirement: every read,
from every path, must accept Space the moment it starts playing.

**Planned direction — one shared component (AFTER the v0.1.11 release,
Manh 2026-11-22):** build a single shared read-keyboard/focus component
that both Full and Lite use, so the rule "read starts playing → its
surface becomes key + focused → Space works at once" lives in ONE place.
Every entry path goes through it; no path has to remember the focus dance
on its own. It keeps the safe direction (§5, focused-only, never global):
the component only makes the focus RELIABLE when a read is playing; it
never captures Space while the user types in another app.

**Done — see "Shared component" above (branch
`feature/shared-read-focus`).** The fragmented state described in the
earlier version of this section is gone: both views use
`ReadKeyboardFocus`, and the panel's keyed opener is
`showForFastRead()`.

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
