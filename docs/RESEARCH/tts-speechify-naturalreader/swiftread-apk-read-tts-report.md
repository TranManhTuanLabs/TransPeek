# Báo cáo nghiên cứu: SwiftRead — Read mode + TTS word sync (APK Android)

> **Phạm vi:** App SwiftRead Speed Reading (package `com.swiftread.universal`) — cách Read mode + TTS hoạt động với word sync: tốc độ đọc/narration, chữ chạy theo giọng, highlight/sync từng từ, chia chunk/cụm, quan hệ giữa tốc độ giọng và WPM, hành vi play/pause/chuyển đoạn.
> **Ngôn ngữ báo cáo:** Tiếng Việt.
> **Ngày nghiên cứu:** 23/11/2026.
> **Cập nhật 24/11/2026:** Manh đã gửi file XAPK SwiftRead 1.10.3 qua Google Drive — đã phân tích binary, kết quả ở **§11**. Các mục §3.4, §4.2, §9 (mục 1–3, 5) đã được xác minh/sửa theo binary; những gì vẫn chưa rõ ghi rõ trong §11.9. Bổ sung cùng ngày ở **§12**: tokens/quota/tính phí, giá Azure AI Speech, list TTS tham khảo của Manh, verdict kết hợp native + SwiftRead, tham chiếu chéo giữa các báo cáo.
> **⚠️ Lưu ý phương pháp — đọc trước:** **File APK đã KHÔNG tải được.** APKPure chặn toàn bộ truy cập bằng Cloudflare Turnstile (curl trả 403; trình duyệt thử 9 vòng verify đều reset, không vào được trang app); APKMirror tìm không thấy app này; Uptodown không có listing (search "SwiftRead" trả về 0 kết quả, URL trực tiếp 404); apkcombo trả 404; thử link trực tiếp `d.apkpure.com` cũng bị chặn. Vì vậy **không có phân tích binary** (không đọc được manifest, `res/values`, dex strings) trong báo cáo này. Toàn bộ nội dung dưới đây dựa trên **tài liệu chính thức của SwiftRead** (Help Center, blog) và **metadata trên store** (Google Play qua AppBrain, App Store, APKPure) — đều là nguồn công khai, đã ghi rõ link ở §10. Những gì chỉ suy luận được (chưa có bằng chứng từ APK) được đánh dấu **[suy luận — chưa xác minh]** và gom ở §6 + §9. **Không sao chép code:** báo cáo chỉ mô tả *pattern* (mẫu thiết kế/hành vi) để re-implement, không trích code proprietary của SwiftRead.
> **Bối cảnh:** Đây là báo cáo thứ 4 trong loạt nghiên cứu TTS/read-along cho TransPeek/Seeless, cùng thư mục với các báo cáo Speechify, NaturalReader, RSVP (xem `speechify-report.md`, `naturalreader-report.md`, `rsvp-report.md`).

---

## 0. Tóm tắt nhanh (đọc 2 phút)

| Câu hỏi | Trả lời ngắn |
|---|---|
| SwiftRead có mấy chế độ đọc? | **3 chế độ, chuyển đổi bất cứ lúc nào:** **Focus** (RSVP — hiện vài từ tại một điểm cố định), **Flow** (giữ nguyên trang, highlight chạy qua text), **Spotlight** (ẩn/làm mờ text xung quanh, chỉ nổi bật cụm đang đọc). |
| TTS hoạt động ở chế độ nào? | **Cả 3 chế độ.** Bật bằng **Enable Narration** trong Text-to-Speech Settings (icon loa cạnh nút Play), chọn giọng trong Voice Library (90+ ngôn ngữ theo App Store). |
| Highlight/sync từng từ ra sao? | Ở Flow + TTS: **từng từ được highlight khi nó được đọc** ("each word is highlighted as it's spoken"), highlight màu xám chạy theo giọng; mắt dõi theo giọng. Ở Focus/Spotlight + TTS: text vẫn hiện trên màn hình theo nhịp giọng. |
| Tốc độ giọng có liên quan gì tới WPM không? | **Có — là MỘT con số duy nhất.** Help Center định nghĩa Reading speed là "how fast SwiftRead presents the words to you (either visually and/or via text-to-speech) in words per minute, or WPM" — tức cùng một giá trị WPM điều khiển cả nhịp hiển thị lẫn tốc độ giọng. Đổi tốc độ bằng icon speedometer cạnh Play, áp dụng ngay cả khi đang nghe. |
| Dải tốc độ đo được | **Tối thiểu 50 WPM** (bản cập nhật mới nhất nâng từ 10 WPM lên 50 WPM — user phàn nàn trên Play, muốn giữ 10 WPM); **tối đa 9x** (cùng bản cập nhật nâng từ 5x lên 9x, theo review user trên Play). Marketing ghi "up to 3X faster". Dải tối đa tính bằng WPM tuyệt đối **đã xác minh: 450 WPM** (binary §11.5); tốc độ tối thiểu 50 WPM vẫn theo review user (chưa đọc được trực tiếp từ binary build 1.10.3 — hằng số nằm trong bytecode Hermes v96, chưa có tool disassemble; 450 = 9 × 50 nên khớp với review). |
| Chia chunk/cụm thế nào? | Setting **"Words at a time" — 1 đến 6 từ** mỗi lần hiển thị (Focus). Số này xem được dưới icon speedometer. |
| Micro-pauses (ngắt nhịp)? | **Chỉ khi đọc bằng mắt (TTS tắt):** pause lâu hơn ở từ dài, số, dấu phẩy, dấu chấm, đoạn mới — chỉnh được trong Settings. **Khi bật TTS thì không chỉnh được:** giọng đọc theo ngữ điệu tự nhiên của con người ("the speech audio approximates a natural human speaking pattern"). |
| Play/pause/chuyển đoạn | Nút **Play/Pause**; phím tắt **Play/pause, Jump back, Jump forward, Speed up, Slow down, Toggle narration**; **double-click/double-tap icon loa** = bật/tắt narration không cần mở Settings. Muốn đổi setting phải **Pause trước** (icon loa biến mất khi đang phát). Bấm Play sau khi pause thì **đọc tiếp từ chỗ dừng**. |
| Audio từ đâu? | **Đã xác minh từ binary: cloud TTS — Microsoft Azure AI Speech (giọng neural, vd `en-US-AvaMultilingualNeural`)**, audio lấy qua signed URL (CloudFront bucket), kèm word timestamps (timepoints) theo từng part; **không dùng Android TextToSpeech on-device** (không có reference trong dex). Xem §11.3–11.4. |
| Giá / giới hạn | Free: mọi tính năng đều có, một số có **daily allowance** (TTS + premium pages). PRO: narration + premium pages không giới hạn. |

---

## 1. Tình trạng tải APK (bằng chứng)

| Nguồn | Kết quả ngày 23/11/2026 |
|---|---|
| APKPure — https://apkpure.com/swiftread-speed-reading/com.swiftread.universal | **Bị chặn.** Trang app và trang download đều qua được crawler text (lấy được mô tả + metadata), nhưng mọi lần tải file thật đều gặp Cloudflare Turnstile: curl → 403 "Just a moment..."; trình duyệt live thử 9 vòng verify (click checkbox, reload, đổi môi trường) đều "Verifying..." ~60 giây rồi reset về checkbox mới. Không tới được nút Download APK. |
| APKMirror | Tìm "SwiftRead", "SwiftRead Speed Reading", "com.swiftread.universal" (cả tab APKS và APPS) → **"No results found"**. App không có trên APKMirror. |
| Uptodown | Search "SwiftRead" → **0 kết quả** ("No hemos podido encontrar programas que coincidan con swiftread"); URL trực tiếp `swiftread-speed-reading.en.uptodown.com` → **404**. |
| apkcombo | URL download `/download/apk` → **404**. |
| Link trực tiếp `d.apkpure.com/b/APK/...` (đoán version code) | 403 / empty reply — Cloudflare chặn cả host này. |

