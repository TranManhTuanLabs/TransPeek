# Project State — TransPeek (mac)

> Ảnh chụp nhanh tình hình hiện tại. Đọc là nắm được ngay.
> Log thay đổi theo ngày: `CHANGELOG.md`. Việc đang làm / chờ: `TASK_QUEUE.md`. Lộ trình: `MASTER_PLAN.md`.

## 1. Tổng quan (22/11/2026 ~03:20)

- **Version:** 0.1.10 (stable mac, release 21/11/2026 14:48).
- **Head trên GitHub:** `762909cb` (docs: `FAST_READ.md` §11 — 3 đường mở read). Commit code mới nhất: `f50688aa` (context không cuộn, CI341).
- **CI341 (Tests, commit `f50688aa`):** đang chạy — gộp 3 sửa: Style 2 select được text, Lite lấy lại focus khi phát (Space ở reminder/rest-eye read), context không cuộn khi font to. Pre-release `v0.1.5.341` sẽ tạo khi xanh.
- **Release tiếp theo:** v0.1.11 từ bản xanh mới nhất (CI341), sau khi Manh test ok.

## 2. Đang mở

- **2 lỗi CI341 chờ Manh duyệt khung sửa** (đã trình khung, chờ anh bấm Ok): (1) Style 1 Full — bấm/bôi đen chữ context thì thành ô scroll (cần component `NonScrollingSelectableText` tự chế); (2) Style 2 — vuốt lên thành cuộn thay vì chỉnh font (cần chặn vuốt dọc ở Window + Lite).
- **Component chung cho phím/focus của read** — NỢ, làm SAU khi release v0.1.11 xong (Manh 03:04). Đã ghi doc `FAST_READ.md` §11.
- **Lẻ gộp chờ đủ món:** Style 2 vuốt ngang hơi chậm (1 dòng/100pt → ~50pt/dòng), chỉ Style 2.

## 3. Chờ Manh

- Test CI341 (Style 2 select, Lite reminder/rest-eye Space, context không cuộn khi font to) → ok thì release v0.1.11.
- Duyệt khung sửa 2 lỗi CI341 (mục §2).
- Link từ điển — Manh tự sưu tập, gửi 1 thể; chỉ sửa khi Manh nói "bắt đầu fix".

## 4. Baseline

- **Nhánh:** chỉ còn `main` (sửa nhỏ làm luôn trên main, không tách nhánh).
- **Release:** stable 0.1.10; pre-release mới nhất `v0.1.5.339` (CI339 xanh); `v0.1.5.341` đang chờ CI341.
- **Quyền GitHub:** Manh cho quyền 7 ngày (đến ~24/11) — Muse tự đẩy + xem log CI qua trình duyệt (TransPeek mac + Windows); hết hạn phải xin lại.

## Liên kết

- [Log thay đổi theo ngày](CHANGELOG.md)
- [Việc đang làm / chờ](TASK_QUEUE.md)
- [Lộ trình](MASTER_PLAN.md)
- [Quy tắc làm việc](AGENTS.md)
