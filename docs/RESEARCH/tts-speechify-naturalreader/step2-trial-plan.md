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

### Speechify — màu thật, đã tìm được trong source extension (2026-11-27)

Đã tìm được trong source extension Speechify (anh gửi): highlight
đọc-theo-giọng dùng CSS Highlight API (`::highlight()`), màu nằm
trong theme token, không nằm trong CSS. Theme mặc định là **purple**,
theo trang sáng/tối (page-based). Trên trang sáng:

| Tầng | Nền | Chữ | Ghi chú |
|---|---|---|---|
| Từ đang đọc | Chàm đậm `#5666F0` (`highlight50`) | Chữ sáng | Nền đặc (opacity 1.0) |
| Câu đang đọc | Tím oải hương rất nhạt `#E0E3FF` (`highlight20`) | Chữ đen | Nền đặc (opacity 1.0) |

**Cơ chế highlight của Speechify (từ source thật):** tô thẳng vào
chữ bằng CSS Highlight API nên không có hình chữ nhật, không có
"cạnh" — đó là lý do highlight Speechify không có border. Speechify
đổi luôn màu chữ (trắng trên nền từ đậm) nên nền đặc vẫn đọc được.
TransPeek (app macOS, ở NGOÀI trang) không sửa được DOM/chữ nên chỉ
vẽ overlay được: nền đặc sẽ che mất chữ đen bên dưới, vì vậy overlay
phải giữ fill MỜ (0.30) và dùng màu của Speechify ở dạng mờ — xem
mục "Màu mặc định hiện tại" bên dưới.

**Màu thử cho TransPeek (Manh chốt 2026-11-24 00:38 — bảng màu pastel, thay cho đề xuất theo NaturalReader):**

| Thành phần | Màu thử | Lý do |
|---|---|---|
| Từ đang đọc | **Tím nhạt** (mờ) — NẾU LÀM ĐƯỢC | Manh chọn. Chỉ làm được nếu lấy được vị trí từng từ (qua AXBoundsForRange với range của từ) — chưa chắc app nào cũng đưa; nếu không lấy được thì bỏ tầng từ, còn câu + đoạn + gạch. |
| Câu đang đọc | **Vàng nhạt** (mờ) | Muse chọn để hợp với tím nhạt: vàng là màu bổ sung (complementary) của tím nên từ tím nổi rõ bên trong câu vàng; vàng cũng là màu highlight câu chuẩn (NaturalReader). |
| Đoạn đang đọc | **Green nhạt** (mờ) | Manh chọn. Tách biệt với vàng của câu. |
| Gạch dọc sợi chỉ | **Blue nhạt** (đặc) | Manh chọn. Gạch là vạch đặc nên dùng blue nhạt vẫn nhìn rõ, khác với 2 lớp tô mờ. |

**Màu mặc định hiện tại (đổi 2026-11-27, Manh duyệt):** từ + câu nay
theo **Speechify** thay cho bảng pastel trên — từ `#5666F0` (chàm,
`highlight50`), câu `#ABB3FE` (tím nhạt, `highlight30`), fill mờ
0.30. KHÔNG dùng `#E0E3FF` (màu câu thật của Speechify) vì ở fill
0.30 thì nhạt quá gần như không thấy; `#ABB3FE` là bước tiếp theo
trong bảng màu của Speechify. Đoạn (green nhạt `#BFF2B3`), gạch
(blue nhạt `#8CBFFF`), cụm (hồng nhạt `#FFC2D1`) giữ nguyên bảng
pastel cũ — Speechify không có 3 lớp này. Chi tiết xem
`docs/UI/UX_DESIGN/HIGHLIGHT_COLORS_UX_SPEC.md` §3.

Lưu ý: TransPeek thử 4 tầng (gạch + từ + câu + đoạn) còn Speechify/NaturalReader
chỉ có 2 tầng (câu + từ) — vì TransPeek không lấy được vị trí từng từ một cách
chắc chắn nên tầng "từ" là có điều kiện (nếu làm được); tầng "đoạn" là tầng
rộng hơn câu để thay thế khi không có tầng từ. Nếu lúc thử thấy các màu nhạt
khó phân biệt trên nền trang sáng/tối thì đổi màu và ghi lại ở mục cuối.