**Metadata lấy được (không cần tải file):**

| Mục | Giá trị | Nguồn |
|---|---|---|
| Phiên bản mới nhất | **1.10.6** (Google Play / App Store, cập nhật 22/10/2026); APKPure đang ở **1.10.3** (chậm hơn 1 bản) | AppBrain, App Store, APKPure |
| Dung lượng file | **65,7 MB** (APKPure) / **66,76 MB** (AppBrain) / **75,2 MB** (App Store) | APKPure, AppBrain, App Store |
| Yêu cầu | Android 7.0+ | APKPure |
| Lượt cài / đánh giá | **7,1 nghìn lượt cài; 4,59★, 222 ratings** | AppBrain |
| Nhà phát triển | SwiftRead Technologies (App Store ghi Seller: S10G Technologies LLC) | Google Play / App Store |
| Có mặt từ | Google Play từ tháng 02/2026 | AppBrain |

**Cập nhật 24/11/2026:** Manh đã tải được file XAPK SwiftRead 1.10.3 từ APKPure trên trình duyệt thật và gửi qua Google Drive (file `SwiftRead_-_Speed_Reading_1.10.3_APKPure.xapk`, 68.879.539 bytes). Phân tích binary ở **§11** — các mục chưa xác minh ở §9 (mục 1–3, 5) nay đã có đáp án (một phần).

---

## 2. Ba chế độ đọc (Read mode)

Nguồn chính: blog SwiftRead "Read or listen to long articles at your own speed" (cập nhật 07/11/2026) + trang APKPure/App Store. Cả 3 chế độ dùng **chung một bộ điều khiển**: icon **speedometer (đồng hồ tốc độ) bên trái nút Play** mở panel Speed Reading (chọn mode + Reading Speed), đóng panel rồi bấm Play. Chuyển mode bất cứ lúc nào, không cần mở lại tài liệu.

### 2.1. Focus — RSVP (Rapid Serial Visual Presentation)

- Hiện **một vài từ tại một điểm cố định giữa màn hình** — text chạy tới mắt thay vì mắt chạy theo dòng. Đây là chế độ RSVP kinh điển.
- **Advanced:** chỉnh được **Focus Stage** (vùng hiển thị) và **Context Lines** (số dòng ngữ cảnh, khi có).
- Có **patent-pending "eye anchor"** (điểm neo mắt) theo mô tả App Store.
- Phù hợp: tăng tốc tối đa, đọc đoạn ngắn, khi muốn mắt không di chuyển.

### 2.2. Flow — highlight chạy trên toàn trang

- **Giữ nguyên toàn bộ bài trên màn hình**, một highlight di chuyển qua text theo đúng tốc độ đã đặt — vẫn thấy ngữ cảnh xung quanh.
- **Advanced:** chọn **Continuous** (cuộn liên tục) hoặc **Paginated** (lật trang).
- Đây là chế độ **duy nhất có mô tả word-by-word highlight tường minh khi bật TTS** (xem §3).
- Phù hợp: đọc hiểu, đọc theo giọng, tài liệu dài cần ngữ cảnh.

### 2.3. Spotlight — làm mờ xung quanh

- Text vẫn ở đúng vị trí, nhưng **phần xung quanh bị ẩn hoặc làm mờ**, chỉ cụm đang đọc nổi bật.
- **Advanced:** chỉnh **tốc độ mờ dần (fade) của các từ vừa đọc xong** + chọn Continuous/Paginated.
- Phù hợp: tập trung, đỡ xao nhãng, đọc buổi tối.

### 2.4. Tuỳ biến chung

Font, màu, khoảng cách (spacing), cỡ chữ đều chỉnh được. Nhập liệu: file **PDF và ePub từ máy (tối đa 25 MB)**, link web, text dán vào; sách mở trong **Kindle Cloud Reader và Libby** (qua Open > Supported sources); post/thread trên X bằng cách reply `@SwiftReadIt`. PDF scan thì chậm hơn vì phải OCR từng trang trước. Một tài khoản đồng bộ Library + tiến độ đọc trên Android, iOS, web app (`app.swiftread.com`) và extension Chrome/Edge.

---

## 3. TTS + word sync — cách narration hoạt động

Nguồn chính: Help Center "Enable audio narration" (cập nhật 07/11/2026), blog "Listen to your PDFs" và "Read or listen to long articles".

### 3.1. Bật narration (luồng thao tác)

1. **Pause** reader nếu đang phát (bắt buộc — icon loa không hiện khi đang phát).
2. Bấm **icon loa (audio icon) cạnh nút Play** → mở **Text-to-Speech Settings**.
3. Bật **Enable Narration**, chọn giọng ở **Current voice → Voice Library**.
4. Đóng settings, bấm **Play** → bài được đọc to, text vẫn hiện trên màn hình.
5. **Shortcut:** double-click (desktop) / double-tap (mobile) icon loa = bật/tắt narration ngay, không cần mở settings.

### 3.2. Word sync — chữ chạy theo giọng như thế nào

- Help Center: *"Text-to-speech reads a document aloud while SwiftRead keeps the spoken words in sync with the reader. It works in all three reading modes: Focus, Flow, and Spotlight."*
- Blog: *"With text-to-speech on in Flow, each word is highlighted as it's spoken, so your eyes follow the voice."* Và: *"The article is read aloud while the full text stays on screen and a gray highlight follows the voice."*
- Tức pattern sync là: **highlight từng từ, màu xám, di chuyển theo đúng từ đang được phát âm** — mắt người đọc dõi theo giọng. Đây là cùng pattern với Speechify (highlight câu đang đọc + từ đang đọc), nhưng SwiftRead mô tả highlight **theo từng từ** là chính, không nhắc tới highlight theo câu.
- Ở Focus/Spotlight + TTS: tài liệu chính thức chỉ nói "text-to-speech works in all three" và text vẫn hiện trên màn hình; **không mô tả chi tiết** cụm từ hiện ra ở Focus có nhảy theo từng từ giọng đọc hay theo chunk WPM — **chưa xác minh** (cần APK hoặc chạy app thật).

### 3.3. Giọng đọc

- **Voice Library: 90+ ngôn ngữ** (theo App Store) — giọng "human-like"/"human-sound".
- Chọn sai giọng/ngôn ngữ → vào Text-to-Speech Settings → Current voice → Voice Library để đổi.
- **Giới hạn Free/PRO:** Free có **daily narration allowance** (xem số từ còn lại trong Text-to-Speech Settings, mục **"Free quota (daily)"**); hết quota thì đợi reset ngày hôm sau hoặc nâng cấp. PRO: narration không giới hạn. Premium pages (trang Kindle/Libby, PDF scan, trang đã lưu vào Library) cũng có daily allowance riêng ở Free, không giới hạn ở PRO.

### 3.4. Cơ chế sync bên trong — [ĐÃ XÁC MINH từ APK 1.10.3 — xem §11.4]

Phân tích binary ngày 24/11/2026 đã xác nhận giả thuyết A và loại giả thuyết B (chi tiết §11.3–11.4). Hai giả thuyết ban đầu:

| Giả thuyết | Căn cứ | Cách xác minh khi có APK |
|---|---|---|
| **A. Cloud TTS + word timestamps** (giống Speechify: server trả audio kèm mốc thời gian từng từ, client map thời gian phát → vị trí từ) | Có daily allowance tính theo **số từ** narration; giọng "human-like" 90+ ngôn ngữ; app yêu cầu Internet ("Internet connection required"); TTS là tính năng tính phí theo lượng dùng | Tìm endpoint TTS + field timestamp trong dex/`res`, hoặc đo traffic khi chạy app |
| **B. Android TextToSpeech on-device + `onRangeStart`** (API 26+, callback vị trí từ đang đọc) | Android 7.0+ (API 24) nhưng `onRangeStart` cần API 26; giọng máy thường không có 90+ ngôn ngữ "human-like" | Tìm `android.speech.tts.TextToSpeech`, `UtteranceProgressListener`, `onRangeStart` trong dex |

