# Kế hoạch thử nghiệm bước 2 — đọc nối tiếp + chỉ báo trên trang

> Kế hoạch làm lần thử này (chốt 2026-11-24). Tài liệu sống: sau khi thử trên máy
> thật thì chỉnh sửa theo thực tế — ghi kết quả thử + điều chỉnh vào mục
> "Ghi chú điều chỉnh theo thực tế" ở cuối, đừng viết doc mới.

- **Nhánh:** `feature/continuous-reading` (tạo nhánh sau khi Manh duyệt khung;
  thông báo tên nhánh + mục đích trước khi tạo, theo chuẩn nhánh).
- **Trạng thái:** khung đã duyệt (Manh 2026-11-24 00:17); code để phiên tới.
- **Mục đích:** bấm Speak 1 lần thì đọc hết bài báo ngay trên trang (không đưa
  vào trình đọc), và người dùng luôn biết đang đọc tới đoạn/câu nào — bằng
  gạch dọc + highlight overlay ngay trên trang/app đang đọc.

## 1. Phạm vi đợt thử này

### Làm

1. **Bước 2 — "đọc nối tiếp" (chaining).** Bấm icon Speak 1 lần: đọc xong
   1 đoạn thì tự tìm đoạn tiếp theo đọc tiếp, tới hết bài hoặc tới khi người
   dùng bấm dừng. Nghe ở lại trên trang, không trích xuất vào trình đọc.
2. **Gạch dọc sợi chỉ** trước đoạn (block) đang đọc — chỉ báo đang đọc khu
   vực đó.
3. **Highlight câu + highlight đoạn (overlay)** — thử nghiệm: tô câu đang
   đọc 1 màu riêng, tô đoạn đang đọc 1 màu riêng, để phân biệt được câu vs
   đoạn khi test. Thêm tầng **từ (tím nhạt) nếu lấy được vị trí từ**.
4. **5 món lẻ gộp** đi theo (đã chờ từ trước, cùng nhánh): (a) vuốt ngang
   Style 2 nhanh hơn (1 dòng/100pt → ~50pt/dòng); (b) căn "Read in:" theo
   "Run FastRead in:" (cả 2 mục `.frame(maxWidth: .infinity,
   alignment: .leading)`); (c) mở swipe ngang ở cửa sổ Nghỉ (gỡ `break`
   ở `RestWindowController`); (d) 2 chú thích cũ trong `RSVPView.swift`
   (ProGate + `ttsCoordinator`); (e) Enter→Done ở cả 2 màn đếm ngược
   (`.keyboardShortcut(.defaultAction)` cho nút Done ở màn cafe + cửa sổ
   Nghỉ).

### KHÔNG làm đợt này

- **Highlight trình đọc (RSVP/Lite, từ + câu)** — Manh chốt 2026-11-24 00:04,
  đảo lại quyết định 2026-11-23 16:47. Component TTS sync-word + sửa dấu
  phẩy (§6.5 báo cáo) đi theo phần highlight này, để sau.
- **Cuộn theo trang kiểu Speechify** (tự cuộn trang để đoạn đang đọc luôn
  hiện) — để sau, thử nghiệm riêng.
- **Trích xuất bài web vào trình đọc** — Manh chốt không làm (2026-11-23
  16:55): đọc xong lại phải xoá bản copy, mất độ liền mạch. Bước 3 là
  trình đọc FILE local (PDF, Word, Markdown...), riêng.
- **Model B** (quét cả cây / icon trên mọi block) — không làm.

## 2. Cơ chế từng phần (đã đối chiếu code thật)

### 2.1 Đọc nối tiếp

- Móc vào đường Speak hiện có: `triggerIconController.onSpeakRequested`
  → `ttsCoordinator.speak(text, language:)` (AppDelegate ~dòng 730).
  `speak()` đọc xong 1 đoạn thì tự gọi `onPlaybackEnded`
  (AppDelegate ~dòng 759: hiện tại chỉ gọi
  `triggerIconController.speakingDidStop()` để tắt trạng thái "đang nói"
  của icon) — đó là tín hiệu để tìm đoạn tiếp theo.
