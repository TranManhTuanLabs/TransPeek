# OCR Text Capture (bản nháp)

> Trạng thái: **bản nháp** — mô tả OCR mac: Vision là chính, Tesseract là fallback.

## 1. Engine OCR

### Vision (chính)

- **mac Vision là chính**, mặc định `["vi-VN", "en-US"]`.
- Vision OCR có từ macOS 10.15, chạy được cả Apple Silicon lẫn Intel;
  TransPeek yêu cầu macOS 15.0+.

### Tesseract (fallback, Manh 2026-11-20)

- **Tesseract là fallback khi Vision không làm được** — Vision thử trước;
  Tesseract chạy khi Vision không hỗ trợ ngôn ngữ nào được chọn, hoặc
  Vision không nhận ra chữ. Vision vẫn là chính.
- Engine: XCFramework cộng đồng qua SPM binary target
  (`lexiaoyao20/tesseract-Apple`, Tesseract 5.5.x, arm64, tĩnh, kèm
  Leptonica), dùng qua lớp phủ Swift `TesseractSwift`.
  Provider: `TesseractOCRProvider` (theo protocol `OcrProvider`).
- **Ngôn ngữ: đủ 8 thứ tiếng trong `OCRSettingsView.availableLanguages`**
  (vi-VN, en-US, zh-Hans, zh-Hant, ja-JP, ko-KR, fr-FR, de-DE) → mã
  tessdata: vie, eng, chi_sim, chi_tra, jpn, kor, fra, deu.
- **Dữ liệu ngôn ngữ:** eng + vie nhúng sẵn trong app (tessdata_best,
  ~27 MB — eng 15.4 MB + vie 12.4 MB; Manh chốt 23:32 "nhúng best luôn",
  chấp nhận app tăng từ ~15 MB lên ~43 MB để chính xác nhất); 6 thứ
  còn lại download on-demand từ tessdata_best
  (`https://github.com/tesseract-ocr/tessdata_best/raw/main/<mã>.traineddata`)
  vào `~/Library/Application Support/TransPeek/tessdata`.
  Quản lý bởi `TesseractLanguageDataManager` (port từ Windows).

## 2. Hai chế độ

- **Chụp → panel** (gốc + dịch, auto-copy bản dịch mặc định bật).
- **Chụp → copy thẳng text gốc**, chỉ toast 'Đã copy'.
- Tesseract ĐÃ biên dịch trong dự án (từ 2026-11-20, nhánh
  `feature/tesseract-ocr-fallback`).

## Liên kết

- [Điều hướng chính](../UI/UX_DESIGN/MAIN_NAVIGATION_UX.md)
- [Kiến trúc](../ARCHITECTURE.md)