Giả thuyết A khả thi hơn vì quota tính theo từ + giọng cloud 90+ ngôn ngữ — và **đã được xác nhận đúng sau khi có APK**: cloud TTS (Azure AI Speech) + word timestamps (timepoints) theo từng part; giả thuyết B **sai** — không có `TextToSpeech`/`onRangeStart` trong dex. Dù là A hay B, **pattern phía UI là như nhau** (highlight từng từ theo thời gian thực), nên phần port ở §7–§8 không phụ thuộc vào đáp án này.

---

## 4. Tốc độ — WPM, chunk, micro-pauses

### 4.1. Một số WPM duy nhất cho cả mắt lẫn tai

Đây là điểm quan trọng nhất của báo cáo, trả lời câu hỏi "tốc độ giọng có liên quan gì tới WPM không":

- Help Center (bài "Changing the reading speed...", bản legacy nhưng định nghĩa còn nguyên trong bản hiện tại qua bài import settings): *"Reading speed: how fast SwiftRead presents the words to you (**either visually and/or via text-to-speech**) in words per minute, or WPM."*
- Bài import legacy settings (cập nhật 30/08/2026) xác nhận: setting **WPM (legacy) → Reading speed (hiện tại)**, chỉ "rounded and adjusted to the current reader's supported range". Và **"Legacy audio WPM" KHÔNG được import** — tức bản hiện tại **không còn tốc độ audio riêng**; chỉ còn một Reading speed chung.
- **Kết luận:** SwiftRead dùng **một con số WPM duy nhất** điều khiển cả nhịp hiển thị (RSVP/highlight) lẫn tốc độ narration. Người dùng chỉnh tốc độ bằng **speedometer control cạnh Play** — chỉnh một lần, áp dụng cho cả hai. Blog cũng viết: *"Change the voice in the text-to-speech settings, and the speed with the speedometer control next to Play"* — giọng và tốc độ là hai control tách biệt.
- **Hệ quả cho port:** không cần 2 slider (một cho WPM hiển thị, một cho tốc độ giọng 0,5x–2x kiểu Speechify). Một slider WPM + map WPM → playback rate của TTS engine là đủ, đơn giản hơn và đúng mental model của SwiftRead.

### 4.2. Dải tốc độ (số liệu đo được từ nguồn công khai)

| Số liệu | Giá trị | Nguồn |
|---|---|---|
| Tốc độ tối thiểu | **50 WPM** (bản mới nhất; trước đó là **10 WPM**) | Review user trên Google Play (AppBrain): "you changed the minimum speed from 10 WPM to 50 WPM… I would like you to keep the minimum speed limit the same as before, at 10 WPM" |
| Tốc độ tối đa | **9x** (bản mới nhất nâng từ 5x lên 9x) | Cùng review user trên: "you increased the speed from 5x to 9x, which is very good" — khớp với binary: MAX_WPM 450 = 9 × 50 (min), xem §11.5 |
| Marketing | "up to 3X faster" | APKPure / App Store |
| Tốc độ tối đa tuyệt đối (WPM) | **450 WPM — đã xác minh từ binary** (chuỗi `MAX_WPM (450 WPM)` trong bundle JS của APK 1.10.3) | Xem §11.5 |
| Bước nhảy (step) của slider | **Phím tắt: 10 WPM (fine) / 50 WPM (coarse) — đã xác minh từ binary** (chuỗi "Increase/Decrease pacing speed by 10/50 WPM"; hằng `FINE_WPM_DELTA`/`COARSE_WPM_DELTA` trong bundle). Step khi kéo slider tay vẫn chưa rõ | Xem §11.5 |

Lưu ý: tốc độ đọc to (read-aloud) của người trung bình ~183 WPM, đọc thầm ~238 WPM (Brysbaert 2019) — nên dải 50 WPM là mức đọc chậm/nghe kỹ (học ngoại ngữ), còn 9x là mức skim. Con số 50 WPM tối thiểu mới là **điểm đáng học cho app học tiếng Anh**: người học cần nghe chậm hơn cả tốc độ nói tự nhiên.

### 4.3. Chia chunk — "Words at a time" 1–6 từ

- Setting **Words at a time: 1–6 từ** mỗi lần hiển thị (Focus). Bài import legacy settings: "Chunk size → Words at a time. Counts from 1 to 6 transfer directly." Giá trị hiện tại xem được dưới icon speedometer ("The value appears under **Words at a time**").
- **Chưa xác minh:** chunk ở Focus có cố định 1–6 hay tự co giãn theo dấu câu/cụm từ; Flow/Spotlight chia cụm theo câu hay theo số từ — cần APK hoặc chạy app.

### 4.4. Micro-pauses — chỉ khi đọc bằng mắt

- Help Center "Micro-pauses" (bản legacy): khi **TTS tắt**, chỉnh được mức pause lâu hơn ở **từ dài, số, dấu phẩy, dấu chấm, đoạn mới**.
- Khi **TTS bật**: *"the speech audio approximates a natural human speaking pattern. There isn't a way to control the speaking pattern from SwiftRead itself"* — tức nhịp ngắt/phrasing do giọng TTS quyết định, user không chỉnh micro-pause nữa.
- **Hệ quả cho port:** đừng làm 2 hệ thống pause chồng nhau. Visual mode cần micro-pause riêng; narration mode phó mặc prosody cho TTS engine.

---

## 5. Hành vi play / pause / chuyển đoạn

| Hành vi | Mô tả (theo tài liệu chính thức) |
|---|---|
| Play/Pause | Nút Play/Pause chính; phím tắt Play/pause. |
| Đổi setting khi đang phát | **Không được:** phải Pause trước — icon loa (narration) và icon speedometer chỉ thao tác được khi đã pause ("If the speaker icon is missing, pause reading first"). |
| Resume sau pause | Bấm Play → **đọc tiếp từ chỗ dừng** (blog PDF: "Pause whenever you want to reread a passage, then press Play to continue"). |
| Nhảy đoạn | Phím tắt **Jump back / Jump forward** (được import từ legacy settings). Tài liệu hiện tại không nói rõ nhảy theo câu hay theo % — **chưa xác minh**. |
| Tăng/giảm tốc khi đang đọc | Phím tắt **Speed up / Slow down**; slider speedometer chỉnh được bất cứ lúc nào đã pause; blog nói "you can change the speed or pause whenever you need". |
| Bật/tắt narration nhanh | **Double-click / double-tap icon loa** (không mở settings). Phím tắt **Toggle narration**. |
| Đọc lại đoạn vừa nghe | Pause → (đọc lại bằng mắt) → Play để tiếp tục; không có mô tả nút "nhảy về đầu câu" riêng trong tài liệu hiện tại. |
| Tiếp tục trên thiết bị khác | Đăng nhập cùng tài khoản → **Library + reading progress sync** qua Android/iOS/web/extension. |

So với Speechify (skip theo câu, seek theo % toàn bộ nội dung, click câu để nhảy tới đọc từ câu đó): SwiftRead **đơn giản hơn** — không thấy mô tả click-to-jump hay seek bar trong tài liệu hiện tại; điều khiển tập trung vào Play/Pause + tốc độ + chuyển mode. Đây là điểm khác biệt về triết lý: SwiftRead tối giản control, Speechify nhiều control nhảy/tua hơn.

---

## 6. Tóm tắt pattern (để re-implement, không copy code)

