# Task Queue (bản nháp)

> Trạng thái: **bản nháp** — việc đang làm / chờ. Cập nhật dần khi xong hoặc có việc mới.
> Ghi rõ session + repo cho mọi mục nợ (quy tắc 17/11: tránh áp nhầm sang repo khác).

## ĐANG LÀM

- [ ] **Panel UX mac** (mac — TransPeek): **chưa chốt size → chưa viết doc**.
  Số hiện tại chỉ để tham khảo: mở mặc định 440×450, min 400×450, max 800×800,
  cap output 260pt. Khi nào chốt thì viết đầy đủ như bản Windows.
- [ ] **CI #197** (mac — TransPeek): attempt 1 bị CANCELLED do hạ tầng runner macOS
  (không phải lỗi test); attempt 2 chạy lại lúc ~03:34 ngày 17/11 — **chưa rõ kết luận,
  cần kiểm tra lại**.

## CHỜ MANH

- [ ] **Link từ điển** — Manh đang tự sưu tập, sẽ gửi 1 thể; CHỈ sửa khi Manh nói
  "bắt đầu fix". Sửa cả 2 repo (mac + Windows), gộp 1 commit + tự theo dõi CI.
- [ ] **M2 (TTS)** — làm mới trên main khi tới lúc (nhánh cũ đã xoá).
- [ ] **Doc UI/UX** — panel chưa chốt size; các doc còn lại là bản nháp, cập nhật dần
  khi hoàn thiện hoặc Manh yêu cầu. `SETTINGS.md` và `SETTING_UX.md` CHƯA VIẾT.

## NỢ / LÀM SAU

- [ ] M3 (Tesseract OCR) — HOÃN.
- [ ] M4: ElevenLabs + VieNeu + nút tải engine ngoài.
- [ ] M5: phát hành (signing/notarize, Sparkle, dọn nợ).
- [ ] Link release notes trong Settings → About (còn thiếu).
- [ ] Nút RSVP cạnh loa trong output — chưa chốt lại.

## ĐÃ ĐÓNG

- [x] Nhánh `m2-m3-tts-ocr` — Manh chốt bỏ (17/11 ~02:52), PR #1 đóng không merge.
- [x] Ký CI bằng cert tự ký 'TransPeek Self-Signed 100Years' — đã lên main (11/11).

## Liên kết

- [Trạng thái dự án](PROJECT_STATE.md)
- [Lộ trình](MASTER_PLAN.md)
- [Panel UX (chưa viết)](UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
