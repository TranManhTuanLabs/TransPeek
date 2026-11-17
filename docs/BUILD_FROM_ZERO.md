# Build From Zero — TransPeek (mac)

> Hướng dẫn build app từ máy trắng (chưa cài gì), từ lúc clone tới lúc chạy được.
> Chi tiết CI: `TEST-BUILD-WORKFLOW-GITHUB/GIT-CI-BUILD-SETUP.md`, `TEST-BUILD-WORKFLOW-GITHUB/BUILD-TEST-WORKFLOW-GITHUB-CI.md`.
> Kiến trúc tổng: `ARCHITECTURE.md`. Quy tắc làm việc: `AGENTS.md`.

## 1. Cần gì (máy Mac)

- **macOS 15.0+** (app yêu cầu macOS 15+, chạy cả Apple Silicon lẫn Intel).
- **Xcode đầy đủ** (cài từ App Store, ~15GB) — **Command Line Tools KHÔNG đủ:**
  CLT không có `xcodebuild` đầy đủ để build project Tuist.
- **Swift 6** (đi kèm Xcode).
- **Tuist** (quản lý project, theo `.tuist-version` + `.mise.toml` trong repo;
  CI cài qua `mise`).
- **Git**.
- Dung lượng trống: Xcode ~15GB + derived data; máy Manh lúc kiểm tra còn ~12GB
  nên ưu tiên **dùng CI build ra app + tải artifact về chạy thử** trước khi cài Xcode local.

## 2. Clone + generate project

```bash
git clone https://github.com/TranManhTuanLabs/TransPeek.git
cd TransPeek
tuist generate
```

- `tuist generate` tạo `TransPeek.xcworkspace` từ `Project.swift` + resolve dependencies
  (Swift Package Manager).
- Mở `TransPeek.xcworkspace` bằng Xcode.

## 3. Build + chạy (Xcode)

- Scheme: **TransPeek**, destination: **My Mac**.
- Build: `Product → Build` (⌘B), chạy: `Product → Run` (⌘R).
- Hoặc bằng lệnh:

```bash
xcodebuild build -workspace TransPeek.xcworkspace -scheme TransPeek \
  -configuration Release -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO
```

- App build ra ở `build/Build/Products/Release/TransPeek.app`.
- Lần đầu chạy: cấp quyền **Accessibility + Screen Recording** (app cần để theo dõi
  selection và chụp màn hình OCR); cấp xong **quit + mở lại app** mới có tác dụng
  (quyền cấp lúc app đang chạy không có tác dụng tới khi mở lại).
- Mở app lần đầu (chưa ký cert thương mại): chuột phải → Open, hoặc `xattr -cr`
  để qua Gatekeeper (app tự ký vẫn bị cảnh báo 'unidentified developer' lần đầu).

## 4. Không muốn build? Tải bản có sẵn

- **Trang Releases** của repo: bản pre-release mới nhất `v0.1.3.<số run>`
  (file zip đính kèm, tải thẳng từ trang Releases).
- **Tab Actions → run Tests mới nhất đang xanh → Artifacts**: app artifact
  (chỉ giữ bản mới nhất).
- Check for Updates trong app (Sparkle) chỉ báo khi có bản release thật
  (tag + appcast), không báo pre-release.

## 5. Test

```bash
xcodebuild test -workspace TransPeek.xcworkspace -scheme TransPeek \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

- `CODE_SIGNING_ALLOWED=NO` để test không cần ký.
- Test bundle lưu dạng `.xcresult` — nguồn chính xác cho chi tiết từng test.

## 6. CI tự động làm gì

- File `.github/workflows/test.yml`: test nhanh (lint + unit) mỗi push;
  build nặng/đóng gói/UI test chỉ ở main/tag release/chạy tay; huỷ run cũ khi push mới.
- **Chỉ build app + up artifact khi commit có `[build-app]`** trong message.
  Commit chỉ sửa docs (`docs/**`, `*.md`) không trigger CI.
- Mỗi build `[build-app]` tạo thêm **pre-release** (tag `v0.1.3.<run>`,
  chỉ giữ mới nhất; bản cũ tự xoá). "0.1.3" trong tag là MARKETING_VERSION —
  khi bump version phải sửa trong `test.yml`.
- `release.yml` hướng B: tải đúng artifact của lần Tests xanh về đóng gói —
  bản phát hành = đúng bản đã test.
- Main khóa qua PR phải xanh mới merge.

## 7. Xử lý lỗi thường gặp

- **Không có `xcodebuild` / build Tuist lỗi:** chỉ cài CLT thì không đủ —
  cài Xcode đầy đủ từ App Store.
- **Quyền Accessibility / Screen Recording không có tác dụng:** quit hẳn app
  rồi mở lại (xem §3).
- **App báo 'unidentified developer':** app tự ký bằng cert tự ký
  'TransPeek Self-Signed 100Years' — cái giá của việc hoãn Apple Developer $99/năm.
  Chuột phải → Open lần đầu để qua.
- **CI đỏ do tải dependency / GitHub API 502:** retry run, đừng sửa code theo.

## Liên kết

- [Setup CI + intervention log](TEST-BUILD-WORKFLOW-GITHUB/GIT-CI-BUILD-SETUP.md)
- [CI detail](TEST-BUILD-WORKFLOW-GITHUB/BUILD-TEST-WORKFLOW-GITHUB-CI.md)
- [Kiến trúc](ARCHITECTURE.md)
- [Quy tắc làm việc](AGENTS.md)
- [Trạng thái dự án](PROJECT_STATE.md)
- [Bản đồ docs](STRUCTURE_MAP.md)