1. **Một WPM — hai đầu ra:** một giá trị Reading speed (WPM) duy nhất điều khiển cả nhịp hiển thị lẫn tốc độ narration. UI: speedometer cạnh Play; Settings giọng tách riêng.
2. **Ba mode hiển thị trên cùng một engine đọc:** Focus (RSVP), Flow (highlight chạy), Spotlight (mờ xung quanh) — chuyển mode không làm mất vị trí đọc; TTS chạy được ở cả ba.
3. **Word sync = highlight từng từ theo thời gian thực**, màu xám, ở Flow là rõ nhất; mắt dõi theo giọng.
4. **Chunk 1–6 từ** (Words at a time) cho RSVP; xem/giá trị ngay dưới speedometer.
5. **Micro-pause chỉ cho visual:** pause dài hơn ở từ dài/số/dấu câu/đoạn mới; khi narration bật thì prosody thuộc về TTS engine.
6. **Tối giản control khi phát:** đổi setting phải pause trước; double-click loa = toggle narration nhanh; phím tắt đủ 6 thao tác (play/pause, jump back/forward, speed up/down, toggle narration).
7. **Quota theo số từ:** Free có daily allowance cho narration (hiển thị "Free quota (daily)" + số từ còn lại); PRO không giới hạn — pattern freemium tính theo lượng dùng, không khóa tính năng.
8. **Tốc độ chậm là tính năng, không phải lỗi:** min 50 WPM (từng là 10 WPM) phục vụ nghe chậm/học ngôn ngữ; user phàn nàn khi bị nâng min — bài học: đừng nâng min speed mà không có lý do, người học ngoại ngữ cần tốc độ rất chậm.

**Lưu ý (cập nhật 24/11/2026):** các pattern 1–7 nay đã có bằng chứng binary ở §11 (đặc biệt pattern 1, 3, 5 — xem §11.4, §11.10).

---

## 7. Phần nào học/port được (cho TransPeek + Seeless)

| Pattern SwiftRead | Port được không? | Ghi chú |
|---|---|---|
| 1 WPM duy nhất cho cả visual + TTS | **Nên làm** — đơn giản hơn Speechify (2 tốc độ riêng). TransPeek hiện bị lỗi "Full đọc ngắt từng từ vì mỗi chunk đọc riêng" — map WPM → TTS rate sẽ giúp giọng liền mạch. | Cần map WPM → rate: vd 150 WPM ≈ 1.0x giọng tự nhiên (nói ~130–150 WPM); 50 WPM ≈ 0.35x. Hệ số map **chưa xác minh** từ SwiftRead — tự chọn khi implement. |
| 3 mode Focus/Flow/Spotlight | **Nên làm, theo thứ tự:** Flow trước (phù hợp nhất cho đọc theo giọng + học từ), Focus sau (RSVP), Spotlight cuối. | TransPeek đã có panel Read (Full/Lite) — Flow tương đương "highlight chạy trên toàn trang" trong Full window. |
| Word highlight từng từ màu xám theo giọng | **Nên làm** — đây là tính năng Manh đang cần cho TTS word-sync. | Đã xác minh: SwiftRead dùng cloud TTS + timepoints theo từng part (xem §11.4); pattern port: tách WordPlayer thành 1 interface với 2 driver (audio-timepoints và visual-timer). |
| Words at a time 1–6 | **Nên làm** cho Focus/RSVP. | Số chunk nhỏ, dễ implement: chia text thành cụm 1–6 từ theo setting. |
| Micro-pauses visual-only | **Nên làm** (dễ): cộng thêm delay ở dấu câu/từ dài khi đọc bằng mắt; tắt khi narration bật. | Đã có bài học tương tự ở ReadSwift (pause ở dấu phẩy/dấu chấm). |
| Double-click loa = toggle narration | **Nên làm** — thao tác nhanh, ít click. | Áp dụng cho icon loa float của TransPeek. |
| Đổi setting phải pause trước | **Cân nhắc** — SwiftRead làm vậy vì tránh trạng thái dở dang; TransPeek có thể cho đổi tốc độ ngay khi đang phát (Speechify làm được) — quyết định theo UX Manh muốn, không bắt buộc theo SwiftRead. |
| Quota Free theo số từ/ngày | **Tham khảo cho Pro plan** — TransPeek Pro đã chốt nội bộ (one-time ~99k–199k, không subscription); quota ngày kiểu SwiftRead là một phương án free-tier, nhưng Manh đã chốt "free core giữ free forever" nên chỉ tham khảo, không áp nguyên. | — |
| Sync progress cross-device | **Chưa cần** — TransPeek/Seeless chưa có tài khoản/cloud. | Ghi nợ tương lai. |

---

## 8. Đánh giá port sang Seeless AI Speech

### 8.1. Kết quả kiểm tra repo — repo TRỐNG

Kiểm tra ngày 23/11/2026 qua **GitHub connector** (đã kết nối, `status: connected`):

- Repo tồn tại: **`TranManhTuanLabs/SeeLess-AI-Speech`** — public, tạo 11/09/2026, cập nhật 11/09/2026, 0 star / 0 fork / 0 issue, mô tả: *"Turn any text into voice. Listen anywhere with AI Smart Bubble. ## Vision AI Text to Speech layer for Android. Turn any text into voice. Listen anywhere with AI Smart Bubble."*
- Đọc nội dung root + liệt kê commits đều trả về lỗi **`409 Git Repository is empty`** — repo **chưa có một file hay commit nào**.
- **Kết luận: đúng như Manh dặn — source Seeless hiện chỉ nằm LOCAL trên máy Mac của Manh, chưa đẩy lên repo. Không thể đánh giá map cụ thể (cái gì map được/không, cần xây thêm gì) vì không có kiến trúc thật để đối chiếu. Mọi nhận xét dưới đây về Seeless đều ở mức "theo mô tả repo" và được đánh dấu rõ — KHÔNG bịa kiến trúc.**

### 8.2. Cần đúng những file/source nào của Seeless để đánh giá port

Để đánh giá lần sau (khi Manh đẩy source lên repo hoặc gửi source), cần tối thiểu:

| # | File / nhóm file cần | Để trả lời câu hỏi gì |
|---|---|---|
| 1 | `AndroidManifest.xml` (và `build.gradle` / `settings.gradle`) | App Android native? minSdk/targetSdk (quyết định dùng được `onRangeStart` API 26+ không), quyền (foreground service? overlay `SYSTEM_ALERT_WINDOW` cho Smart Bubble?), TTS engine dependency nào |
| 2 | Cây source `app/src/main/java/...` (tên package, các Activity/Service) | Có sẵn Service đọc nền (foreground service + MediaSession/notification) chưa, hay mới chỉ là Activity; Smart Bubble là Service overlay hay AccessibilityService |
| 3 | Module TTS hiện tại (class gọi TTS) | Đang dùng **Android TextToSpeech on-device** hay **cloud TTS API** (giọng nào, có word timestamps không); cách chia text thành utterance; có `UtteranceProgressListener`/`onRangeStart` chưa |
| 4 | Module xử lý text (tokenize/chunk) | Đã có chia câu/từ/chunk chưa, hay mới đọc cả đoạn một lần (lỗi giống TransPeek Full hiện tại: mỗi chunk đọc riêng → ngắt quãng) |
| 5 | UI player hiện tại (layout + ViewModel/State) | Đã có Play/Pause/tốc độ/chọn giọng chưa; state đọc (vị trí từ/câu hiện tại) lưu ở đâu — để gắn highlight theo giọng |
| 6 | `README.md` / doc kiến trúc (nếu có) | Mục tiêu sản phẩm: "AI Smart Bubble" bắt text ở đâu (clipboard? Accessibility? overlay mọi app?) — quyết định pattern word-sync nào khả thi |
| 7 | Branch/commit mới nhất trên `main` | Đảm bảo đánh giá trên code mới nhất, không phải bản cũ |

**Cách gửi nhanh nhất cho Manh:** trên Mac, vào thư mục source Seeless local → `git push` lên repo `TranManhTuanLabs/SeeLess-AI-Speech` (repo đã có sẵn, đang trống), rồi báo lại — lần chạy sau sẽ đánh giá map cụ thể được ngay, không cần gửi file lẻ.

### 8.3. Đánh giá sơ bộ theo mô tả repo (chưa xác minh — chỉ để tham khảo)

