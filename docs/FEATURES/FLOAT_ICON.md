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
  ≤ 3 levels up). Model B (scan the whole accessibility tree / show the
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
- Compact hover icon (Manh 2026-11-21): the hover icon is 24 pt
  (`TriggerIconPanel.compactSize`), smaller than the 32 pt selection
  icon — it appears on every text block, so a smaller icon stays out
  of the mouse's way and does not cover the text. The glyphs (15 pt
  "A", 14 pt speaker) still fit. The selection icon keeps the full
  32 pt size.
- While the icon is up, the hovered block's frame is re-read every
  0.3 s; if it moved > 10 pt (the text scrolled away) or the element
  is gone, the icon is dismissed as stale. Polling stops when the icon
  is dismissed. While speaking, the icon is never dismissed as stale
  (the user needs it to stop playback).
- Settings (General → Translation, inside "Show floating icon on text
  selection"): "Show icon when hovering text (default: on)". Default ON.
  Below it, "Hover text delay (default: 400ms)" — a Picker
  (200/300/400/500/700 ms) for how long the mouse must stay still
  before the hover icon appears. Uses the same Accessibility permission
  as text selection — no new permission is needed.
- Limits (v1): a block must be ≥ 4 chars and ≤ 2000 chars; buttons,
  links and other controls never summon the icon; TransPeek's own
  windows are skipped; the excluded-apps list applies, same as selection.

## Liên kết

- [Icon float UX](../UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md)
- [Fast Read: icon giả khi bôi đen trong Read](../UI/UX_DESIGN/FAST_READ_SELECT_ICON.md)
- [Speech Player](SPEECH_PLAYER.md)
- [Tổng quan UX](../UI/UX_DESIGN/APP_UX_OVERVIEW.md)