- Tìm đoạn tiếp theo: hit-test 1 điểm ngay dưới khung đoạn vừa đọc (giữa
  khung theo chiều ngang), dùng lại Model A (1 điểm, ≤ 5 tầng, không quét
  cây). Tìm được đoạn khác thì đọc tiếp; không tìm được thì dừng.
- Dừng: bấm icon lúc đang đọc nối tiếp thì **dừng hết** (đúng luật loa:
  click = nói, click lại = dừng; `onStopSpeakRequested` → `stop()`).
  `stop()` huỷ task nên `onPlaybackEnded` không bắn sau khi dừng — không
  sợ đọc tiếp sau khi đã dừng.
- Không dùng `speakContinuous` (đó là đường read-along của RSVP, cố ý
  không chạm `onPlaybackEnded`); bước 2 dùng `speak()` (đọc cả đoạn).

### 2.2 Gạch dọc sợi chỉ

- 1 cửa sổ overlay trong suốt (borderless, không nhận chuột
  `ignoresMouseEvents = true` để bấm xuyên qua, không cướp focus) đè lên
  trên app khác, vẽ 1 gạch dọc đặc ở mép trái khung đoạn đang đọc.
- Chỉ cần **khung của cả đoạn** — đã có sẵn (`HoverBlock.frame`, đọc lại
  qua `HoverBlockText.frame(of: element)`).
- Bám theo đoạn khi cuộn: poll đọc lại khung (xem §4). Đoạn cuộn khỏi màn
  hình thì ẩn gạch.

### 2.3 Highlight câu + highlight đoạn (overlay, thử nghiệm)

- Cùng 1 cửa sổ overlay như gạch dọc, vẽ thêm 2 lớp tô mờ:
  **câu đang đọc** 1 màu, **đoạn đang đọc** 1 màu (màu xem §3), và thêm
  tầng **từ đang đọc (tím nhạt) nếu lấy được vị trí từ**.
- Khung câu: thử lấy qua `kAXBoundsForRangeParameterizedAttribute`
  (AXBoundsForRange) với range ký tự của câu đang đọc — app chưa từng
  dùng API này, chưa biết app nào hỗ trợ. **Nếu app không trả khung câu
  thì rơi về chỉ tô cả đoạn** (vẫn còn gạch dọc + highlight đoạn).
- Khung đoạn: có sẵn như §2.2.
- Tô mờ (translucent) chứ không tô đặc — vì vẽ đè lên chữ của app khác,
  tô đặc sẽ che chữ. Độ mờ chỉnh trong lúc thử (bắt đầu khoảng 25–35%,
  tăng dần nếu khó thấy, giảm nếu che chữ).

## 3. Màu sắc — học theo Speechify / NaturalReader

Manh chốt (2026-11-24 00:26): màu câu + đoạn xem Speechify, NaturalReader
dùng màu gì thì học theo. Đã tra từ **source extension thật** (anh gửi,
trong `src/`) — đây mới là đáp án đúng, thay cho tra web trước đó:

### NaturalReader — màu thật trong source extension

File `src/naturalreader/injected/nr-ext-dom/nr-ext-dom.css` (đọc trực tiếp
từ source extension anh gửi). NaturalReader cho chọn 4 theme (Light /
Dark / Ice / Warm), mỗi theme có 2 tầng: câu + từ. Theme mặc định là
**Light**:

