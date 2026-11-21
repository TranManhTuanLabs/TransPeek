# Changelog — TransPeek (mac)

> Log thay đổi theo ngày, mới nhất lên đầu. Mỗi mục 1–2 dòng: ngày + commit + CI + thay đổi.
> Ảnh chụp nhanh tình hình hiện tại: `PROJECT_STATE.md`.

## 2026-11-22

- 03:05 — `762909cb` (docs-only): `FAST_READ.md` §11 — 3 đường mở read + trạng thái phân mảnh của Space/focus + hướng component chung (làm sau v0.1.11).
- 02:48 — `f50688aa` (CI341, đang chạy): context không cuộn — thêm `.scrollDisabled(true)` ngay trên Text (Window + Lite, trước + sau); gộp cả 2 sửa của `1ca40268`.
- 02:40 — `1ca40268` (CI340, bị supersede bởi `f50688aa`): Style 2 select được text; Lite lấy lại focus khi bắt đầu phát (sửa Space ở reminder/rest-eye read sau Lite).
- 01:53 — Manh chốt: phím trong Read chỉ ăn khi mặt đọc đang focus (không bắt phím toàn cục); doc `FAST_READ.md` §5 + §9 (`6732412d`, docs-only).
- 01:37 — `b77c3102` (CI339 XANH, pre-release `v0.1.5.339`): cỡ icon float mặc định 26→24pt, picker thêm 18/20/22; doc UX spec cập nhật (`a7db2ee3`).
- 00:57 — `b6388f20` (CI338 XANH, pre-release `v0.1.5.338`): sửa Space ở reminder read (`onShowPanel` → `makeKey: true`); icon alternative trong Fast Read (module `Sources/UI/AlternativeIcon/`).
- 23:11 (21/11) — `6bbf32d7` (CI337 XANH, pre-release `v0.1.5.337`): 2 picker cỡ icon float trong Settings → Translation.

## 2026-11-21

- 14:48 — Release v0.1.10 (stable).
- Tesseract OCR fallback MERGED (PR #10, `da885ae8`, CI331 XANH): Tesseract chỉ Apple Silicon, 34 ngôn ngữ, nút tải dữ liệu thiếu.
- Speaker Option B MERGED (PR #9, `474f70b0`): TTS liên tục + word-sync, speaker theo từng mặt, `ProGate`.
- Block-text detection MERGED (PR #8, `9b0816b8`): hover block text → icon float sau debounce 400ms.
- Hover icon + delay batch (`39f1053f` CI334, `593c86b4`, `1e8ff09d` CI336 XANH, pre-release `v0.1.5.336`).
- 30h doc catch-up (`106c757f`, docs-only): Style 2, control-row, click-zoom nit, pin −30°, Focus & Rest trong menubar Reading.
- Blank center-tab bug fixed (`79869410`, CI308): `hasPanelContent` thiếu arm `.translate`.
- Fast Read no-scroll fix (`8c2e6ee5`): `.scrollDisabled(true)` trên context text (bookPage).

## 2026-11-18/19

- Speaker + Style 2 MERGED (PR #4, `32ea3b08`): speaker TTS, speed slider 0.6x–4x, Style 2 "Basic Reading", voice picker dạng overlay.

## 2026-11-16/17

- Đợt redesign panel (`722da9d`, 16/11 22:41): đồng nhất sizing với Windows, flip target generic, gỡ dây nối cursor monitor.
- Text dài không tự dãn — đã sửa (`1fe70a2`, CI #195).
- Docs: cấu trúc docs đầy đủ + cross-link + docs tree; nhánh `m2-m3-tts-ocr` đã xoá (Manh chốt bỏ 17/11), PR #1 đóng không merge; repo chỉ còn `main`.

## 2026-11-11

- Ký CI bằng cert tự ký 'TransPeek Self-Signed 100Years' — đã lên main.