**Lưu ý thêm (từ source thật):** màu câu mặc định của NaturalReader là
xanh lá nhạt `#B5C687` — cùng tông với màu ĐOẠN (green nhạt) mà Manh chọn
cho TransPeek. Tức là nếu học sát NaturalReader thì câu = xanh lá nhạt,
đoạn phải chọn màu khác. Bảng màu pastel của Manh vẫn giữ nguyên trừ khi
anh muốn đổi theo NaturalReader.

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
  hình ảnh lag rồi nhảy từng bước lúc cuộn nhanh.
- **Trạng thái 2026-11-27: ĐÃ LÀM** — dự phòng này đã triển khai (xem
  §7): có toggle "Hide highlights while scrolling" trong Settings →
  Audio → "Highlight colors", mặc định BẬT; ý tưởng "tăng tốc poll"
  không dùng (ẩn khi cuộn thay vì poll nhanh hơn).

## 5. Pha test (tách 2 pha)

**Pha 1 — hiển thị** (làm trước, test trước):
- Gạch dọc + highlight câu + highlight đoạn có hiện đúng chỗ không?
- Có chặn chuột không? (bấm xuyên qua được không?)
- Phân biệt được câu vs đoạn bằng màu không? (thấy màu câu = lấy được
  khung câu; chỉ thấy màu đoạn = đã rơi về highlight cả đoạn.)
- Nếu highlight câu không ra ở app nào đó thì vẫn còn gạch + highlight
  đoạn (không trắng tay).

**Pha 2 — cuộn + dự phòng** (chỉ làm khi pha 1 xong và thấy giật):
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
- Màu vàng + xanh nhạt có phân biệt được trên cả nền sáng và nền tối
  không?

## 7. Ghi chú điều chỉnh theo thực tế

_(Điền sau khi thử trên máy thật — kết quả từng app, màu/độ mờ cuối cùng,
tốc độ poll cuối cùng, có dùng dự phòng ẩn/hiện không, lỗi gặp phải.)_

