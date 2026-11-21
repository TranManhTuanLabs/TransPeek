# Master Plan (bản nháp)

> Trạng thái: **bản nháp** — lộ trình tổng, cập nhật dần khi Manh chốt từng bước.

## 1. Version

- Hiện tại: **0.1.10** (stable mac, release 21/11). Pre-release tự động `v0.1.5.<run>` (chỉ giữ mới nhất).
- Release tiếp theo: v0.1.11 từ bản xanh mới nhất (CI341), sau khi Manh test ok.

## 2. Lộ trình (plan mac)

- **M1: xong.**
- **M2 (TTS): cơ bản xong** — TTS + speaker + word-sync (PR #9, 21/11).
- **M3: XONG** (21/11, PR #10 — Tesseract OCR fallback, chỉ Apple Silicon, 34 ngôn ngữ).
- **M4: ElevenLabs + VieNeu** + nút tải engine ngoài.
- **M5: phát hành** (signing/notarize, Sparkle, dọn nợ).
- Apple Developer $99/năm: **tạm hoãn** (1 membership dùng chung iOS + macOS);
  code notarize giữ làm dự phòng.

## 3. Việc đang mở (xem chi tiết `TASK_QUEUE.md`)

- CI341 đang chạy (gộp Style 2 select + Lite focus + context no-scroll) → test rồi release v0.1.11.
- 2 lỗi CI341 chờ Manh duyệt khung sửa (context thành ô scroll; Style 2 vuốt lên cuộn thay vì chỉnh font).
- Component chung cho phím/focus của read — nợ, làm sau release v0.1.11.
- Link từ điển: chờ Manh gửi 1 thể, chỉ sửa khi Manh nói "bắt đầu fix".

## Liên kết

- [Việc đang làm / chờ](TASK_QUEUE.md)
- [Trạng thái dự án](PROJECT_STATE.md)
- [Log thay đổi theo ngày](CHANGELOG.md)
- [Kiến trúc](ARCHITECTURE.md)
- [Chỉ mục UX](UI_DESIGN.md)