| Theme | Câu đang đọc | Từ đang đọc |
|---|---|---|
| **Light** (mặc định) | Nền xanh lá nhạt `#B5C687`, chữ xanh dương đậm `#0d3b55` | Nền xanh dương đậm `#0d3b55`, chữ sáng `#E7ECEE` |
| Dark | Nền xanh dương đậm `#0d3b55`, chữ sáng `#E7ECEE` | Nền vàng `#EFD369`, chữ `#393E3E` |
| Ice | Nền xám rất nhạt `#F1F3F4`, chữ `#373D3E` | Nền xanh teal `#0F7895`, chữ trắng `#FFFFFF` |
| Warm | Nền be ấm `#ebdcb2`, chữ `#605140` | Nền nâu đậm `#563e20`, chữ `#E6CCB5` |

**Cơ chế highlight của NaturalReader (từ source thật):** extension chạy
content script TRONG trang web, chèn tag vào DOM của trang (câu được bọc
bằng class `nr-s{N}`, rồi gắn class `nr-highlighted-sentence` /
`nr-highlighted-word` + `nr-sentence-highlight-{theme}` /
`nr-word-highlight-{theme}`), và tự cuộn tới câu đang đọc
(`scrollIntoView`). Tức là highlight trên trang được vì extension ở TRONG
trang và sửa được DOM — đúng như nhận định overlay: TransPeek (app macOS,
ở NGOÀI trang) không sửa được DOM nên chỉ vẽ overlay được. Source
extension xác nhận cơ chế này.

### Speechify — màu chính xác ĐÃ tìm được trong source extension (2026-11-27)

Đã tìm trong source extension Speechify (anh gửi): màu highlight đọc-theo-giọng không nằm trong CSS mà nằm trong JS (theme token `highlightColor`: từ dùng `hglt-prim`, câu dùng `hglt-sec`). Mặc định (theme tím, trang sáng): **từ `#5666f0`** (highlight50, chàm đậm — chữ trắng) và **câu `#e0e3ff`** (highlight20, tím oải hương rất nhạt — chữ đen). Nền ĐẶC (opacity 1.0), tô thẳng vào chữ bằng CSS Highlight API (`::highlight()`), nên không có hình chữ nhật. Bảng gốc còn có `highlight30 #abb3fe` (tím nhạt) và `highlight40 #444766` (chàm tối, cho trang tối).

**Áp dụng cho TransPeek (Manh 2026-11-27 03:41):** màu mặc định từ/câu nay theo Speechify — từ `#5666F0`, câu `#ABB3FE` (dùng highlight30 thay `#e0e3ff` vì ở fill mờ 0.30 thì `#e0e3ff` nhạt quá gần như không thấy). Overlay của TransPeek vẽ đè lên trang, không đổi được màu chữ, nên KHÔNG copy opacity 1.0 của Speechify — fill vẫn mờ 0.30 để chữ đen đọc được. Đoạn (`#BFF2B3`), cụm (`#FFC2D1`), vạch (`#8CBFFF`) giữ bảng pastel cũ (Speechify không có 3 lớp này). Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §3.

**Màu thử cho TransPeek (Manh chốt 2026-11-24 00:38 — bảng màu pastel, thay cho đề xuất theo NaturalReader):**

| Thành phần | Màu thử | Lý do |
|---|---|---|
| Từ đang đọc | **Tím nhạt** (mờ) — NẾU LÀM ĐƯỢC | Manh chọn. Chỉ làm được nếu lấy được vị trí từng từ (qua AXBoundsForRange với range của từ) — chưa chắc app nào cũng đưa; nếu không lấy được thì bỏ tầng từ, còn câu + đoạn + gạch. |
| Câu đang đọc | **Vàng nhạt** (mờ) | Muse chọn để hợp với tím nhạt: vàng là màu bổ sung (complementary) của tím nên từ tím nổi rõ bên trong câu vàng; vàng cũng là màu highlight câu chuẩn (NaturalReader). |
| Đoạn đang đọc | **Green nhạt** (mờ) | Manh chọn. Tách biệt với vàng của câu. |
| Gạch dọc sợi chỉ | **Blue nhạt** (đặc) | Manh chọn. Gạch là vạch đặc nên dùng blue nhạt vẫn nhìn rõ, khác với 2 lớp tô mờ. |

