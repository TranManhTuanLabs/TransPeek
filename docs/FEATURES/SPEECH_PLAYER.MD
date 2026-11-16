# Speech Player (bản nháp)

> Trạng thái: **bản nháp** — mô tả player TTS (nút loa, auto-play, đọc nhanh RSVP).

## 1. Nút loa

- **Loa panel**: phát tiếng của text; bấm lần nữa để dừng (toggle).
- **Loa icon float**: click = phát text đã chọn.
- Khi click icon loa đang phát TTS, hover vào icon loa hiện panel tab 2/3 chỉnh nhanh
  tốc độ 1x/1.2x/1.5x/2x, chọn giọng, autoswitch voice nhận diện 2 ngôn ngữ — khỏi
  vào Settings; hoặc làm control riêng như Speechify/NaturalReader (định hướng 16/11).

## 2. Đọc nhanh (RSVP) — đã chốt luồng vào 17/11, CHƯA LÀM

- (1) Option-click (Mac) / Alt-click (Windows) → RSVP thẳng.
- (2) Chuột phải icon → menu "Đọc nhanh".
- (3) Nút "Đọc nhanh" trong panel dịch.
- (4) Menubar/tray. (5) Shortcut global chỉ là fallback.
- + Settings toggle đổi click → RSVP cho người dùng RSVP là chính.
- Vị trí view đọc: **giữ cả 2 phương án** (tab dãn / panel riêng), quyết ở lúc prototype.
  Nếu làm tab phải **ẩn HOÀN TOÀN chức năng panel dịch** khi đang đọc.
- Engine RSVP (tham khảo SwiftRead): WPM mặc định 275, max 2000, chunk 1–6,
  ORP pivot = ký tự giữa `floor(n/2)`, chữ cam `#f6861f`.
- **Model A là hướng thực tế cho app native; Model B KHÔNG làm** (ngay cả Speechify
  cũng chỉ Model B ở site quen viết selector tay).

## Liên kết

- [Speech Engine](SPEECH_ENGINE.MD)
- [Float Icon](FLOAT_ICON.MD)
- [Panel UX (chưa viết)](../UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.MD)
