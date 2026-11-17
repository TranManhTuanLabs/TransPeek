# Architecture (bản nháp)

> Trạng thái: **bản nháp** — kiến trúc tổng, cập nhật dần. Spec chi tiết: `SPEC-v0.1.md`.

## 1. Stack

- **Swift 6, macOS 15.0+** (Apple Silicon + Intel), project Tuist (`Project.swift`).
- **Bundle ID:** `com.tranmanhtuanlabs.transpeek`. **URL scheme:** `transpeek`.
- **Updater:** Sparkle (Check for Updates + toggle tự check; link release notes còn thiếu).
- Build app bắt buộc **cài Xcode đầy đủ** — Command Line Tools không build được project Tuist.
- Ký CI bằng certificate tự ký 'TransPeek Self-Signed 100Years' (hạn tới 17/10/2126);
  app tự ký vẫn bị cảnh báo 'unidentified developer' lần đầu.

## 2. Cấu trúc repo

```
Sources/          # code Swift (Core, UI, ...)
Tests/            # XCTest
Resources/        # tài nguyên
docs/
  SPEC-v0.1.md    # SPEC + tên đã chốt
  TEST-BUILD-WORKFLOW-GITHUB/
    GIT-CI-BUILD-SETUP.md
    BUILD-TEST-WORKFLOW-GITHUB-CI.md
  FEATURES/       # mô tả từng tính năng
  UI/UX_DESIGN/   # spec UX (panel CHƯA VIẾT — chưa chốt size)
  ARCHITECTURE.md # doc này
  MASTER_PLAN.md  # lộ trình
  STRUCTURE_MAP.md# bản đồ repo + docs
  TASK_QUEUE.md   # việc đang làm / chờ
  UI_DESIGN.md    # chỉ mục UX
```

## 3. Thành phần chính

- **Dịch:** Google Translate (xem `SPEC-v0.1.md`); flip target theo favorite của user
  (KHÔNG hardcode cặp ENG–VIE).
- **OCR:** Vision là chính (`["vi-VN", "en-US"]`); Tesseract M3 hoãn.
- **TTS:** M2 tách riêng (chưa làm); M4 ElevenLabs + VieNeu.
- **Panel:** xem `UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` (CHƯA VIẾT — chưa chốt size).
- **Từ điển:** link + icon theo template `{word}`; Manh đang sưu tập thêm link.

## 4. Build / CI

- `test.yml`: test nhanh (lint + unit) mỗi push; build nặng/đóng gói/UI test chỉ ở
  main/tag release/chạy tay; huỷ run cũ khi push mới; cache dependency.
- Chỉ build app + up artifact khi commit có `[build-app]`; docs-only không trigger CI.
- Pre-release tự động mỗi build `[build-app]` (tag `v0.1.3.<run>`, chỉ giữ mới nhất).
- `release.yml` hướng B: tải đúng artifact của lần Tests xanh về đóng gói — bản phát
  hành = đúng bản đã test.
- Main khóa qua PR phải xanh mới merge.

## 5. Nguyên tắc kiến trúc

> Nguyên tắc chung cho MỌI dự án, MỌI repo (Manh 17/11/2026). Mục đích:
> code dễ bảo trì, dễ nâng cấp, linh động — ai mới vào cũng tìm được file
> cần sửa.

- **Dễ bảo trì, dễ nâng cấp, linh động (flexible):** viết sao cho sửa 1 chỗ
  không vỡ chỗ khác, thêm tính năng mới không phải đập đi viết lại.
- **Tách code / tách folder khi cần:** 1 tính năng = 1 module/thư mục riêng
  (xem §5.1).
- **Dùng chung hàm/component:** cái gì dùng nhiều chỗ thì viết 1 lần, không
  copy-paste — sửa 1 lần là hết mọi chỗ.
- **Cấu trúc rõ ràng như dự án lớn:** tên file/thư mục nói rõ nó là cái gì,
  ai mới vào cũng tìm được file cần sửa mà không cần hỏi.

### 5.1. Tính năng mới viết riêng module, không nhét vào code dịch (Manh 17/11/2026)

- **Quyết định:** các tính năng tomato/focus/rest-eyes/Fast Read/RSVP viết riêng
  file/module — **không nhét vào code chính / code dịch**.
- **Cấu trúc (mac + Windows làm cùng để 2 repo song song):**
  - `FastRead/` — engine RSVP + cửa sổ đọc + view của nó.
  - `BreakTimer/` — timer (Pomodoro/focus/20-20-20) + tab của nó.
  - `Shortcuts/` — bảng shortcut, **1 view dùng chung** cho nút "?" nhúng
    trong ô output + panel shortcut (tab trái), không copy-paste 2 bản.
- **Khung tab giữ mỏng:** 1 tab = 1 view + 1 tên, không gọi thẳng code dịch.
  Chỉ chạm code chung ở chỗ nối mỏng (nút, menubar/tray, Option+click,
  toggle Settings).
- **Cái dùng chung thật thì giữ chung, không nhân bản:** icon float, hiện/ẩn
  panel, Settings, provider dịch.
- **Không tách quá nhỏ** (1 file cho 1 hàm thì khó tìm) — 1 thư mục/tính năng,
  UI + logic nằm chung trong đó.
- **Đã làm (nhánh `feature/fast-read-rsvp`, 17/11/2026):** `Sources/FastRead/`
  có `RSVPEngine.swift` + `RSVPView.swift` + `RSVPWindowController.swift`
  (dời từ `Sources/Services/RSVP/` + `Sources/UI/RSVP/`, nội dung không đổi);
  `Sources/Shortcuts/` có `ShortcutsTableView.swift` (dời từ
  `Sources/UI/PopupPanel/ShortcutsPopoverView.swift`, chỉ đổi tên file —
  struct bên trong vốn đã tên `ShortcutsTableView`). 4 file cũ đã xoá.
- **Lý do:** tránh conflict và tránh làm vỡ panel dịch — panel đã qua quá
  nhiều vòng sửa (chuỗi che loa, nút "?", multi-tab), cứ đụng vào file của
  nó là dễ vỡ layout; mỗi tính năng có vòng đời riêng, lỗi của RSVP hay
  timer không được lan sang dịch.

## Liên kết

- [SPEC v0.1](SPEC-v0.1.md)
- [Lộ trình](MASTER_PLAN.md)
- [Bản đồ docs](STRUCTURE_MAP.md)
- [Bối cảnh AI](AI_CONTEXT.md)
- [Trạng thái dự án](PROJECT_STATE.md)
