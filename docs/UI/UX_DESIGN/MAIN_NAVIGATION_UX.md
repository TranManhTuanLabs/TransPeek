# Main Navigation — UX Spec (bản nháp)

> Trạng thái: **bản nháp** — ghi lại menu bar + cấu trúc Settings đã chốt,
> chờ Manh duyệt rồi mới thành spec chốt.

## 1. Menu bar

- App chạy ở **menu bar** (không có Dock icon thường trực — xem `SPEC-v0.1.md`).
- Menu bar hiện số CI build (build stamp: `CURRENT_PROJECT_VERSION` = số run CI;
  About hiện "Build CI #" dưới Version, ẩn khi = "1").
- Menubar/tray là 1 trong các luồng vào RSVP ("Đọc nhanh") — xem
  `FEATURES/SPEECH_PLAYER.md`.
- **Menubar mac dùng được submenu (Manh 12:06):** menubar chỉ có 1 hàng
  nhưng mỗi mục chính mở được list con của chính nó — nên tích hợp thêm
  menu Tomato/Focus/Fast Read là hoàn toàn khả thi, không sợ menu dài
  (mục mới nằm trong submenu, không thêm mục top-level). Áp cho cả luồng
  vào RSVP (mục menubar/tray) và tab timer sau này (Tomato/Focus có thể
  điều khiển nhanh từ submenu menubar mà không cần mở panel). Lưu ý: tray
  Windows cũng mở được submenu tương tự — khi làm Windows thì giữ cùng
  pattern.
- **Sections (Manh 2026-11-21):** "Focus & Rest" nằm TRONG section
  "Reading" (không phải section riêng) — bấm vào mở panel ở tab TRÁI
  (tab Focus & Rest), vì nó thuộc về việc đọc/nghỉ. Xem
  `Sources/UI/MenuBar/MenuItemView.swift`.

## 2. Cửa sổ Settings

- Tab: General, Translation, Dictionary, OCR, TTS Speech, About (theo thiết kế chung;
  chi tiết từng trang: `SETTING_UX.md` — **CHƯA VIẾT**).
- **Text Size top bar:** DÙNG CHUNG 1 size cho tên app + slogan (Manh chốt):
  Settings → General, dưới 'Font Size': slider 12–24, mặc định 17pt; tên app lấy
  đúng số đó (đậm), slogan nhỏ hơn 2pt (tối thiểu 8pt). Key `popupTopBarFontSize`.
- Panel theo bố cục Windows: pickers ngôn ngữ trái, Capture OCR phải; Pin + Settings
  ở hàng Actions mới dưới kết quả, căn phải, Pin trước Settings. Panel cao thêm 18pt —
  Manh chốt GIỮ NGUYÊN.
- Hint thứ 3: "Hover icon to translate, Click to listen".

## Liên kết

- [Settings UX (chưa viết)](SETTING_UX.md)
- [Tính năng Settings (chưa viết)](../../FEATURES/SETTINGS.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
