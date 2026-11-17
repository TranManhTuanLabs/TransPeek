# App UX Overview (bản nháp)

> Trạng thái: **bản nháp** — tổng quan UX toàn app, các doc chi tiết nằm cùng thư mục
> `docs/UI/UX_DESIGN/`. Cập nhật dần khi từng phần chốt.

## 1. Định hướng app (Manh chốt, lâu dài)

1. **Dịch / tra từ là chính** (OCR hỗ trợ việc này).
2. **TTS là tính năng chính để NGHE text** thay vì đọc bằng mắt.
3. Cả 2 chung **1 float icon**: **HOVER → luồng dịch; CLICK → luồng TTS nghe**.

## 2. Luồng dùng chính

- Bôi chọn text → icon hiện → hover để dịch (panel mở) → đọc xong **click chuột ra
  chỗ khác cho panel tự ẩn** → bôi chọn cái mới.
- Panel **KHÔNG có nút đóng tay và KHÔNG CẦN**.
- Yêu cầu cốt lõi: **mỗi khi panel hiện ra là resize nếu cần** (auto-fit mỗi lần hiện).

## 3. Ngôn ngữ

- Ngôn ngữ UI gốc: **English**. Tiếng Việt thêm sau, rồi zh-Hans, Hàn khi app hoàn thiện
  cuối cùng. Chỉ thêm ngôn ngữ khi app đã hoàn thiện.

## 4. Các doc UX chi tiết

- `FLOAT_POPUP_PANEL_UX.md` — **CHƯA VIẾT (chưa chốt size)**. Bản Windows đã chốt:
  `TranManhTuanLabs/TransPeek-Windows`, `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md`.
- `FLOAT_ICON_UX_SPEC.md` — bản nháp: hình dạng + hành vi icon float.
- `MAIN_NAVIGATION_UX.md` — bản nháp: menu bar + cửa sổ Settings.
- `SETTING_UX.md` — **CHƯA VIẾT**.

## Liên kết

- [Panel UX (chưa viết)](FLOAT_POPUP_PANEL_UX.md)
- [Icon float UX](FLOAT_ICON_UX_SPEC.md)
- [Điều hướng chính](MAIN_NAVIGATION_UX.md)
- [Settings UX (chưa viết)](SETTING_UX.md)
- [Speech Player](../../FEATURES/SPEECH_PLAYER.md)
- [Quy tắc làm việc](../../AGENTS.md)