- Mô tả repo nói Seeless là **"AI Text to Speech layer for Android"** với **"AI Smart Bubble"** — tức là lớp TTS phủ trên mọi app Android (bubble nổi), khác SwiftRead (app đọc tài liệu trong chính nó). Vì vậy **pattern port được nhiều nhất là §7** (1 WPM chung, word highlight theo giọng, chunk 1–6, micro-pause visual-only, double-click loa toggle) — còn **3 mode đọc của SwiftRead chỉ port được phần Flow** (highlight chạy trên text) vì Bubble không sở hữu trang đọc; Focus/Spotlight kiểu RSVP cần một màn hình đọc riêng, không hợp với bubble nổi trên app khác.
- **Rủi ro lớn nhất (dự đoán):** word sync trên text của app khác — Bubble không có DOM/text gốc như SwiftRead có tài liệu của mình; muốn highlight từng từ thì phải lấy được text + vị trí từ qua Accessibility hoặc clipboard, rồi tự map với giọng. Đây là phần khó nhất, cần source thật mới đánh giá được.
- **Không kết luận gì thêm về Seeless** cho tới khi có source.

---

## 9. Chưa xác minh được — cần làm tiếp

| # | Chưa biết | Cách xác minh |
|---|---|---|
| 1 | ~~File APK (manifest, versionCode, targetSdk, dung lượng thật)~~ | **ĐÃ XONG 24/11/2026** — Manh gửi XAPK 1.10.3 qua Google Drive; manifest: versionCode 102, versionName 1.10.3, minSdk 24, targetSdk 36, base APK ~47,6 MB, tổng XAPK ~68,9 MB, không OBB. Xem §11.1 |
| 2 | Dải WPM tuyệt đối của slider (min 50, max ? WPM), bước nhảy, preset tốc độ | **ĐÃ XÁC MINH MỘT PHẦN 24/11** — max 450 WPM (binary); phím tắt step 10/50 WPM (binary); min 50 WPM vẫn theo review (chưa đọc được từ bytecode Hermes v96); preset tốc độ/step slider tay chưa rõ. Xem §11.5 |
| 3 | TTS engine thật (cloud endpoint nào? word timestamps dạng gì? hay on-device `onRangeStart`?) | **ĐÃ XÁC MINH 24/11** — cloud Azure AI Speech (neural voices), audio qua signed URL CloudFront, word timestamps (timepoints) theo từng part, adaptive prefetch; KHÔNG dùng on-device TTS. Xem §11.3–11.4 |
| 4 | Focus/Spotlight + TTS: cụm từ nhảy theo giọng hay theo chunk WPM? | Chạy app thật, quay màn hình khi bật narration ở Focus/Spotlight |
| 5 | Jump back/forward nhảy theo đơn vị gì (câu? cụm? %) | **ĐÃ XÁC MINH MỘT PHẦN 24/11** — nhảy theo **giây** (`JUMP_TO_TIME_DELTA_SECONDS`) + seek theo token (`seekToToken`); số giây mỗi lần nhảy chưa rõ. Xem §11.7 |
| 6 | Đánh giá port cụ thể sang Seeless | Manh đẩy source Seeless local lên repo `TranManhTuanLabs/SeeLess-AI-Speech` (xem §8.2) rồi chạy lại đánh giá |

---

## 10. Nguồn

- SwiftRead Help Center (helpscoutdocs.com): "Enable audio narration" (cập nhật 07/11/2026) — https://swiftread.helpscoutdocs.com/article/75-enable-audio-narration
- SwiftRead Help Center: "Import your legacy extension settings" (30/08/2026) — https://swiftread.helpscoutdocs.com/article/108-syncing-importing-your-legacy-extension-settings
- SwiftRead Help Center: "Changing the reading speed, number of words at a time, and font size" (legacy, 23/03/2026) — https://swiftread.helpscoutdocs.com/article/15-changing-the-reading-speed-number-of-words-at-a-time-and-font-size
- SwiftRead Help Center: "Micro-pauses: controlling how SwiftRead pauses while reading" (legacy, 23/03/2026) — https://swiftread.helpscoutdocs.com/article/22-micro-pauses-controlling-how-swiftread-pauses-while-reading
- SwiftRead Help Center: "Audio narration limits on PRO and free plans" (04/09/2026) — https://swiftread.helpscoutdocs.com/article/66-audio-narration-limits-on-pro-and-free-plans
- SwiftRead blog: "Read or listen to long articles at your own speed" (07/11/2026) — https://swiftread.com/blog/read-long-articles
- SwiftRead blog: "Listen to your PDFs" — https://swiftread.com/blog/listen-to-a-pdf-while-following-the-text
- APKPure: SwiftRead app page + download page (truy cập 22–23/11/2026) — https://apkpure.com/swiftread-speed-reading/com.swiftread.universal
- AppBrain: SwiftRead – Speed Reading (cập nhật 22/10/2026) — https://www.appbrain.com/app/swiftread-speed-reading/com.swiftread.universal
- App Store: SwiftRead – Speed Reading, v1.10.6 — https://apps.apple.com/us/app/swiftread-speed-reading/id6470811151
- Đối chiếu: `speechify-report.md`, `naturalreader-report.md`, `rsvp-report.md` (cùng thư mục).

---

## 11. Phân tích binary từ APK 1.10.3 (bổ sung 24/11/2026)

> Nguồn: file XAPK do Manh gửi qua Google Drive (`SwiftRead_-_Speed_Reading_1.10.3_APKPure.xapk`, 68.879.539 bytes), giải nén + phân tích ngày 24/11/2026. Công cụ: `unzip`, `strings`, androguard 4.1.4 (manifest + dex), parse thủ công bảng string của Hermes bytecode v96 (hbctool mới nhất 0.1.5 chỉ hỗ trợ tới HBC v76 nên KHÔNG disassemble được — các hằng số dạng số như MIN_WPM, TTS_WPM_CAP chỉ thấy tên, không đọc được giá trị). Mọi phát hiện dưới đây đều ghi rõ nguồn (binary vs tài liệu vs suy luận). File giải nén + script parse lưu ở `~/workspace/research_notes/swiftread-apk-20261124/` (thư mục `extract/`, venv androguard/hbctool, script `parse_hbc_strings.py`).

### 11.1. File XAPK — cấu trúc và manifest

- XAPK = ZIP chứa bộ split APK (Android App Bundle): APK chính `com.swiftread.universal.apk` (~47,6 MB) + split `config.armeabi_v7a.apk` (~18 MB native libs) + 17 split ngôn ngữ (`config.en`, `config.vi`, ... — có cả tiếng Việt) + `config.hdpi.apk` (density). Không có file OBB. Kèm `manifest.json` (package, version, permissions, danh sách split).
- Manifest (đọc bằng androguard): package `com.swiftread.universal`, versionName 1.10.3, versionCode 102, minSdk 24 (Android 7.0), targetSdk 36, compileSdk 36. MainActivity `com.swiftread.universal.MainActivity`.
- Quyền đáng chú ý: INTERNET, RECORD_AUDIO, SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE, WAKE_LOCK, BILLING, CAMERA, READ_MEDIA_AUDIO. Không có service foreground riêng cho audio trong manifest — narration chạy in-app (không chạy nền kiểu music player).
- Thư viện nhận diện được: RevenueCat (mua PRO), Google Play Billing, Sentry, PostHog, Airbridge, Supabase, ML Kit barcode, Expo modules.

### 11.2. Framework — React Native + Expo, không phải native thuần

- App viết bằng **React Native + Expo SDK 54** (new architecture bật), JS chạy trên **Hermes engine v96** (`assets/index.android.bundle`, 20,5 MB, Hermes bytecode). UI strings nằm trong bundle JS, không nằm trong `resources.arsc` (arsc chỉ còn chuỗi của AndroidX/Material) — vì vậy không đọc được label slider từ res.
- Vì là React Native nên logic đọc/TTS nằm hết trong JS bundle; dex (10 MB + 5,8 MB) chủ yếu là Expo/React Native bridge + thư viện. Không có Java/Kotlin riêng cho TTS.
- Hệ quả cho port: pattern của SwiftRead là pattern **JS/React Native**, nhưng các pattern kiến trúc (WordPlayer, part/timepoints, prefetch) là độc lập framework — port sang native (Swift/Kotlin/Desktop) vẫn dùng được (xem §11.10).

