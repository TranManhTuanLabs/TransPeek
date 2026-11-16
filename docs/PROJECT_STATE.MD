# Project State — TransPeek (mac)

> Trạng thái dự án tại thời điểm ghi. Cập nhật mỗi khi có thay đổi lớn.
> Việc đang làm / chờ: `TASK_QUEUE.MD`. Lộ trình: `MASTER_PLAN.md`.

## 1. Tổng quan (17/11/2026 ~05:00)

- **Version:** 0.1.3 (stable mac).
- **Head trên GitHub:** `67c470e` (fix test `streamingResultsRespectManualResize`,
  CI #197). Commit trước: `722da9d` (đợt redesign panel 22:41 ngày 16/11).
- **CI #197:** attempt 1 CANCELLED do hạ tầng runner macOS (không phải lỗi test);
  attempt 2 chạy lại lúc ~03:34 ngày 17/11 — **chưa rõ kết luận, cần kiểm tra lại**.

## 2. Đang mở

- **Panel UX mac: chưa chốt size → chưa viết doc.** Số hiện tại chỉ để tham khảo:
  mở mặc định 440×450, min 400×450, max 800×800, cap output 260pt.
- **CI #196 đỏ** (17/11 ~02:50): chỉ 1 test lỗi — `streamingResultsRespectManualResize`
  (112 pass, 1 fail); đã sửa ở `67c470e` (CI #197).
- **Nhánh `m2-m3-tts-ocr` ĐÃ XOÁ** (Manh chốt bỏ 17/11 ~02:52); PR #1 đóng không merge;
  repo giờ chỉ còn `main`.

## 3. Đã xong gần đây

- **Docs (17/11 ~05:00):** cấu trúc docs đầy đủ + cross-link + docs tree;
  `AGENTS.MD`, `AI_CONTEXT.MD`, `PROJECT_STATE.MD`. Cùng cấu trúc với repo Windows
  (Windows đã chốt panel UX; mac panel UX là placeholder vì chưa chốt size).
- **Đợt redesign panel 16/11 22:41** (`722da9d`): đồng nhất sizing với Windows,
  flip target generic, gỡ dây nối cursor monitor.
- **Text dài không tự dãn** — đã sửa (`1fe70a2`, CI #195).
- **Pre-release tự động** trong `test.yml` (tag `v0.1.3.<run>`, chỉ giữ mới nhất);
  run #188 xanh — xác nhận hoạt động.

## 4. Chờ Manh

- Chốt size panel mac → viết panel UX đầy đủ.
- Link từ điển — Manh tự sưu tập, gửi 1 thể; chỉ sửa khi Manh nói "bắt đầu fix".
- Lệnh bắt đầu M2 (TTS) khi tới lúc.

## 5. Baseline

- **Panel mac:** chưa có baseline chốt (khác Windows: Windows lấy #153 làm chuẩn).
- **Release:** stable 0.1.3; pre-release mới nhất `v0.1.3.188` (đã xác nhận hoạt động).

## Liên kết

- [Việc đang làm / chờ](TASK_QUEUE.MD)
- [Lộ trình](MASTER_PLAN.md)
- [Panel UX (chưa viết)](UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.MD)
- [Quy tắc làm việc](AGENTS.MD)
