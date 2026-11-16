# OCR Text Capture (bản nháp)

> Trạng thái: **bản nháp** — mô tả OCR mac: Vision là chính, Tesseract hoãn.

## 1. Engine OCR

### Vision (chính)

- **mac Vision là chính**, mặc định `["vi-VN", "en-US"]`.
- Vision OCR có từ macOS 10.15, chạy được cả Apple Silicon lẫn Intel;
  TransPeek yêu cầu macOS 15.0+.

### Tesseract (M3 — HOÃN)

- M3 hoãn từ 09/11. Khi làm lại thì làm mới trên main (nhánh `m2-m3-tts-ocr` đã xoá).

## 2. Hai chế độ

- **Chụp → panel** (gốc + dịch, auto-copy bản dịch mặc định bật).
- **Chụp → copy thẳng text gốc**, chỉ toast 'Đã copy'.
- Tesseract KHÔNG biên dịch trong dự án.

## Liên kết

- [Điều hướng chính](../UI/UX_DESIGN/MAIN_NAVIGATION_UX.MD)
- [Kiến trúc](../ARCHITECTURE.MD)