### 11.3. TTS engine — cloud Azure AI Speech, không phải on-device [đã xác minh]

Bằng chứng từ binary (xếp theo độ chắc chắn):

1. **Tên giọng Azure trong bundle:** các file sample giọng `en-US-AvaMultilingualNeural.m4a`, `en-US-BrianMultilingualNeural.m4a`, `en-US-AndrewMultilingualNeural.m4a`, `en-US-EmmaMultilingualNeural.m4a`, `en-US-NancyMultilingualNeural.m4a`, `en-US-NovaTurboMultilingualNeural.m4a`, ... — đây là tên giọng **Azure AI Speech neural** (dòng MultilingualNeural + Turbo). Sample host trên Supabase Storage (`...supabase.co/storage/v1/object/public/static/voice-samples/en-US-...Neural.m4a`).
2. **Hàm resolve giọng Azure:** `resolveAzureVoiceShortName`, `resolveAzureRecommendedLocale`, `resolveAzureLocaleFailed`, `isPlausibleAzureVoiceShortName`, `isValidTtsVoiceName`, `azure_tts_rate_limited`, regex kiểm tra tên giọng `...Neural`.
3. **Không có on-device TTS:** trong toàn bộ dex (classes.dex/2/3) KHÔNG có `android.speech.tts.TextToSpeech`, `UtteranceProgressListener`, `onRangeStart`, `setSpeechRate` — chỉ có các hằng speech-recognition (từ thư viện khác) và `setPitch`. Bundle JS cũng không có expo-speech. **Giả thuyết B ở §3.4 bị loại.**
4. **Server riêng:** app server Cloud Run `https://app-server-prod-120403148976.us-east4.run.app` (đường dẫn `/tts-adaptive-prefetch-v1`), API base `https://base.swiftread.com`, client dùng tRPC (`createTRPCProxyClient`). Audio TTS lấy qua **signed URL** trỏ tới CloudFront (`https://da08ctfrofx1b.cloudfront.net/bucket...`) — có chuỗi lỗi "Error getting signed url for tts audio file".
- Kết luận: **cloud TTS (Azure AI Speech) + server tổng hợp audio + client phát file audio**. Nhờ vậy mới có 90+ ngôn ngữ giọng "human-like" và quota tính theo số từ. Cần Internet để narration (khớp tài liệu).

### 11.4. Cơ chế word sync — timepoints theo từng part + WordPlayer [đã xác minh]

- **Đơn vị đồng bộ là "part" + "timepoint":** tài liệu được chia thành các part (theo token), mỗi part tổng hợp thành 1 file audio kèm danh sách **timepoints** (mốc thời gian từng từ). Class/hàm trong bundle: `TtsAudioPart`, `TtsAudioPartManager`, `TtsAudioPart.getTimepointAtPosition`, `TtsAudioPart.getSound`, `TtsAudioPartManager.getPartWords`, `getPartEndTokenIdx`, `updateStats`; chuỗi lỗi "called on a TtsAudioPart with empty/no/undefined timepoints", "part: timepoints". **Đây chính là cơ chế sync: vị trí phát audio → timepoint → chỉ số từ (token idx) → highlight từ đó.**
- **WordPlayer — 1 interface, 2 driver (pattern quan trọng nhất để port):** bundle có `WordPlayer` (base) với 2 implementation: `SimpleTtsWordPlayer` (chạy theo audio + timepoints khi narration bật) và `VisualOnlyWordPlayer` (chạy theo timer WPM khi đọc bằng mắt). Cả hai cùng cập nhật `currentTokenIdx`/`wpm` (`[WordPlayer] Updating WordPlayer wpm`, `updateWordPlayerWpmForRamp`, `updatePlaybackRate`). Nhờ tách này mà 3 mode hiển thị (Focus/Flow/Spotlight) dùng chung 1 engine đọc — mode chỉ là cách render khác nhau của cùng 1 vị trí token hiện tại.
- **Chunker — chia token:** `Chunker` + `buildTokenIndexMap`, `buildSentenceStartTokenIdxs`, `currentTokenIdx`, `chunkStopTokenIdxs`, `currentLineChunksTokenIdxs`, `lineTokenIdxs` — text được tokenize (từ/câu/dòng) và map chỉ số token để scroll/highlight đúng vị trí (`SCROLL_TO_TOKEN_LOCATION`, `SCROLL_TO_CURRENT_TOKEN_IDX`, `seekToToken`).
- **Phát audio:** expo-av (`Audio.Sound`, `setRateAsync`, `shouldCorrectPitch`) — tốc độ giọng đổi bằng **playback rate của file audio, có pitch correction** (giọng không bị méo khi tăng tốc). `TtsAudioPartManager.calculateEstimatedPlaybackRate` ước lượng rate từ WPM mẫu (`sampleWpm`) — tức WPM → rate là phép map có tính toán, không phải rate cố định.
- **Prefetch thích ứng:** `adaptivePrefetchEnabled`, `adaptivePrefetchConfig`, `ADAPTIVE_PREFETCH_LOOKAHEAD_PARTS`, `refreshAdaptivePrefetchConfig`, endpoint `/tts-adaptive-prefetch-v1` — client tổng hợp trước các part sắp tới (lookahead N part), config làm mới được từ server; `snapToSynthesizedBoundary` (phát tới đâu thì chỉ phát tới biên part đã tổng hợp xong), `maxSynthesizedTokenIdx`.
- **Giới hạn part:** có `DEFAULT_TTS_SOFT_MAX_TOKEN_COUNT_PER_PARTIAL_EXTRACTION` và `..._HARD_MAX_TOKEN_COUNT_PER_PARTIAL_EXTRACTION...` (soft/hard cap số token mỗi lần trích xuất part) + `NUM_TOKENS_PER_PARTITION` — tài liệu dài được cắt part theo token, không tổng hợp cả bài một lần. (Giá trị số cụ thể nằm trong bytecode, chưa đọc được.)
- **Focus/Spotlight + TTS (mục §9.4):** vẫn chưa xác minh được bằng runtime, nhưng kiến trúc trên cho thấy cả 3 mode cùng chạy trên 1 WordPlayer: ở Focus, chunk hiện ra nhảy theo token hiện tại của giọng; ở Flow, highlight từ chạy theo giọng; ở Spotlight, các từ khác mờ dần theo token hiện tại. Cần chạy app thật mới khẳng định chi tiết hiển thị.

### 11.5. Tốc độ WPM — max 450 đã xác minh, min chưa đọc được

- **MAX_WPM = 450 — đã xác minh:** chuỗi `MAX_WPM (450 WPM)` trong bundle JS (kèm chuỗi diagnostic "WPM below average").
- **MIN_WPM — chưa đọc được từ binary:** hằng `MIN_WPM` có tên trong bundle nhưng giá trị số nằm trong bytecode Hermes v96 (hbctool 0.1.5 chỉ hỗ trợ tới HBC v76, không disassemble được). Review user trên Play nói min mới là 50 WPM (trước là 10 WPM) — giữ nguyên theo review, chưa khẳng định cho build 1.10.3. Gợi ý khớp số: 450 = 9 × 50, khớp với review nói max nâng từ 5x lên 9x (nếu 9x tính theo min 50).
- **Bước nhảy phím tắt: 10 WPM (fine) / 50 WPM (coarse) — đã xác minh:** chuỗi "Increase/Decrease pacing speed by 10 WPM" và "...by 50 WPM" + hằng `FINE_WPM_DELTA`/`COARSE_WPM_DELTA`. Step khi kéo slider tay chưa rõ.
- **TTS_WPM_CAP:** hằng giới hạn WPM riêng cho narration có tồn tại trong bundle (`TTS_WPM_CAP`), giá trị chưa đọc được.
- **Slider:** `sliderPositionFromWpm` / `_wpmFromSliderPosition` / `pacingSliderMax` — slider map vị trí ↔ WPM (có thể không tuyến tính); `effectiveMaxWpm`, `commitWpm`, `applyWpmDelta`, `updateWpmForRamp`/`buildStartRampPlan` (có khái niệm "ramp" — tăng tốc dần khi bắt đầu đọc).

