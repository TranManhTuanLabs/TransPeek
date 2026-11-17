# Float Icon — UX Spec (bản nháp)

> Trạng thái: **bản nháp** — ghi lại những gì đã chốt, chờ Manh duyệt rồi mới thành spec chốt
> như panel Windows.

## 1. Hình dạng

- Cửa sổ **32×32**, trong suốt thật, không có bubble.
- Icon theo dark/light system: chưa chốt.

## 2. Hành vi (đã chốt)

- **Mặc định: bôi chọn → icon → hover → float panel; click icon = TTS.**
- **Hover icon → luồng dịch; Click icon → luồng TTS nghe.**
- **Option-click (Mac) / Alt-click (Windows) → đọc nhanh (RSVP) thẳng** — đã chốt
  luồng vào RSVP 17/11, xem `FEATURES/SPEECH_PLAYER.md`.
- Chuột phải icon → menu có "Đọc nhanh".
- **Hover delay (Settings → General): Slider 300...800ms, bước 100ms, mặc định 500ms** (commit `0bdf99f`, Manh 17/11). Trước đây là Picker với mặc định 300ms — 300ms kích hoạt gần như ngay khi di chuột qua nên user không kịp click icon để nghe; tăng mặc định lên 500ms cho kịp click. Giá trị đã lưu của user được giữ nguyên khi đổi UI.
- **Auto-hide icon (Settings → General, ngay dưới Hover delay): Slider 3...10s, bước 1s, mặc định 5s** (commit `0bdf99f`, Manh 17/11). Defaults key mới `autoHideDelaySec`; `TriggerIconController.startAutoDismissTimer()` đọc giá trị này (trước đây fix cứng 5s). Icon tự ẩn sau khoảng này nếu không tương tác.

## 3. Tham chiếu

- Thiết kế chung mac + Windows: `SPEC-v0.1.md`, `AI_CONTEXT.md`.
- Bản Windows (đã chốt panel): `TranManhTuanLabs/TransPeek-Windows`,
  `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md`.

## Liên kết

- [Panel UX (chưa viết — chưa chốt size)](FLOAT_POPUP_PANEL_UX.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
- [Tính năng Float Icon](../../FEATURES/FLOAT_ICON.md)
- [Điều hướng chính](MAIN_NAVIGATION_UX.md)
