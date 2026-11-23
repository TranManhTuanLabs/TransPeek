# Project State — TransPeek (mac)

> Ảnh chụp nhanh tình hình hiện tại. Đọc là nắm được ngay.
> Log thay đổi theo ngày: `CHANGELOG.md`. Việc đang làm / chờ: `TASK_QUEUE.md`. Lộ trình: `MASTER_PLAN.md`.

## 1. Tổng quan (23/11/2026 ~13:52)

- **Version:** 0.1.12 (stable mac, release 23/11/2026 13:40, app = CI353 build `f08a9a3f`).
- **Head trên GitHub:** `73e58ba1` (docs: theme/style dùng chung + vẽ riêng theo mặt). Commit code mới nhất: `f08a9a3f` (đổi tên "Run reminder in:" → "FastRead Lite Window", CI353 xanh).
- **Release v0.1.12 đã publish:** Space ở cả 3 đường vào đọc, loa ở cửa sổ Nghỉ (nhớ chung), vuốt dọc đổi font ở cửa sổ Nghỉ, khoá swipe ngang ở panel Lite, đổi tên "FastRead Lite Window".
- **Release tiếp theo:** sau khi TTS sync-word xong (xem §2).

## 2. Đang mở

- **TTS sync-word (việc lớn tiếp theo, Manh duyệt 22/11):** gộp loa + highlight từ + highlight câu thành 1 component chung cho Full + Lite, module riêng. Trình khung trước cho Manh duyệt, rồi làm trên nhánh riêng.
- **Lẻ gộp chờ (3 món, gộp THEO vào task tiếp theo nếu cùng nhánh — Manh 23/11 13:30, KHÔNG đợi đợt gộp sau):** (1) Style 2 vuốt ngang hơi chậm (1 dòng/100pt → ~50pt/dòng); (2) "Read in:" căn lề trái theo "Run FastRead in:"; (3) MỞ swipe ngang ở cửa sổ Nghỉ (panel vẫn khoá) — Manh chốt 23/11 13:51.
- **Docs bắt kịp:** CHANGELOG + PROJECT_STATE lên v0.1.12 (đẩy cùng đợt docs này).

## 3. Chờ Manh

- Duyệt khung TTS sync-word khi em trình (sau đợt docs này).
- Link từ điển — Manh tự sưu tập, gửi 1 thể; chỉ sửa khi Manh nói "bắt đầu fix".
- SwiftRead APK: chờ Manh gửi file APK hoặc đẩy source Seeless AI Speech lên repo thì mới phân tích tiếp được.

## 4. Baseline

- **Nhánh:** chỉ còn `main` (sửa nhỏ làm luôn trên main, không tách nhánh; việc lớn mới tách nhánh).
- **Release:** stable 0.1.12; pre-release mới nhất `v0.1.5.353` (CI353 xanh).
- **Quyền GitHub:** Manh cho quyền đến ~29/11 — Muse tự đẩy + xem log CI qua trình duyệt (TransPeek mac + Windows + SeekZip); hết hạn phải xin lại.

## Liên kết

- [Log thay đổi theo ngày](CHANGELOG.md)
- [Việc đang làm / chờ](TASK_QUEUE.md)
- [Lộ trình](MASTER_PLAN.md)
- [Quy tắc làm việc](AGENTS.md)
