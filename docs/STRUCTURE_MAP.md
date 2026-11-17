# Structure Map (bản nháp)

> Trạng thái: **bản nháp** — bản đồ repo + docs. Cập nhật dần khi thêm/sửa doc.

## 1. Repo

- **Repo:** `TranManhTuanLabs/TransPeek`, branch `main`, public. Fork từ cosZone/MoePeek.
- **Code:** `Sources/` (Swift 6, Tuist), `Tests/`, `Resources/`. Module riêng theo tính năng (xem `docs/ARCHITECTURE.md` §5.1): `Sources/FastRead/` (engine RSVP + cửa sổ đọc + view), `Sources/Shortcuts/` (bảng shortcut dùng chung).
- **Docs:** `docs/` (xem §2).

## 2. Bản đồ docs

| File | Nội dung | Trạng thái |
|---|---|---|
| `docs/SPEC-v0.1.md` | SPEC + tên đã chốt | Đang dùng |
| `docs/TEST-BUILD-WORKFLOW-GITHUB/GIT-CI-BUILD-SETUP.md` | Setup + intervention log | Đang dùng |
| `docs/TEST-BUILD-WORKFLOW-GITHUB/BUILD-TEST-WORKFLOW-GITHUB-CI.md` | CI detail | Đang dùng |
| `docs/LOCALIZATION.md` | Localisation | Đang dùng |
| `docs/M2-M3-TESTING.md` | Test M2/M3 (nhánh cũ đã xoá) | Lưu trữ |
| `docs/MANUAL-RELEASE.md` | Phát hành thủ công | Đang dùng |
| `docs/RELEASE-PROCESS.md` | Quy trình release | Đang dùng |
| `docs/SELF-SIGNED-CERTIFICATE-GUIDE.md` | Cert tự ký | Đang dùng |
| `docs/APP-SIGN-KEY-PERMISSIONS.md` | Quyền ký app | Đang dùng |
| `docs/ARCHITECTURE.md` | Kiến trúc tổng | Bản nháp |
| `docs/MASTER_PLAN.md` | Lộ trình | Bản nháp |
| `docs/STRUCTURE_MAP.md` | Doc này | Bản nháp |
| `docs/TASK_QUEUE.md` | Việc đang làm / chờ | Bản nháp |
| `docs/UI_DESIGN.md` | Chỉ mục UX | Bản nháp |
| `docs/FEATURES/FLOAT_ICON.md` | Tính năng icon float | Bản nháp |
| `docs/FEATURES/SPEECH_ENGINE.md` | Engine TTS | Bản nháp |
| `docs/FEATURES/SPEECH_PLAYER.md` | Player TTS + RSVP | Bản nháp |
| `docs/FEATURES/OCR_TEXT_CAPTURE.md` | OCR | Bản nháp |
| `docs/FEATURES/SETTINGS.md` | Tính năng Settings | **CHƯA VIẾT** |
| `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` | Panel UX | **CHƯA VIẾT (chưa chốt size)** |
| `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` | Icon float UX | Bản nháp |
| `docs/UI/UX_DESIGN/APP_UX_OVERVIEW.md` | Tổng quan UX | Bản nháp |
| `docs/UI/UX_DESIGN/SETTING_UX.md` | Settings UX | **CHƯA VIẾT** |
| `docs/UI/UX_DESIGN/MAIN_NAVIGATION_UX.md` | Menu bar + Settings | Bản nháp |
| `docs/AGENTS.md` | Quy tắc làm việc cho AI trong repo | Đang dùng |
| `docs/AI_CONTEXT.md` | Bối cảnh cho AI | Đang dùng |
| `docs/PROJECT_STATE.md` | Trạng thái dự án hiện tại | Đang dùng |
| `docs/BUILD_FROM_ZERO.md` | Build app từ máy trắng | Đang dùng |
| `docs/RESEARCH/README.md` | Chỉ mục research | Đang dùng |
| `docs/RESEARCH/transpeek-panel-sizing/report.md` | Research panel co dãn | Đang dùng |
| `docs/RESEARCH/tts-speechify-naturalreader/` | Research TTS (6 báo cáo) | Đang dùng |
| `docs/RESEARCH/transpeek-windows-packaging-signing/report.md` | Research đóng gói/ký/Store (Windows) | Đang dùng |

## 3. Cây docs

```
docs/
├── SPEC-v0.1.md                  # SPEC + tên đã chốt
├── TEST-BUILD-WORKFLOW-GITHUB/
│   ├── GIT-CI-BUILD-SETUP.md     # setup + intervention log
│   └── BUILD-TEST-WORKFLOW-GITHUB-CI.md
├── LOCALIZATION.md
├── M2-M3-TESTING.md              # lưu trữ (nhánh cũ đã xoá)
├── MANUAL-RELEASE.md
├── RELEASE-PROCESS.md
├── SELF-SIGNED-CERTIFICATE-GUIDE.md
├── APP-SIGN-KEY-PERMISSIONS.md
├── AGENTS.md                     # quy tắc làm việc cho AI
├── AI_CONTEXT.md                 # bối cảnh cho AI
├── PROJECT_STATE.md              # trạng thái dự án hiện tại
├── BUILD_FROM_ZERO.md            # build app từ máy trắng
├── RESEARCH/
│   ├── README.md                     # chỉ mục research
│   ├── transpeek-panel-sizing/       # panel co dãn (gốc mac, đối chiếu Windows)
│   ├── tts-speechify-naturalreader/  # TTS (6 báo cáo)
│   └── transpeek-windows-packaging-signing/  # đóng gói/ký/Store (Windows-specific)
├── ARCHITECTURE.md               # kiến trúc tổng
├── MASTER_PLAN.md                # lộ trình
├── STRUCTURE_MAP.md              # doc này (bản đồ + cây docs)
├── TASK_QUEUE.md                 # việc đang làm / chờ
├── UI_DESIGN.md                  # chỉ mục UX
├── FEATURES/
│   ├── FLOAT_ICON.md             # tính năng icon float
│   ├── SPEECH_ENGINE.md          # engine TTS
│   ├── SPEECH_PLAYER.md          # player TTS + RSVP
│   ├── OCR_TEXT_CAPTURE.md       # OCR
│   └── SETTINGS.md               # tính năng Settings (CHƯA VIẾT)
└── UI/
    └── UX_DESIGN/
        ├── FLOAT_POPUP_PANEL_UX.md   # panel UX (CHƯA VIẾT — chưa chốt size)
        ├── FLOAT_ICON_UX_SPEC.md     # icon float UX
        ├── APP_UX_OVERVIEW.md        # tổng quan UX
        ├── MAIN_NAVIGATION_UX.md     # menu bar + Settings
        └── SETTING_UX.md             # Settings UX (CHƯA VIẾT)
```

## 4. Quy ước

- Doc trong `docs/` viết tiếng Việt (trừ các doc cũ viết tiếng Anh từ đầu — giữ nguyên).
- Panel UX mac chưa viết vì chưa chốt size; khi chốt thì viết đầy đủ như bản Windows
  (`TranManhTuanLabs/TransPeek-Windows`, `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md`).

## Liên kết

- [Quy tắc làm việc](AGENTS.md)
- [Bối cảnh AI](AI_CONTEXT.md)
- [Trạng thái dự án](PROJECT_STATE.md)
- [Panel UX (chưa viết)](UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
- [Chỉ mục UX](UI_DESIGN.md)