- **Độ lệch so với kế hoạch (ghi khi triển khai, 2026-11-24):**
  - §2.1 nói "Không dùng `speakContinuous`... bước 2 dùng `speak()`" —
    triển khai làm NGƯỢC LẠI: chaining dùng `speakContinuous` (vì cần
    `onWordRange` để theo dõi từ/câu cho highlight, và Bool trả về là
    tín hiệu nối tiếp). `speak()` không có word tracking nên không dùng
    được cho chaining. Quyết định này nằm trong brief triển khai.
  - Tên hàm update của overlay: brief gọi là
    `update(wordRange:sentenceRange:)` — triển khai nhận CGRect?
    (`update(wordFrame:sentenceFrame:)`) vì overlay vẽ frame, không
    vẽ range. Tên đổi cho rõ, hành vi giữ nguyên.
  - Vạch dọc: brief nói "ở mép trái frame của block" — triển khai cho
    cửa sổ overlay rộng hơn block 8pt về bên trái, vạch nằm trong dải
    8pt đó (bên CẠNH chữ, không che ký tự đầu dòng).
  - Màu cuối cùng sau test: (chưa test — điền sau khi thử trên máy thật).
  - **Ẩn highlight khi cuộn — phase 2 (§4) ĐÃ LÀM (2026-11-27):** trước
    đây chỉ làm "nếu test thấy giật"; nay đã triển khai luôn vì đã thấy
    cần: follow poll so sánh frame block giữa các lần poll (lệch > 1pt
    = đang cuộn → ẩn các fill + vạch dọc, cửa sổ vẫn bám theo để lúc
    hiện lại đã đúng chỗ; đứng yên 2 poll liên tiếp ~0,6s → hiện lại).
    Có toggle trong Settings → Audio → "Highlight colors": "Hide
    highlights while scrolling" (key
    `transpeek_highlightHideWhileScrolling`, mặc định BẬT). Không thêm
    lần đọc AX nào (dùng frame đã đọc sẵn ở poll). Ý tưởng "tăng tốc
    poll để bám sát" (§4) KHÔNG dùng — ẩn khi cuộn thay vì poll nhanh
    hơn (poll nhanh chỉ tốn thêm lần đọc AX mà vẫn lag khi cuộn nhanh).
  - **Overlay có thêm lớp Cluster + picker Line follows (2026-11-27):**
    lớp thứ 5 Cluster — highlight cho đoạn văn (cụm câu) chứa câu đang
    đọc, màu hồng nhạt `#FFC2D1`, mặc định bật; block fill mặc định
    TẮT trên nhánh (cụm là fill rộng thay cho block). Vạch dọc có
    picker "Line follows" (Sentence / Paragraph / Block, mặc định
    Paragraph); fallback vạch: đơn vị chọn → câu → cụm, KHÔNG về
    block; không có frame nào thì không vẽ vạch. Chi tiết trong
    `docs/UI/UX_DESIGN/HIGHLIGHT_COLORS_UX_SPEC.md` (mặc định cuối
    trên nhánh: line shown, line follows Paragraph, block hidden,
    sentence + word + cluster shown).
  - **Màu mặc định từ/câu theo Speechify (2026-11-27, Manh duyệt):**
    từ `#5666F0` (chàm, `highlight50`), câu `#ABB3FE` (tím nhạt,
    `highlight30`), fill mờ 0.30 — thay cho tím nhạt `#D9BFFA` /
    vàng nhạt `#FFF2A6` của bảng pastel chốt 2026-11-24. Đoạn, gạch,
    cụm giữ màu pastel cũ. Không dùng `#E0E3FF` (màu câu thật của
    Speechify) vì ở fill 0.30 thì nhạt quá; Speechify tô đặc (1.0)
    và đổi màu chữ nên mới dùng được nền đặc — overlay không đổi
    được màu chữ nên giữ fill mờ. Chi tiết §3.
  - **Gạch chân thử trên nhánh + vạch dọc mỏng đi (2026-11-27):**
    thêm toggle \"Show underline\" (key
    `transpeek_highlightUnderlineShown`, mặc định TẮT, chỉ trên
    nhánh): vẽ gạch chân đặc 2.5pt dưới từ + câu đang đọc, mỗi cái
    màu của lớp đó, độc lập với công tắc Show của lớp (tắt hết fill
    mà bật gạch chân thì vẫn thấy gạch chân — để so sánh 2 kiểu).
    Lý do: fill hình chữ nhật có cạnh cứng trông như border (xem
    giới hạn kỹ thuật trong UX spec §7); gạch chân tránh hẳn hình
    chữ nhật. Vạch dọc mỏng đi 1/2 (3.5 → 1.75pt, Manh thấy hơi
    to); dải 8pt bên trái giữ nguyên.
  - **Giới hạn kỹ thuật (ghi trong UX spec §7, 2026-11-27):**
    overlay vẽ hình chữ nhật đè lên trang nên highlight luôn có
    cạnh cứng (không phải bug); không đổi được màu chữ của trang
    (nên không dùng nền đặc 1.0 như Speechify); không tô theo hình
    chữ (chỉ có khung AX); frame từ/câu/cụm phụ thuộc app có cho
    lấy `AXBoundsForRange` không.
- ...

## Liên kết

- Spec icon float + quyết định bước 1/2/3:
  `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` (§8).
- Tính năng icon float: `docs/FEATURES/FLOAT_ICON.md`.
- Báo cáo nghiên cứu TTS/Speechify/NaturalReader (ngưỡng, dấu phẩy §6.5):
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`.
- Tính năng đọc Fast Read (RSVP/Lite): `docs/FEATURES/FAST_READ.md`.
- Chỉ mục research: `docs/RESEARCH/README.md`.
