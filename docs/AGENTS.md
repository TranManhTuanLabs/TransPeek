# AGENTS.md — TransPeek (mac)

> Quy tắc làm việc cho AI (Muse) trong repo này. Đọc trước khi làm việc.
> Bối cảnh tổng: `AI_CONTEXT.md`. Trạng thái hiện tại: `PROJECT_STATE.md`.
> Bản đồ docs: `STRUCTURE_MAP.md`.

## 1. Commit và đẩy code

- **Làm local hết tới cuối Phase/milestone lớn rồi mới đẩy lên GitHub MỘT đợt**,
  không đẩy lẻ từng file giữa chừng.
- **Đẩy các file liên quan GỘP 1 COMMIT**, không đẩy từng file qua web editor.
- **Commit chỉ sửa docs (`docs/**`, `*.md`) KHÔNG trigger CI** (do `paths-ignore`).
- **Local phải đồng bộ mới nhất theo main trước khi đẩy** — tránh dùng code cũ.
- Sau mỗi lần đẩy, **tự theo dõi run CI mới nhất tới khi kết luận**, rồi báo kết quả.

## 2. Theo dõi CI

- Xem trạng thái xanh/đỏ qua **API GitHub** (poll thưa 5–10 phút/lần, chỉ lúc run đang
  chạy, xong là dừng). **Đọc log CI qua API bị chặn (403) — dùng thẳng trình duyệt.**
- Khi CI bị huỷ do push mới đè lên (concurrency cancel) thì **không cần báo**;
  chỉ báo CI xanh (kèm link tải) hoặc CI đỏ thật.
- **CI đang chờ/chưa chạy thì đừng chờ xong mới đẩy (Manh 23:56):** sửa code xong
  đẩy luôn cho gộp vào run mới nhất — đằng nào cũng mất công chờ, cứ để CI chạy
  là test luôn code mới nhất. Run cũ bị push mới đè lên mà huỷ là bình thường,
  không cần báo.
- **Báo nhanh khi run kết luận**, đừng để Manh phải hỏi "sao build lâu thế".
- Đỏ do tải dependency/GitHub API 502 thì retry, đừng sửa code theo.
- Main khóa qua PR phải xanh mới merge; test nhanh (lint + unit) mỗi push,
  build nặng/đóng gói/UI test chỉ ở main/tag release/chạy tay.

## 3. Sửa UI — khung trước, sửa sau

- **Trước khi sửa UI: lên khung layout trước, Manh duyệt khung, rồi mới sửa dần theo khung.**
  Không đẩy bản mò từng lỗi vặt bắt Manh test từng bản.
- **Bài học từ Windows (chuỗi #150→#159, bug che loa):** nâng min output card
  150→160→170→180→210→218 mà không tìm nguyên nhân gốc — không lần nào hết.
  Đừng lặp lại: **điều tra nguyên nhân trước (cần bằng chứng: ảnh/video đo được),
  rồi mới sửa.**
- Panel UX mac chưa chốt size → chưa có spec chốt; khi chốt thì viết doc đầy đủ
  như bản Windows rồi mới sửa theo doc.
- **Native trước, tự chế sau:** tính năng nào control native không có thì **báo Manh
  1 câu trước** rồi mới làm custom.

## 4. Tra tên API / enum

- **Mở thẳng tài liệu chính chủ Apple Developer TRƯỚC khi viết code.**
  Không dùng tên nhớ từ framework khác, không tin trang thứ ba.

## 5. Quy tắc chung

- **Ngắn, hiểu rõ thì làm luôn; dài, chưa rõ, việc nhiều thì hỏi lại** (Manh 18/11/2026, áp dụng mọi repo): (1) trình khung cho anh duyệt trước khi làm; (2) xong rồi thì tóm tắt những gì đã làm.
- **Tính năng mới viết riêng module** — xem quyết định kiến trúc
  `ARCHITECTURE.md` §5.1 (Manh 17/11/2026): `FastRead/`, `BreakTimer/`,
  `Shortcuts/` (1 view dùng chung), khung tab mỏng, chỉ nối mỏng vào code
  chung. Không nhét tính năng mới vào file panel dịch.
- **KHÔNG hardcode** — mọi thứ không nên fix cứng trừ khi thật sự cần; phải có tính
  mở rộng hoặc tự nhận diện (vd flip target theo favorite của user, không fix cặp ENG–VIE).
- GitHub App/connector **không sửa được `.github/workflows/*` (403)**, không xoá được
  file, không tạo được release. Workflow sửa từ Mac rồi push, hoặc qua trình duyệt
  khi Manh cho quyền.
- GitHub web: mặc định giả vờ như **chưa đăng nhập**; chỉ khi Manh nói rõ cho quyền
  thì mới đăng nhập web và thao tác.
- **Khi ghi việc nợ phiên, ghi rõ session/chat nào và repo nào** (vd "mac — TransPeek"),
  tránh chat khác áp nhầm sang repo sai.
- Manh viết sai chính tả thì **tự correct cho đúng** khi đưa vào app; để ý cả chữ
  hoa/thường. NGOẠI LỆ: slogan "Translate anywhere, Peek instantly!" — chỉ hoa T và P.
- Manh dùng từ kỹ thuật / tiếng Anh sai thì **báo hoặc sửa cho đúng ngay lúc đó**.
- Quyết định sản phẩm phải hỏi Manh trước, trừ khi anh liệt kê phương án và bảo Muse chọn.
- Mỗi lần cải tiến workflow thì **tự ghi nhớ** (vào `docs/TEST-BUILD-WORKFLOW-GITHUB/GIT-CI-BUILD-SETUP.md` và
  `docs/TEST-BUILD-WORKFLOW-GITHUB/BUILD-TEST-WORKFLOW-GITHUB-CI.md`), đừng để Manh nhắc lại.

## 6. Về Manh

- Manh **không phải dân IT gốc, đang học, làm theo kiểu vibecode**. Giải thích bằng
  tiếng Việt đơn giản, ví dụ từ chính dự án, không dạy dồn dập. Vừa làm vừa dạy dần.
- Trả lời bằng tiếng Việt, ngắn, trực tiếp, cụ thể. Lần đầu nhắc thuật ngữ thì viết đủ,
  giữ nguyên từ kỹ thuật tiếng Anh (hash, certificate, ...), không dịch gượng.
