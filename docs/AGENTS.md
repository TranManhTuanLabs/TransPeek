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
- **Repo mac hay phải chờ máy — tranh thủ làm luôn (Manh 18/11):** khi CI đang
  chờ máy (queued) mà có yêu cầu mới thì làm ngay, đẩy gộp vào run đang chờ để
  CI chạy một thể rồi Manh test một lượt, đừng để máy chạy xong mới làm rồi lại
  chờ lượt mới. Ví dụ 18/11: trong lúc #230 chờ máy, làm luôn setting "Show
  context around focus word" + sửa nút chìm nền đen, đẩy gộp thành #231.
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
- **Native trước, tự chế sau:** khi cần 1 tính năng/control, **check native
  trước** — native có sẵn và hỗ trợ ngon (đủ dùng, đúng chuẩn hệ thống) thì dùng
  native; chỉ tự chế khi native **không có** hoặc **không hỗ trợ đủ tốt**. Tự chế
  thì **báo Manh 1 câu trước** rồi mới làm. Ví dụ: dropdown tìm kiếm 249 ngôn ngữ
  — SwiftUI có Popover + List + `.searchable` ráp lại được thì dùng native, không
  tự vẽ dropdown từ đầu.

## 4. Tra tên API / enum / mã code / cú pháp

- **Mở thẳng tài liệu chính chủ Apple Developer TRƯỚC khi viết code.**
  Không dùng tên nhớ từ framework khác, không tin trang thứ ba.
- **Tra mã code / cú pháp cũng lấy từ nguồn chính thống trước** — vd Google Cloud
  Translation docs cho mã ngôn ngữ, Apple Developer docs cho SwiftUI/AppKit.
  Không lấy từ kết quả tìm web nhanh hay trang thứ ba (Wikipedia, blog, list tổng
  hợp) làm đáp án — chỉ dùng để tham khảo hoặc cross-check sau khi đã có nguồn
  chính thống.

## 5. Chọn phương án triển khai — đọc mã nguồn thật trước

- **Trước khi làm gì, đọc mã nguồn THẬT của dự án rồi mới chọn phương án triển khai
  tốt nhất.** Phương án phải dựa trên code đang chạy trong repo (cách code hiện tại
  viết, control/API nào đang dùng, hành vi thật của nó), không dựa trên trí nhớ
  về "thường thì làm thế này".
- **Không phụ thuộc hoàn toàn vào trí nhớ.** Trí nhớ chỉ là gợi ý. **Tra lại nhanh
  cho chắc** (mở file code, mở tài liệu chính chủ) với mọi thứ sẽ đưa vào code;
  **tra kỹ khi cần** (logic phức tạp, tên API/enum, hành vi quyết định chọn phương án
  nào, thứ đã từng sai).
- **Đây là dạng tổng quát của §4 (tra tên API/mã/cú pháp):** tên API, mã code, cú pháp,
  hành vi control — tất cả đều phải đối chiếu nguồn thật trước khi dùng.
- **"Native trước, tự chế sau" là 1 phần của việc chọn phương án** (xem §3).
- Bài học (Windows CI #189, 19/11): chọn ComboBox editable + `TextChanged` để lọc
  live 249 ngôn ngữ — từ trí nhớ kiểu WPF, không tra WinUI trước. WinUI ComboBox
  KHÔNG có `TextChanged` (chỉ có `TextSubmitted` khi Enter/mất focus), build đỏ.
  Tra mã nguồn/API thật trước thì đã chọn AutoSuggestBox ngay từ đầu — control native
  sinh ra để gõ-tìm.

## 6. Quy tắc chung

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

## 7. Về Manh

- Manh **không phải dân IT gốc, đang học, làm theo kiểu vibecode**. Giải thích bằng
  tiếng Việt đơn giản, ví dụ từ chính dự án, không dạy dồn dập. Vừa làm vừa dạy dần.
- Trả lời bằng tiếng Việt, ngắn, trực tiếp, cụ thể. Lần đầu nhắc thuật ngữ thì viết đủ,
  giữ nguyên từ kỹ thuật tiếng Anh (hash, certificate, ...), không dịch gượng.

## 8. Doc mới phải được lập chỉ mục + liên kết, không để lẻ loi (Manh 21/11/2026)

- **Mỗi lần tạo doc mới, cập nhật ngay trong cùng đợt:** (1) thêm doc vào
  `docs/STRUCTURE_MAP.md` (bảng + cây docs + mục Liên kết), và vào
  `docs/UI_DESIGN.md` nếu là doc UX; (2) thêm mục liên kết ở cuối doc mới
  trỏ sang các doc liên quan; (3) thêm link ngược từ các doc liên quan
  trỏ về doc mới.
- **Không để doc lẻ loi, mất liên kết.** Trước khi gọi là xong, kiểm tra lại
  mọi link mới đều trỏ tới file có thật trong repo.
