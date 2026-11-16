# Main Navigation — UX Spec (bản nháp)

> Trạng thái: **bản nháp** — ghi lại menu bar + cấu trúc Settings đã chốt,
> chờ Manh duyệt rồi mới thành spec chốt.

## 1. Menu bar

- App chạy ở **menu bar** (không có Dock icon thường trực — xem `SPEC-v0.1.md`).
- Menu bar hiện số CI build (build stamp: `CURRENT_PROJECT_VERSION` = số run CI;
  About hiện "Build CI #" dưới Version, ẩn khi = "1").
- Menubar/tray là 1 trong các luồng vào RSVP ("Đọc nhanh") — xem
  `FEATURES/SPEECH_PLAYER.MD`.

## 2. Cửa sổ Settings

- Tab: General, Translation, Dictionary, OCR, TTS Speech, About (theo thiết kế chung;
  chi tiết từng trang: `SETTING_UX.MD` — **CHƯA VIẾT**).
- **Text Size top bar:** DÙNG CHUNG 1 size cho tên app + slogan (Manh chốt):
  Settings → General, dưới 'Font Size': slider 12–24, mặc định 17pt; tên app lấy
  đúng số đó (đậm), slogan nhỏ hơn 2pt (tối thiểu 8pt). Key `popupTopBarFontSize`.
- Panel theo bố cục Windows: pickers ngôn ngữ trái, Capture OCR phải; Pin + Settings
  ở hàng Actions mới dưới kết quả, căn phải, Pin trước Settings. Panel cao thêm 18pt —
  Manh chốt GIỮ NGUYÊN.
- Hint thứ 3: "Hover icon to translate, Click to listen".

## Liên kết

- [Settings UX (chưa viết)](SETTING_UX.MD)
- [Tính năng Settings (chưa viết)](../../FEATURES/SETTINGS.MD)
- [Tổng quan UX](APP_UX_OVERVIEW.MD)