Lưu ý: TransPeek thử 4 tầng (gạch + từ + câu + đoạn) còn Speechify/NaturalReader
chỉ có 2 tầng (câu + từ) — vì TransPeek không lấy được vị trí từng từ một cách
chắc chắn nên tầng "từ" là có điều kiện (nếu làm được); tầng "đoạn" là tầng
rộng hơn câu để thay thế khi không có tầng từ. Nếu lúc thử thấy các màu nhạt
khó phân biệt trên nền trang sáng/tối thì đổi màu và ghi lại ở mục cuối.

**Lưu ý thêm (từ source thật):** màu câu mặc định của NaturalReader là
xanh lá nhạt `#B5C687` — cùng tông với màu ĐOẠN (green nhạt) mà Manh chọn
cho TransPeek. Tức là nếu học sát NaturalReader thì câu = xanh lá nhạt,
đoạn phải chọn màu khác. Bảng màu pastel của Manh vẫn giữ nguyên cho đoạn/vạch/cụm; riêng từ + câu đã đổi sang màu Speechify từ 2026-11-27 (xem mục trên) — bảng trên là bảng gốc 2026-11-24, chỉ còn đúng cho đoạn/vạch/cụm.

## 4. Theo dõi khi cuộn + dự phòng chống giật

- Cơ chế có sẵn: follow poll hiện tại 0.3 s (`followIntervalSec`,
  `HoverTextDetector.swift` ~dòng 264) — mỗi lần poll đọc lại khung của
  element qua `HoverBlockText.frame(of:)`. Hiện tại khung lệch > 10 pt
  thì icon bị coi là stale và ẩn đi.
- Cho chỉ báo đang đọc thì đổi hành vi: lúc đang nói, poll **dời gạch
  dọc/highlight theo khung mới** thay vì ẩn.
- Độ "sát" phụ thuộc tốc độ poll: 0.3 s = cập nhật ~3 lần/giây; lúc cuộn
  nhanh sẽ lag rồi bắt kịp từng bước, không mượt như dính liền. Thử poll
  nhanh hơn lúc đang nói (vd 0.1 s) để bám sát hơn — nhưng AX lúc cuộn
  nhanh có thể trả chậm (app đích bận vẽ), nên đây là phần phải test trên
  máy thật.
- **Dự phòng khi bị giật (Manh 2026-11-24 00:13):** nếu thử mà gạch
  dọc/highlight bị giật / không theo kịp thì chuyển sang: **lúc đang cuộn
  thì ẨN đi, khi cuộn dừng thì HIỆN LẠI** ở vị trí mới. Nhận biết: khung
  còn đổi giữa các lần poll tức đang cuộn (ẩn); khung đứng yên qua 1–2
  lần poll (khoảng 0.3–0.6 s) tức đã dừng (hiện lại ở khung mới). Tránh
  hình ảnh lag rồi nhảy từng bước lúc cuộn nhanh. **(ĐÃ LÀM 2026-11-27 —
  xem §7.)**

## 5. Pha test (tách 2 pha)

**Pha 1 — hiển thị** (làm trước, test trước):
- Gạch dọc + highlight câu + highlight đoạn có hiện đúng chỗ không?
- Có chặn chuột không? (bấm xuyên qua được không?)
- Phân biệt được câu vs đoạn bằng màu không? (thấy màu câu = lấy được
  khung câu; chỉ thấy màu đoạn = đã rơi về highlight cả đoạn.)
- Nếu highlight câu không ra ở app nào đó thì vẫn còn gạch + highlight
  đoạn (không trắng tay).

**Pha 2 — cuộn + dự phòng** (chỉ làm khi pha 1 xong và thấy giật — ĐÃ LÀM 2026-11-27, xem §7):
- Cuộn nhanh: gạch/highlight có bám theo không, có giật không?
- Nếu giật: bật dự phòng ẩn lúc cuộn / hiện lại khi dừng, test lại.

