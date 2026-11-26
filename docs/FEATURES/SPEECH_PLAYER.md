# Speech Player (bản nháp)

> Trạng thái: **bản nháp** — mô tả player TTS (nút loa, auto-play, đọc nhanh RSVP).

## 1. Nút loa — play/pause/resume, hết mới stop (CHỐT 26/11/2026, thay luật cũ "bấm lần nữa là stop")

Luật cũ (trước 26/11): bấm loa lần nữa là stop luôn. Luật mới theo hành vi Speechify + NaturalReader (đã đọc source thật cả 2 extension — xem `docs/RESEARCH/tts-speechify-naturalreader/`): 1 nút loa = toggle Play/Pause, KHÔNG có nút Stop riêng. Áp dụng giống nhau cho mọi unit (1 từ, 1 câu, 1 đoạn — chỉ khác độ dài). Phạm vi: loa click-to-listen (loa panel + loa icon float). Loa trong Read mode (bật/tắt tiếng khi đọc RSVP) là control riêng, giữ nguyên.

- **Chưa phát → bấm loa = play** từ đầu unit.
- **Đang phát → bấm loa = pause**, giữ nguyên vị trí từ/câu đang dừng.
- **Đang pause → bấm loa = resume** đúng chỗ dừng (không phát lại từ đầu).
- **Hết unit → stop tự động**: reset vị trí về đầu, gỡ highlight, ẩn icon loa.
- **Dừng giữa chừng = Esc** — không có nút Stop riêng.
- **Pause thì GIỮ NGUYÊN highlight** ở từ đang dừng (không gỡ như NaturalReader) — để user thấy đang dừng ở đâu, resume nhìn rõ.
- **KHÔNG có timeout tự stop khi pause lâu**: pause vô thời hạn, resume lúc nào cũng được (cả 2 app đều vậy; pause là ý định của user, tự stop sẽ làm mất chỗ đang dừng).
- **Play mới thay play cũ**: bấm loa unit khác trong lúc đang phát/pause thì dừng cái cũ, phát unit mới từ đầu (auto-detect ON: hover block khác + click; OFF: select text mới + click). Bấm lại đúng unit đang pause thì resume.
- **Icon loa phải HIỆN trong suốt phiên phát** (đang phát HOẶC đang pause — tức là khi chưa stop hẳn) để user luôn bấm được để tương tác. Chỉ ẩn khi đã stop hẳn (hết unit / Esc). Luật cũ "loa chỉ hiện khi đang nói" sửa thành "loa hiện khi phiên phát còn hoạt động (phát hoặc pause)". Hệ quả: auto-hide tạm dừng trong suốt phiên phát (xem `FLOAT_ICON_UX_SPEC.md` §4), và icon không bị dismiss là stale trong lúc phát/pause (xem §8).

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

- [Speech Engine](SPEECH_ENGINE.md)
- [Float Icon](FLOAT_ICON.md)
- [Panel UX (chưa viết)](../UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
