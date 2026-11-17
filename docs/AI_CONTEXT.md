# AI Context — TransPeek (mac)

> Bối cảnh cho AI làm việc trong repo này. Quy tắc làm việc: `AGENTS.md`.
> Trạng thái hiện tại: `PROJECT_STATE.md`. Bản đồ docs: `STRUCTURE_MAP.md`.

## 1. App là gì

- **TransPeek (mac)**: app dịch / tra từ / nghe (TTS) / OCR cho macOS,
  fork từ MoePeek (cosZone), viết lại thành app học English.
- **Định hướng (Manh chốt):** (1) Dịch/tra từ là chính, OCR hỗ trợ; (2) TTS là tính
  năng chính để NGHE text thay vì đọc bằng mắt. Cả 2 chung 1 float icon:
  **HOVER → dịch; CLICK → nghe**.
- Repo: `TranManhTuanLabs/TransPeek`, branch `main`, public.
- Version hiện tại: **0.1.3** (stable). Pre-release tự động `v0.1.3.<run>`.
- Bản Windows riêng: `TranManhTuanLabs/TransPeek-Windows` (WinUI 3 + C#).

## 2. Stack

- **Swift 6, macOS 15.0+** (Apple Silicon + Intel), project Tuist.
- **Bundle ID:** `com.tranmanhtuanlabs.transpeek`. **URL scheme:** `transpeek`.
- **Updater:** Sparkle. **Ký CI:** cert tự ký 'TransPeek Self-Signed 100Years'.
- Build app bắt buộc **cài Xcode đầy đủ** — CLT không build được project Tuist.
- Ngôn ngữ UI gốc English; tiếng Việt thêm sau khi app hoàn thiện.

## 3. Quyết định lớn đã chốt (chi tiết: `SPEC-v0.1.md`)

- **Dịch:** Google Translate; flip target theo favorite của user (KHÔNG hardcode cặp ENG–VIE).
- **OCR:** mac Vision là chính (mặc định `["vi-VN", "en-US"]`); Tesseract M3 hoãn.
- **TTS:** M2 tách riêng (chưa làm); M4 ElevenLabs + VieNeu; TTS v1 chỉ EN + VI.
  KHÔNG dùng Edge TTS. RSVP: giữ cả 2 phương án (tab dãn / panel riêng), quyết ở lúc
  prototype; Model A là hướng thực tế, Model B KHÔNG làm.
- **Panel:** thiết kế chung mac + Windows chốt 16/11 (mở mặc định, min, cap output 260pt,
  auto-fit, snap-back ngang); **số mac chưa chốt → panel UX chưa viết**.
  Windows đã chốt riêng (mở mặc định 420, max rộng 600) — không áp sang mac.
- **Phát hành:** `release.yml` hướng B (tải đúng artifact của lần Tests xanh về đóng gói);
  Apple Developer $99/năm tạm hoãn; code notarize giữ làm dự phòng.
- **CI:** chỉ build app khi commit có `[build-app]`; docs-only không trigger CI;
  pre-release tự động, chỉ giữ mới nhất.

## 4. File quan trọng

- Spec: `docs/SPEC-v0.1.md`.
- CI: `.github/workflows/test.yml` (test + pre-release), `.github/workflows/release.yml`.
- Setup CI: `docs/TEST-BUILD-WORKFLOW-GITHUB/GIT-CI-BUILD-SETUP.md`, `docs/TEST-BUILD-WORKFLOW-GITHUB/BUILD-TEST-WORKFLOW-GITHUB-CI.md`.
- Panel UX (chưa viết): `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md`.

## 5. Người dùng

- **Manh**: nói tiếng Việt; không phải dân IT gốc, đang học, vibecode bằng AI.
  Muốn AI vừa làm vừa dạy dần, chỉnh từ kỹ thuật sai thành đúng ngay lúc nói.
  Quyết nhanh, muốn làm đầu-cuối, gộp 2–3 sửa vào 1 commit + 1 vòng test.
