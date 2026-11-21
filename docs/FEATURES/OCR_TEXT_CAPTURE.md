# OCR Text Capture

> Trạng thái: Vision là chính, Tesseract là fallback — **chỉ trên Apple
> Silicon** (phương án B, Manh 2026-11-21). Intel chỉ dùng Vision.

## 1. Engine OCR

### Vision (chính)

- **mac Vision là chính**, mặc định `["vi-VN", "en-US"]`.
- Vision OCR có từ macOS 10.15, chạy được cả Apple Silicon lẫn Intel;
  TransPeek yêu cầu macOS 15.0+.
- **Vision giống nhau trên Intel và Apple Silicon** — cùng API, cùng model,
  cùng ngôn ngữ (kể cả tiếng Việt); khác nhau theo phiên bản macOS, không
  theo chip. Chip M nhanh hơn nhờ Neural Engine, Intel dùng CPU/GPU. Nên
  máy Intel vẫn đọc chữ bằng Vision đầy đủ, chỉ thiếu dự phòng Tesseract
  khi Vision đọc không được.

### Tesseract (fallback, chỉ Apple Silicon — phương án B, Manh 2026-11-21)

- **Quyết định (phương án B): Tesseract chỉ bật trên Apple Silicon**
  (`#if arch(arm64)`); Intel chỉ dùng Vision. **Giữ nguyên bản
  universal** (hỗ trợ cả 2 chip, Intel còn lâu mới bỏ).
- **Lý do:** thư viện Tesseract chỉ có arm64, nên build universal Release
  lỗi link x86_64 (CI #307: bước test xanh, bước Build app đỏ — test build
  chỉ chạy trên máy arm64 nên test vẫn qua, còn link universal thì lỗi).
  Code được bọc `#if arch(arm64)` ở `TesseractOCRProvider.swift`,
  `ScreenCaptureOCR.swift`, `OCRSettingsView.swift` và bộ test;
  `Project.swift` vẫn khai báo external như cũ — code guard mới là phần
  sửa, CI kiểm chứng link.
- **Tesseract là fallback khi Vision không làm được** — Vision thử trước;
  Tesseract chạy khi Vision không hỗ trợ ngôn ngữ nào được chọn, hoặc
  Vision lỗi. Giới hạn v1: Vision trả về chữ SAI mà không báo lỗi thì
  KHÔNG kích hoạt fallback.
- Engine: XCFramework cộng đồng qua SPM binary target
  (`lexiaoyao20/tesseract-Apple`, Tesseract 5.5.2, arm64, tĩnh, kèm
  Leptonica), dùng qua lớp phủ Swift `TesseractSwift`.
  Provider: `TesseractOCRProvider` (theo protocol `OcrProvider`).
- **Ngôn ngữ: đủ 18 thứ tiếng trong `OCRSettingsView.availableLanguages`**
  (đủ bộ Vision trên macOS 15+: vi-VN, en-US, ar-SA, ars-SA, de-DE, es-ES,
  fr-FR, it-IT, ja-JP, ko-KR, pt-BR, ru-RU, th-TH, uk-UA, yue-Hans,
  yue-Hant, zh-Hans, zh-Hant) → mã tessdata: vie, eng, ara, deu, spa, fra,
  ita, jpn, kor, por, rus, tha, ukr, chi_sim, chi_tra. **3 thứ tiếng chỉ
  Vision đọc được** (ars-SA, yue-Hans, yue-Hant — Tesseract không có model
  cho chúng, fallback sẽ bỏ qua và đọc tiếng Anh nếu Vision lỗi).
- **Danh sách gạt ngôn ngữ trong Settings là card thu gọn** (bấm để
  ẩn/mở, mặc định thu gọn cho đỡ tốn diện tích — dòng thu gọn vẫn hiện
  các ngôn ngữ đang chọn, vd "Vietnamese, English").
- **Dữ liệu ngôn ngữ:** eng + vie nhúng sẵn trong app (tessdata_best,
  ~27 MB — eng 15.4 MB + vie 12.4 MB; Manh chốt 23:32 "nhúng best luôn",
  chấp nhận app tăng từ ~15 MB lên ~43 MB để chính xác nhất); 13 thứ
  còn lại download on-demand từ tessdata_best
  (`https://github.com/tesseract-ocr/tessdata_best/raw/main/<mã>.traineddata`)
  vào `~/Library/Application Support/TransPeek/tessdata`.
  Quản lý bởi `TesseractLanguageDataManager` (port từ Windows).
- **Nút tải trước trong Settings** (mục Tesseract fallback, chỉ Apple
  Silicon): nút "Download missing language data" tải ngay dữ liệu của
  các ngôn ngữ đã chọn mà còn thiếu — để lần OCR đầu không phải chờ tải
  giữa lúc chụp. Nút chỉ hiện khi còn ngôn ngữ thiếu dữ liệu; tải xong
  hiện kết quả (tải được / tải lỗi những ngôn ngữ nào).

### Chuỗi fallback

1. Vision thử trước với các ngôn ngữ user đã chọn trong Settings.
2. Ngôn ngữ nào Vision không hỗ trợ (hoặc Vision lỗi) → Tesseract thử
   với ngôn ngữ đó (chỉ trên Apple Silicon; Intel bỏ qua bước này).
3. Tesseract thiếu dữ liệu ngôn ngữ → tải ngầm (không hỏi, không báo);
   tải lỗi (mất mạng) thì bỏ ngôn ngữ đó CHỈ Ở LẦN CHỤP ĐÓ, OCR tiếp bằng
   các ngôn ngữ còn lại (rớt về `eng`), không hiện lỗi làm gián đoạn lúc
   chụp. Lần chụp sau (khi đã có mạng) app tự tải lại — KHÔNG bị bỏ vĩnh
   viễn, vì app không lưu lại lần tải lỗi nào (không có cờ "đã lỗi").

## 2. Hai chế độ

- **Chụp → panel** (gốc + dịch, auto-copy bản dịch mặc định bật).
- **Chụp → copy thẳng text gốc**, chỉ toast 'Đã copy'.
- Tesseract ĐÃ biên dịch trong dự án (từ 2026-11-20, nhánh
  `feature/tesseract-ocr-fallback`).

## Liên kết

- [Điều hướng chính](../UI/UX_DESIGN/MAIN_NAVIGATION_UX.md)
- [Kiến trúc](../ARCHITECTURE.md)
