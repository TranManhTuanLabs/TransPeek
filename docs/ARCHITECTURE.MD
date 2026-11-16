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
  ARCHITECTURE.MD # doc này
  MASTER_PLAN.md  # lộ trình
  STRUCTURE_MAP.md# bản đồ repo + docs
  TASK_QUEUE.MD   # việc đang làm / chờ
  UI_DESIGN.MD    # chỉ mục UX
```

## 3. Thành phần chính

- **Dịch:** Google Translate (xem `SPEC-v0.1.md`); flip target theo favorite của user
  (KHÔNG hardcode cặp ENG–VIE).
- **OCR:** Vision là chính (`["vi-VN", "en-US"]`); Tesseract M3 hoãn.
- **TTS:** M2 tách riêng (chưa làm); M4 ElevenLabs + VieNeu.
- **Panel:** xem `UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.MD` (CHƯA VIẾT — chưa chốt size).
- **Từ điển:** link + icon theo template `{word}`; Manh đang sưu tập thêm link.

## 4. Build / CI

- `test.yml`: test nhanh (lint + unit) mỗi push; build nặng/đóng gói/UI test chỉ ở
  main/tag release/chạy tay; huỷ run cũ khi push mới; cache dependency.
- Chỉ build app + up artifact khi commit có `[build-app]`; docs-only không trigger CI.
- Pre-release tự động mỗi build `[build-app]` (tag `v0.1.3.<run>`, chỉ giữ mới nhất).
- `release.yml` hướng B: tải đúng artifact của lần Tests xanh về đóng gói — bản phát
  hành = đúng bản đã test.
- Main khóa qua PR phải xanh mới merge.

## Liên kết

- [SPEC v0.1](SPEC-v0.1.md)
- [Lộ trình](MASTER_PLAN.md)
- [Bản đồ docs](STRUCTURE_MAP.md)
- [Bối cảnh AI](AI_CONTEXT.MD)
- [Trạng thái dự án](PROJECT_STATE.MD)