### 11.6. Mode, chunk, micro-pause — hằng số đã thấy trong binary

- **3 mode:** `SPEED_READING_MODE_OPTIONS`, chuỗi "Cycle speed reading mode: Focus, Flow, Spotlight." — khớp tài liệu §2.
- **Chunk:** `MAX_WORDS_AT_A_TIME`, `MIN_WORDS_AT_A_TIME`, `DEFAULT_WORDS_AT_A_TIME`, `clampWordsAtATime`, `setWordsAtATime`, label "words at a time" — khớp tài liệu (1–6 từ); giá trị số cụ thể chưa đọc được từ bytecode (tài liệu legacy nói 1–6).
- **Highlight:** component `BionicHighlight` — renderer highlight từ hiện tại.
- **Micro-pause:** `PAUSE_TYPES`, `mapPauseTypeToSettingKey`, `sentence_pauseTypeToString` + chuỗi "Rhythm pauses do not apply when narration" — khớp §4.4 (chỉ khi đọc bằng mắt).

### 11.7. Hành vi play/pause/nhảy — đã xác minh một phần

- **Jump back/forward nhảy theo GIÂY:** hằng `JUMP_TO_TIME_DELTA_SECONDS` — nhảy theo delta thời gian (giây), không phải theo câu/cụm. Số giây mỗi lần nhảy chưa đọc được (nằm trong bytecode). Ngoài ra có `seekToToken` (nhảy tới 1 token/từ cụ thể — click-to-jump ở mức từ) và `jumpToTokenLocationInternal`.
- **Đổi setting phải pause trước:** khớp tài liệu (icon loa/speedometer chỉ thao tác khi đã pause).
- **Double-click loa = toggle narration:** khớp tài liệu (đã có ở §3.1/§5).

### 11.8. Quota — đã xác minh trong code

- `TTS_WORDS_QUOTA_WARNING_THRESHOLD`, `FreeQuotaExceededError`, `useQuotaQuery`, `quota_limit_hit`, `handleTtsQuotaExceeded`, `mapQuotaTypeToAnalyticsFeature`, `normalizeQuotaMessage`, `PREMIUM_PAGE_QUOTA_EXCEEDED_ERR`, chuỗi "has exceeded the free quota for TTS" / "Free quota (daily)" — quota tính theo **số từ narration/ngày** (Free) như tài liệu §3.3.

### 11.9. Còn chưa xác minh được (ngay cả sau khi có APK)

| # | Chưa biết | Vì sao chưa biết / cách xác minh tiếp theo |
|---|---|---|
| 1 | Giá trị `MIN_WPM` (50? hay khác) trong build 1.10.3 | Hằng số nằm trong bytecode Hermes v96; hbctool mới nhất (0.1.5) chỉ hỗ trợ tới HBC v76. Cần tool disassemble HBC v96 (chờ hbctool cập nhật) hoặc chạy app thật và xem slider |
| 2 | Giá trị `TTS_WPM_CAP`, `MAX/MIN_WORDS_AT_A_TIME`, soft/hard max token per part, số giây jump back/forward, step slider tay | Cùng lý do trên — các hằng số nằm trong bytecode |
| 3 | Focus/Spotlight + TTS: cụm từ nhảy theo giọng hay theo chunk WPM? | Cần chạy app thật, quay màn hình khi bật narration ở Focus/Spotlight |
| 4 | Chi tiết phía server: Azure dùng SSML/word-boundary event ra sao, tRPC procedure TTS chính xác là gì, audio format (mp3? LINEARPCM?) | Chỉ thấy phía client (tên hàm, endpoint, signed URL); cần traffic khi chạy app hoặc tài liệu server (không có) |
| 5 | Đánh giá port cụ thể sang Seeless | Repo Seeless vẫn trống (xem §8.2) — Manh đẩy source local lên repo rồi chạy lại đánh giá |

### 11.10. Bài học port (mức pattern — cho Seeless + app desktop native)

1. **Tách WordPlayer thành 1 interface + 2 driver** (pattern quan trọng nhất): `WordPlayer` chung, driver TTS (chạy theo audio + timepoints) và driver visual (chạy theo timer WPM). Nhờ vậy 3 mode hiển thị + bật/tắt narration không phải viết lại engine đọc — chỉ đổi driver. TransPeek hiện bị lỗi "Full đọc ngắt từng từ vì mỗi chunk đọc riêng" — tách driver kiểu này là cách sửa đúng hướng: giọng là 1 luồng audio liền mạch, highlight chỉ là "con trỏ token" chạy theo.
2. **Part + timepoints, không tổng hợp cả bài:** cắt tài liệu thành part theo token (có soft/hard cap), mỗi part = 1 file audio + danh sách timepoints (từ → mili-giây). Client prefetch lookahead N part, phát tới đâu chỉ tới biên part đã xong (`snapToSynthesizedBoundary`). Pattern này áp dụng được cho cả desktop native (audio file + timestamp map) lẫn mobile.
3. **Một WPM → playback rate (có pitch correction):** không cần 2 tốc độ riêng; map WPM → rate phát audio (`setRateAsync` + `shouldCorrectPitch`) để giọng không bị méo khi tăng tốc. `calculateEstimatedPlaybackRate` gợi ý rate được ước lượng từ WPM mẫu, không hardcode.
4. **Chunker tokenize trước, map chỉ số token:** tokenize toàn bộ text thành từ/câu/dòng + map chỉ số token ngay từ đầu — mọi tính năng (highlight, scroll-to-token, seek-to-token, jump) đều nói chuyện bằng token idx, không phải bằng chuỗi text.
5. **Cloud TTS (Azure neural) là lựa chọn của SwiftRead, nhưng không bắt buộc:** nếu port sang Seeless/desktop mà muốn offline thì dùng on-device TTS + `onRangeStart` (Android) / `boundary` event (Web Speech) / `willSpeakRange` (Apple AVSpeechSynthesizer) để lấy word timing — pattern WordPlayer + timepoints giữ nguyên, chỉ đổi nguồn timestamp.
6. **Jump theo giây + seek theo token:** Jump back/forward theo giây (đơn giản, dễ hiểu); click-to-jump theo token (từ). Không cần seek bar phức tạp.

> Lưu ý phương pháp: báo cáo này chỉ mô tả hành vi/pattern — không trích code decompile của SwiftRead. Tên class/hằng/string ngắn được nêu để làm bằng chứng, không copy logic chi tiết.

---

## 12. Tokens/quota/tính phí, giá Azure, list TTS tham khảo + tham chiếu chéo (bổ sung 24/11/2026)

### 12.1. Đếm token: một phép đếm phục vụ 3 việc — sync, quota, tính phí

Đúng như Manh hỏi: cách SwiftRead làm tính được luôn cả 3. Vì text được tokenize ngay từ đầu (xem §11.4) nên app biết chính xác mỗi part có bao nhiêu từ/token:

- **Sync:** timepoints map từng từ → mili-giây (§11.4).
- **Quota:** quota Free tính theo **số từ narration/ngày** — bằng chứng trong code: `TTS_WORDS_QUOTA_WARNING_THRESHOLD`, `FreeQuotaExceededError`, `useQuotaQuery`, `quota_limit_hit` (§11.8). Hết quota ngày thì chặn narration, không chặn đọc bằng mắt.
- **Tính phí API:** Azure tính tiền theo **ký tự** của mỗi request xử lý thành công (xem §12.2). SwiftRead đếm từ cho user nhưng trả tiền cho Azure theo ký tự — đổi đơn vị khoảng 5 ký tự/từ (tính cả khoảng trắng). Nhờ đếm token từ đầu, server biết trước mỗi part tốn bao nhiêu ký tự Azure trước khi gọi API, nên kiểm soát được chi phí theo từng user.

