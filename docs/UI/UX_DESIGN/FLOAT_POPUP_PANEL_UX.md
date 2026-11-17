# Float / Popup Panel — UX Spec

> **CHƯA VIẾT — chưa chốt size.**
>
> Panel mac chưa chốt size nên doc này chưa viết. Khi nào chốt size thì viết đầy đủ
> như bản Windows (`TranManhTuanLabs/TransPeek-Windows`,
> `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` — đã chốt 17/11/2026).
>
> **Số hiện tại (CHƯA CHỐT, chỉ để tham khảo — không phải spec):**
> mở mặc định 420×450, tối thiểu 400×450, tối đa 600×800, cap output 260pt,
> Settings chỉ đặt giá trị mặc định, mỗi lần mở về mặc định, kéo tay chỉ to ra thêm
> trong phiên, snap-back ngang, retry auto-fit 1 lần khi thiếu số đo, slider Settings
> (rộng 400...600, cao 450...800). Top bar: 1 size chung cho tên app + slogan
> (mặc định 17pt, slogan nhỏ hơn 2pt, sàn 8pt), key `popupTopBarFontSize`.
>
> Thiết kế panel chung mac + Windows đã chốt 16/11 (xem `SPEC-v0.1.md` và
> `AI_CONTEXT.md`); các số mac (mở mặc định 420, max rộng 600) nay bằng đúng
> số Windows đã chốt.

## Quyết định đã chốt (không phải số size — áp dụng ngay)

- **Loa + Copy ở TRONG ô output (Manh 2026-11-17):** mỗi provider có nút
  loa/Copy riêng ngay dưới text của chính nó (`ProviderResultCard`). Đưa ra
  ngoài thành hàng cố định thì phải thêm logic định tuyến nút về đúng provider
  (provider nào đang nói/copy, provider đang load thì sao, nhiều provider thì
  nút thuộc về ai) — phức tạp hơn mà không đáng. Giữ trong ô là đơn giản nhất
  và đúng với Windows (loa/Copy cũng ở trong ô output). Nhược điểm đã biết:
  text dài thì phải kéo xuống đáy mới thấy nút Copy — chấp nhận, vì đó là giá
  của việc mỗi provider có nút riêng.
- **Nút "?" bảng shortcut (Manh 2026-11-17):** nút `?` đứng ngay bên trái nút
  Pin ở hàng Actions; bấm mở popover liệt kê 9 shortcut theo đúng thứ tự
  Settings → Keyboard Shortcuts, mỗi dòng có tên + phím tắt hiện tại + nút Run
  chạy trực tiếp hành động đó (gọi đúng code path như bấm phím tắt —
  `AppDelegate.performShortcut`). Người dùng khỏi bấm phím vật lý.

## Liên kết

- [Icon float UX](FLOAT_ICON_UX_SPEC.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
- [Kiến trúc](../../ARCHITECTURE.md)
- [Việc đang làm / chờ](../../TASK_QUEUE.md)
- [Trạng thái dự án](../../PROJECT_STATE.md)
- [Chỉ mục UX](../../UI_DESIGN.md)
- [Panel UX Windows (đã chốt)](https://github.com/TranManhTuanLabs/TransPeek-Windows/blob/main/docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
