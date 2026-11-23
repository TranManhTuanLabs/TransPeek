# Changelog — TransPeek (mac)

> Log thay đổi theo ngày, mới nhất lên đầu. Mỗi mục 1–2 dòng: ngày + commit + CI + thay đổi.
> Ảnh chụp nhanh tình hình hiện tại: `PROJECT_STATE.md`.

## 2026-11-23

- 13:51 — Manh chốt: MỞ swipe ngang ở cửa sổ Nghỉ (panel vẫn khoá — không có tab nên không trùng); gộp theo vào phiên tiếp theo (lẻ gộp món 3/3). Ghi doc `FEATURES/FAST_READ.md` §2 + §10 (đợt docs này).
- 13:40 — Release v0.1.12 (stable, Release #36, app = CI353 `f08a9a3f`): Space ở cả 3 đường vào đọc, loa ở cửa sổ Nghỉ (nhớ chung), vuốt dọc đổi font ở cửa sổ Nghỉ, khoá swipe ngang Lite, đổi tên "FastRead Lite Window".
- 13:30 — Manh sửa quy tắc lẻ gộp: món đang chờ gộp THEO vào task tiếp theo nếu cùng nhánh, KHÔNG đợi đợt gộp sau / lệnh gộp tiếp theo.
- 12:26 — Pre-release `v0.1.5.353` (CI353 XANH): đổi tên label nhắc nhở.
- 12:23 — `73e58ba1` (docs-only): theme/style dùng chung + vẽ riêng theo mặt (`FAST_READ.md` §9).
- 12:06 — `e003317f` (docs-only): luồng nhắc nhở chung + mô hình 2 mặt (`FAST_READ.md` §9).
- 11:54 — `f08a9a3f` (CI353): đổi tên "Run reminder in:" → "FastRead Lite Window".
- 10:41 — `daf38565` (CI352 XANH, pre-release `v0.1.5.352`): khoá swipe ngang Lite (panel + cửa sổ Nghỉ).
- 10:28 — PR #11 merged (`ce86e95`): component chung phím/focus read (`ReadKeyboardFocus`).
- 10:20 — `71f242bb` (CI351, bị supersede bởi `daf38565`): loa + trackpad cho cửa sổ Nghỉ.
- 10:19 — (docs-only): 3 quyết định mới về loa read (Manh): (1) thêm loa vào cửa sổ nghỉ; (2) loa nhớ trạng thái chung Full + Lite, lưu bền (thay quyết định 21/11 mỗi mặt giữ riêng); (3) sau này gộp speed audio vào WPM thành 1 control chung. Ghi vào `FEATURES/FAST_READ.md` §10 + `TASK_QUEUE.md`.

## 2026-11-22

- 05:09 — Release v0.1.11 (stable, Release #35, app = CI344 `b0e314f0`).
- Post-release batch (CI347 XANH, pre-release `v0.1.5.347`): `c7ed69ad` book icon spacing, `46c8e357` "Read in:" title, `2cb39c10` nút ngắn + thứ tự nhắc nhở.
- `4bd122c2` (docs-only): quy tắc "sửa lặp → test + log + bắt lỗi + docs" vào `docs/AGENTS.md` §9.
- `ea5745df` (docs-only): block-text UX spec §8.
- `1bee44bf` + `48467629` (docs-only): comma ngắt nhịp — nghiên cứu + doc §6.5 (chưa sửa code).
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
