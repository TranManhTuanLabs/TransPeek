# Float Icon (bản nháp)

> Trạng thái: **bản nháp** — mô tả tính năng icon float. Spec UX chi tiết:
> `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md`.

## 1. Tính năng

- Icon tròn nhỏ hiện gần text user bôi chọn (theo dõi selection tự động).
- **Hover → mở panel dịch.** **Click → phát TTS** của text đã chọn.
- Option-click → đọc nhanh (RSVP) thẳng. Chuột phải → menu có "Đọc nhanh".

## 2. Cài đặt liên quan

- Watch selection automatically, hover delay, trigger icon hides after
  (xem `SETTINGS.md` khi viết xong).

## 3. Hover block detection (Manh 2026-11-21)

- Hovering a block of text in another app shows the float icon
  **without selecting the text first**. After the icon appears, the
  flow is the normal icon flow (hover → translate panel; click → Speak /
  Fast Read per "Click icon for:"; Option+click → the other action).
- Model A (research TTS 16/11): hover → hit-test ONE point via the
  macOS Accessibility API (`AXUIElementCopyElementAtPosition`), read the
  text element under the cursor (or its nearest text-bearing ancestor,
  ≤ 5 levels up — was 3, raised in step 1, 2026-11-23). A link is
  climbed past, not stopped at (step 1): hovering a link inside a
  paragraph summons the icon for that paragraph; the link's own text
  is never taken. Model B (scan the whole accessibility tree / show the
  icon on every block) is NOT done — too expensive on CPU and does not
  follow scrolling.
- Only apps that expose text via Accessibility work. Apps/places that do
  not expose text are out of scope (separate research, next session) —
  hovering there simply does nothing.
- Debounce (Manh 2026-11-21): the icon appears only after the mouse
  has stayed still over a text block for the "Hover text delay"
  (Settings, default 400 ms; was a fixed ~150 ms). Longer = the icon
  only shows on a deliberate pause, not while sweeping the mouse
  across text. No hit-test while dragging (a selection is in progress —
  the selection flow owns it), and no delivery while the icon or the
  panel is already up.
- Icon sizes (Manh 2026-11-21, default changed 2026-11-22): both icon
  sizes are user-adjustable in Settings (see below). The selection
  icon defaults to 24 pt (`TriggerIconPanel.size`, key
  `floatIconSize`, Picker 18/20/22/24/26/28/30/32 — recommend
  20-24pt) and the hover icon defaults to 24 pt (`compactSize`, key
  `autoShowFloatIconSize`, Picker 18/20/22/24 — recommend 20, 22pt) —
  the hover icon appears on every text block, so it is smaller by
  default and stays out of the mouse's way. The glyphs scale with the
  circle ("A" = half the diameter, speaker ~44%, "+" badge a quarter),
  so a smaller circle still shows a proportional letter. Sizes are
  read live at each show, so a Settings change applies to the next icon.
- While the icon is up, the hovered block's frame is re-read every
  0.3 s; if it moved > 10 pt (the text scrolled away) or the element
  is gone, the icon is dismissed as stale. Polling stops when the icon
  is dismissed. While a playback session is active (playing or paused),
  the icon is never dismissed as stale (the user needs it to
  pause/resume/stop playback).
- Settings (General → Translation, inside "Show floating icon on text
  selection"): "Show icon when hovering text (default: on)". Default ON.
  Below it, "Hover text delay (default: 0.4s)" — a Picker
  (0.2/0.3/0.4/0.5/0.7 s) for how long the mouse must stay still
  before the hover icon appears. Values are shown in seconds (Manh
  2026-11-21) because 0.4s is easier to picture than 400ms; the
  stored value is still milliseconds. Below that, "Float icon size
  (default: 24pt — recommend 20-24pt)" — a Picker
  (18/20/22/24/26/28/30/32 pt) for the selection icon — and
  "Auto-show float icon size (default: 24pt — recommend 20, 22pt)" —
  a Picker (18/20/22/24 pt) for the hover icon. Uses the same
  Accessibility permission as text selection — no new permission is
  needed.
- Limits (v1): a block must be ≥ 4 chars and ≤ 2000 chars; buttons,
  links and other controls never summon the icon; TransPeek's own
  windows are skipped; the excluded-apps list applies, same as selection.
  Full threshold table + done/not-doing/not-yet decisions:
  `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` §8 (Spec snapshot +
  Decisions, recorded 2026-11-23).

## Liên kết

- [Icon float UX](../UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md)
- [Fast Read: icon giả khi bôi đen trong Read](../UI/UX_DESIGN/FAST_READ_SELECT_ICON.md)
- [Speech Player](SPEECH_PLAYER.md)
- [Tổng quan UX](../UI/UX_DESIGN/APP_UX_OVERVIEW.md)
