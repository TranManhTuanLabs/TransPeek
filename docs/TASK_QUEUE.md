# Task Queue (bản nháp)

> Trạng thái: **bản nháp** — việc đang làm / chờ. Cập nhật dần khi xong hoặc có việc mới.
> Ghi rõ session + repo cho mọi mục nợ (quy tắc 17/11: tránh áp nhầm sang repo khác).

## ĐANG LÀM

- [ ] **CI341** (mac — TransPeek): Tests run cho commit `f50688aa` (gộp Style 2 select + Lite focus + context no-scroll) — đang chạy; xanh thì gửi link test cho Manh.
- [ ] **2 lỗi CI341 chờ Manh duyệt khung** (mac — TransPeek): (1) Style 1 Full — bấm/bôi đen chữ context thì thành ô scroll (cần component `NonScrollingSelectableText` tự chế); (2) Style 2 — vuốt lên thành cuộn thay vì chỉnh font. Đã trình khung, chờ anh bấm Ok.

## CHỜ MANH

- [ ] **Test CI341 → release v0.1.11** — Manh test 3 sửa (Style 2 select, Lite reminder/rest-eye Space, context không cuộn khi font to); ok thì release v0.1.11 từ bản xanh mới nhất.
- [ ] **Link từ điển** — Manh đang tự sưu tập, sẽ gửi 1 thể; CHỈ sửa khi Manh nói "bắt đầu fix". Sửa cả 2 repo (mac + Windows), gộp 1 commit + tự theo dõi CI.
- [ ] **Doc UI/UX** — `SETTINGS.md` và `SETTING_UX.md` CHƯA VIẾT; các doc còn lại cập nhật dần khi hoàn thiện hoặc Manh yêu cầu.

## NỢ / LÀM SAU

- [ ] **Component chung cho phím/focus của read** (mac — TransPeek, làm SAU khi release v0.1.11 xong, Manh 03:04) — 1 component chung cả Full + Lite, quy tắc "read phát → mặt read thành cửa sổ chính + lấy focus ngay → Space ăn ngay". Đã ghi doc `FAST_READ.md` §11.
- [ ] **Lẻ gộp: Style 2 vuốt ngang hơi chậm** (mac — TransPeek, chờ đủ 3-4 món) — 1 dòng/100pt → ~50pt/dòng, chỉ Style 2.
- [ ] M4: ElevenLabs + VieNeu + nút tải engine ngoài.
- [ ] M5: phát hành (signing/notarize, Sparkle, dọn nợ).
- [ ] Link release notes trong Settings → About (còn thiếu).
- [ ] Nút RSVP cạnh loa trong output — chưa chốt lại.

## ĐÃ ĐÓNG

- [x] Tesseract OCR fallback (PR #10, 21/11) — Tesseract chỉ Apple Silicon, 34 ngôn ngữ.
- [x] Speaker Option B + Style 2 (PR #9, 21/11) — TTS liên tục + word-sync.
- [x] Block-text detection (PR #8, 21/11) — hover block text → icon float.
- [x] Nhánh `m2-m3-tts-ocr` — Manh chốt bỏ (17/11 ~02:52), PR #1 đóng không merge.
- [x] Ký CI bằng cert tự ký 'TransPeek Self-Signed 100Years' — đã lên main (11/11).

## Liên kết

- [Trạng thái dự án](PROJECT_STATE.md)
- [Log thay đổi theo ngày](CHANGELOG.md)
- [Lộ trình](MASTER_PLAN.md)
- [Panel UX](UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