### 12.2. Azure AI Speech — tính phí hay free?

**Trả phí, nhưng có free tier vĩnh viễn.** Giá tra ngày 24/11/2026 từ trang giá chính thức của Microsoft (https://azure.microsoft.com/pricing/details/cognitive-services/speech-services/):

- **Free (F0): 500.000 ký tự neural/tháng, miễn phí vĩnh viễn** (reset ngày 1 mỗi tháng). Giới hạn: 20 request/60 giây, 1 request đồng thời, không dùng được batch synthesis, không gồm giọng Neural HD (dòng DragonHD).
- **Trả theo dùng (S0): $15 / 1 triệu ký tự** cho giọng neural chuẩn (real-time + batch); Neural HD $22/1M; gói cam kết xuống tới $7.50/1M ở lượng lớn.
- **Tính tiền theo ký tự** của mỗi request xử lý thành công.
- 500.000 ký tự/tháng ≈ 100.000 từ ≈ 6–12 bài báo dài — đủ cho dùng cá nhân/dev, không đủ cho sản phẩm free ở quy mô lớn.

Hệ quả cho TransPeek/Seeless: nếu sau này thêm cloud TTS thì đi theo hướng **BYOK** (user tự nhập key Azure của mình, tự trả tiền Azure; Manh không trả) — đúng như đã chốt trong plan Pro nội bộ. Free tier F0 đủ cho Manh tự dev/test giọng Azure mà không tốn tiền.

### 12.3. List TTS tham khảo của Manh (GitHub stars: tts-service)

Manh đã tổng hợp sẵn list này — lưu lại để dùng ở phiên thêm engine TTS offline (và tham khảo cloud): https://github.com/stars/TranManhTuanLabs/lists/tts-service (14 repo, đọc ngày 24/11/2026):

| Repo | Offline? | Ghi chú |
|---|---|---|
| HayaiApp/HayaiTTS | Có (Android) | Neural TTS hệ thống, 186 giọng qua sherpa-onnx (Piper/Kokoro/Kitten/Matcha/ZipVoice...) |
| sipeter/CloneTTS | Có (Android) | TTS nhẹ, clone giọng on-device |
| siva-sub/NekoSpeak | Có (Android) | TTS riêng tư, Kokoro/KittenTTS/Pocket-tts/Piper |
| k2-fsa/sherpa-onnx | Có (đa nền tảng) | STT/TTS/Diarization bằng onnxruntime, không cần mạng |
| debpalash/VoiceStudio | Có | ElevenLabs mã nguồn mở chạy local, clone giọng, 646 ngôn ngữ |
| pnnbao97/VieNeu-TTS | Có | TTS tiếng Việt, clone giọng tức thì, on-device, CPU real-time, 48kHz |
| 0xShug0/audio.cpp | Có | Engine C++ thuần (ggml): TTS/STT/VAD/voice conversion |
| souzatharsis/podcastfy | Cloud GenAI | Tạo podcast từ tài liệu (kiểu NotebookLM) |
| OpenBMB/VoxCPM | — | VoxCPM2 TTS đa ngôn ngữ, không cần tokenizer, clone giọng |
| dvchd/ViFastTts | Có (Win/mac/Linux/Web/Android) | App đọc tiếng Việt, mã nguồn mở, model có sẵn |
| bilibili/GPT-SoVITS | — | Clone giọng few-shot (1 phút audio mẫu) |
| tronghieuit/v-tts | — | TTS tiếng Việt nhẹ nhất, đa giọng, zero-shot clone |
| dogenthq/KorvaTTS | Có | TTS tiếng Việt ưu tiên, code-switching, ONNX Runtime |
| haocse/VietVoice-TTS | — | Thư viện TTS tiếng Việt + clone giọng |

**NỢ:** khi tới phiên thêm engine TTS offline thì đánh giá từng repo trong list này (chọn theo: chạy được trên mac/Windows, có word timing không, giọng Việt/Anh chất lượng, dung lượng model). Nếu cần thêm thì search toàn GitHub sau.

### 12.4. Kết hợp native + SwiftRead, hay chỉ theo 1 hướng giống SwiftRead?

**KẾT HỢP — không theo 1 hướng duy nhất.** Kiến trúc lấy từ SwiftRead, nguồn timestamp lấy từ native của từng nền tảng:

- **Lấy từ SwiftRead (kiến trúc, không phụ thuộc framework):** WordPlayer 1 interface + 2 driver (§11.4), tokenize trước + map chỉ số token (§11.4), part + timepoints + prefetch (§11.4), 1 WPM → playback rate có pitch correction (§11.5), jump theo giây + seek theo token (§11.7).
- **Lấy từ native (nguồn timestamp, theo nền tảng):** macOS dùng `AVSpeechSynthesizer willSpeakRangeOfSpeechString` — word-range miễn phí, offline, giọng hệ thống (xem `recommendation.md` §3). Windows WinRT không có word-boundary callback → highlight theo câu, hoặc cloud TTS trả speech marks nếu muốn tới từng từ (xem `recommendation.md` §3; `naturalreader-report.md` §5–§6: MP3 + speech marks qua header).
- **Vì sao không copy y xì SwiftRead:** SwiftRead phải dùng cloud vì nó là React Native — trong RN không có API word-timing miễn phí. TransPeek trên mac CÓ (AVSpeechSynthesizer), nên driver TTS trên mac dùng `willSpeakRange`, không cần Azure. Chỉ khi cần giọng cloud hay hơn giọng hệ thống (Pro BYOK) mới dùng Azure.
- **Vì sao không chỉ dùng native:** API native chỉ cho timestamp (biết đang đọc từ nào), không cho kiến trúc (token map, driver, part/prefetch). Không có kiến trúc thì lại rơi về lỗi cũ: mỗi chunk đọc riêng → giọng ngắt quãng.
- **Ghi chú về quyết định cũ:** `recommendation.md` (17/11) từng chốt "RSVP window CHỈ ĐỌC, không gồm TTS trong read" (đọc và nghe tách hẳn). Sau đó Manh duyệt "Speech with Fast Read + TTS sync-word component chung" (22/11). Pattern WordPlayer hòa giải được 2 quyết định này: đọc và nghe chung 1 engine + chung vị trí token, chỉ đổi driver — thêm nghe vào đọc không phải là "gắn TTS vào RSVP", mà là đổi driver của cùng 1 WordPlayer.

### 12.5. Tham chiếu chéo — các báo cáo liên quan (cùng thư mục)

- `speechify-report.md` §5 (highlight 2 lớp câu+từ bằng overlay rect, không sửa DOM), §6 (block → playable → câu), §8.4 (markCharIndex theo mốc thời gian cloud).
- `naturalreader-report.md` §4–§6 (highlight câu/từ 4 theme, speech marks, chunk 60 ký tự, word timer 50ms), §11 (khả thi tích hợp native).
- `rsvp-report.md` §1 (SwiftRead extension — đã đọc source thật .crx 6.11.2/5.9.2), §6 (khả thi tích hợp native RSVP).
- `recommendation.md` §3 (TTS tích hợp native: willSpeakRange mac, WinRT Windows), §5 (RSVP verdict), §8 (thứ tự triển khai).
- `envi-report.md` (panel dịch lite ENVI — liên quan panel, không liên quan word-sync).
- `panel-tabs-break-report.md` (multi-tab panel + break reminders — liên quan luồng đọc/nghỉ).
- Các báo cáo khác trong loạt TTS/read-along cũng tham chiếu ngược lại báo cáo này ở mục word-sync highlight — xem mục "Tham khảo chéo" cuối mỗi file.