Test trên trang báo đơn giản trước (Safari/Chrome), rồi mới thử app khác
(Word...). Ghi kết quả từng app vào mục cuối.

## 6. Câu hỏi mở — cần kiểm chứng trên máy thật

- `AXBoundsForRange` có trả khung câu không — Safari? Chrome? Word?
  App nào có, app nào không?
- Poll nhanh lúc đang nói (0.1 s) có bám sát không? AX lúc cuộn nhanh
  có trả chậm không?
- Overlay có chặn chuột không? (phải `ignoresMouseEvents`.)
- Đoạn cuộn khỏi màn hình thì ẩn đúng không?
- Độ mờ 25–35% có đọc được chữ bên dưới không, hay phải chỉnh?
- Màu chàm (từ) + tím nhạt (câu) + xanh nhạt (đoạn) có phân biệt được
  trên cả nền sáng và nền tối không?

## 7. Ghi chú điều chỉnh theo thực tế

- **2026-11-27 — dự phòng chống giật (phase 2) ĐÃ LÀM:** test thấy cuộn bị giật nên đã triển khai ẩn highlight lúc cuộn / hiện lại khi dừng, đúng như §4 dự phòng: follow poll 0,3 s so sánh khung block với poll trước, khung đổi → ẩn các fill + vạch dọc (cửa sổ vẫn bám theo để lúc hiện lại đã đúng chỗ), khung đứng yên 2 poll liên tiếp (~0,6 s) → hiện lại. Có toggle "Hide highlights while scrolling" trong Settings → Audio → Highlight colors, **mặc định BẬT**; tắt thì về hành vi follow-only cũ (có thể giật). Không thêm lần đọc AX nào (dùng khung poll đã đọc sẵn). Xem `docs/UI/UX_DESIGN/HIGHLIGHT_COLORS_UX_SPEC.md` §7.
- **2026-11-27 — màu mặc định từ/câu đổi sang Speechify:** màu Speechify đã tìm được trong source extension (từ `#5666f0`, câu `#e0e3ff`, nền đặc, tô thẳng vào chữ). Mặc định TransPeek nay: từ `#5666F0`, câu `#ABB3FE` (dùng highlight30 thay `#e0e3ff` vì ở fill 0.30 thì `#e0e3ff` nhạt quá); fill vẫn mờ 0.30 vì overlay vẽ đè lên trang, không đổi được màu chữ như Speechify. Đoạn `#BFF2B3`, cụm `#FFC2D1`, vạch `#8CBFFF` giữ nguyên. Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §3.
- **2026-11-27 — vạch dọc mỏng đi 1/2 + giới hạn kỹ thuật ghi vào doc:** vạch dọc từ 3.5 pt → **1.75 pt** (Manh thấy 3.5 hơi to; dải 8 pt bên trái giữ nguyên, chỉ thanh vạch mỏng đi). Đồng thời ghi rõ giới hạn kỹ thuật của overlay vào `HIGHLIGHT_COLORS_UX_SPEC.md` §9: highlight luôn là hình chữ nhật có cạnh cứng (bản chất cách vẽ, không phải bug — màu nhạt chỉ làm cạnh mờ đi); overlay không đổi được màu chữ và không tô theo hình chữ như Speechify, nên fill phải giữ mờ 0.30; lớp nào app không cho lấy `AXBoundsForRange` thì không vẽ được.
- **2026-11-27 — overlay thêm lớp Paragraph (cụm) + picker Line follows:** ngoài 4 lớp cũ (vạch dọc, đoạn, câu, từ), overlay nay có thêm lớp highlight **Paragraph (cụm)** — nhóm câu gần nhau, tách nhau bằng ranh giới đoạn (xem bullet tách đoạn bên dưới), màu mặc định hồng nhạt `#FFC2D1` (mặc định trên main: TẮT; chỉ có highlight từ bật sẵn). Vạch dọc không còn dài cố định bằng cả block: picker "Line follows" trong hàng Vertical line cho chọn Sentence / Paragraph / Block (mặc định main: Sentence); fallback khi đơn vị chọn không có frame: đơn vị chọn → câu → cụm, không có frame nào thì không vẽ vạch (block chỉ là đơn vị được chọn, không phải fallback). Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §3/§6.
- **2026-11-27 — gạch chân thành lớp thứ 6, mặc định BẬT:** gạch chân (trước đây chỉ thử trên nhánh) nay là lớp riêng trên main: có màu riêng `#5666F0` (chàm, như màu từ) để chọn trong Settings, có công tắc Show riêng, mặc định **BẬT** (Manh thấy gạch chân đẹp hơn tô nền — không bị cạnh cứng hình chữ nhật). Vẫn vẽ dưới từ + câu đang đọc, nét 2.5 pt đặc, độc lập với công tắc Show của fill (tắt hết fill mà bật gạch chân thì vẫn thấy gạch chân). Thứ tự hàng trong Settings đổi thành: Underline, Vertical line, Word, Sentence, Paragraph, Block. "Reset all to default" nay reset cả 6 màu + 6 Show + Line follows (không reset toggle tự ẩn khi scroll). Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §2/§3/§5.
- **2026-11-27 — cụm không fallback về cả block:** block không có dòng trống (chỉ có 1 đoạn = cả block) thì **không vẽ fill cụm** — không có cụm để highlight (trước đây cụm = cả block, vẽ đè lên toàn bộ block). Muốn tô cả block thì bật lớp Block (đã có Show riêng); cụm chỉ tô khi nó là 1 PHẦN của block (có sự phân tách thật). Block có dòng trống thì cụm vẫn hiện bình thường (tô cụm chứa câu đang đọc). Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §3/§4.
- **2026-11-27 — tách đoạn theo cả 3 tín hiệu (không chỉ dòng trống):** ranh giới đoạn nay là khi khoảng trắng giữa 2 câu chứa ÍT NHẤT 1 lần ngắt dòng (1+ lần — trước đây chỉ tách khi 2+ lần, tức dòng trống), HOẶC câu tiếp theo bắt đầu bằng thụt đầu dòng (tab, hoặc 2+ khoảng trắng — 1 khoảng trắng chỉ là dấu phân cách giữa 2 câu). Lý do: bắt được đoạn trong sách/PDF, nơi các đoạn thường chỉ cách nhau bằng 1 lần xuống dòng hoặc thụt đầu dòng, không có dòng trống — cách tách cũ (chỉ dòng trống) hụt những đoạn này. Giữ nguyên quy ước CRLF tính là 1 lần ngắt (không tách nhầm). Đã kiểm chứng bằng mô phỏng 9 mẫu (dòng trống tách, 1 lần xuống dòng tách, tab thụt tách, 1 khoảng trắng không tách, CRLF tính 1 lần; CRLF dòng trống tách, 3 đoạn hỗn hợp tách thành 3, block chỉ có 1 khoảng trắng → 1 đoạn → cụm = nil). Xem `HIGHLIGHT_COLORS_UX_SPEC.md` §4.

_(Điền sau khi thử trên máy thật — kết quả từng app, màu/độ mờ cuối cùng,
tốc độ poll cuối cùng, có dùng dự phòng ẩn/hiện không, lỗi gặp phải.)_

- ...

## Liên kết

- Spec icon float + quyết định bước 1/2/3:
  `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` (§8).
- Tính năng icon float: `docs/FEATURES/FLOAT_ICON.md`.
- Báo cáo nghiên cứu TTS/Speechify/NaturalReader (ngưỡng, dấu phẩy §6.5):
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`.
- Tính năng đọc Fast Read (RSVP/Lite): `docs/FEATURES/FAST_READ.md`.
- Chỉ mục research: `docs/RESEARCH/README.md`.
