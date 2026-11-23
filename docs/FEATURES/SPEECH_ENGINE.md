# Speech Engine (bản nháp)

> Trạng thái: **bản nháp** — mô tả engine TTS mac. Spec UX: `docs/UI/UX_DESIGN/`.

## 1. Hướng đã chốt

- **TTS là tính năng chính để NGHE text** thay vì đọc bằng mắt (cùng với dịch/tra từ).
- **M2 (TTS) tách riêng** — làm mới trên main hiện tại khi tới lúc (nhánh
  `m2-m3-tts-ocr` đã xoá 17/11, PR #1 đóng không merge; code cũ xem lại được qua diff
  của PR đóng để tham khảo).
- **KHÔNG dùng Edge TTS** (đã quyết không dùng).
- **Speed audio gộp vào WPM (Manh 2026-11-23, làm sau):** sau này chỉ còn 1 control tốc độ đọc — slider Speed 0.6x–4x (key `ttsSpeechRate`) sẽ gộp vào WPM, không để 2 slider riêng. Chi tiết + bảng quy đổi: `FEATURES/FAST_READ.md` §10.
- **M4: ElevenLabs + VieNeu.** ElevenLabs = cloud REST, key của user, trả theo ký tự.
  VieNeu-TTS v3 Turbo on-device ~500–600MB, KHÔNG nhúng — chạy server local ngoài,
  app gọi localhost, làm theo kiểu nút tải engine ngoài; v4 chỉ qua API vieneu.io.
- **TTS v1 chỉ EN + VI**, làm SAU CÙNG (trong M2).

## 2. Giọng hệ thống

- Giọng hệ thống macOS (nền tảng `AVSpeechSynthesizer` / Speech framework).
- TTS v1: EN + VI. Ngôn ngữ khác thêm sau.

## Liên kết

- [Speech Player](SPEECH_PLAYER.md)
- [Kiến trúc](../ARCHITECTURE.md)
- [Tổng quan UX](../UI/UX_DESIGN/APP_UX_OVERVIEW.md)
