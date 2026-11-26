# Khuyến nghị chiến lược — TTS, Quick panel, RSVP, Multi-tab panel & Break reminders

**Ngày:** 16/11/2026 — Tổng hợp từ 5 báo cáo research riêng:
- `speechify-report.md` — Speechify 14.15.0.0 (TTS)
- `naturalreader-report.md` — NaturalReader 8.0.3.0 (TTS)
- `envi-report.md` — ENVI 1.1.6.0 (quick-translate panel)
- `rsvp-report.md` — RSVP speed reading (SwiftRead, jetzt, Sprint Reader)
- `panel-tabs-break-report.md` — Multi-tab panel + break reminders (wnr, tadama, pandan)

**Quy tắc chung:** chỉ học *pattern* (cách bố trí UI, luồng tương tác), tự viết lại code native. Không copy code, giọng đọc, endpoint hay dữ liệu từ điển proprietary của các extension.

## Cập nhật 17/11/2026 — những gì Manh đã chốt sau khi đọc bản này

- **Model A là hướng thực tế cho app native; Model B KHÔNG làm.** Ngay cả Speechify cũng chỉ Model B ở site quen (selector viết tay), trang lạ dùng Model A; NaturalReader cũng vậy. Native không có DOM/MutationObserver, quét cây Accessibility/UI Automation liên tục đắt CPU, icon không bám scroll.
- **Luồng vào RSVP — CHỐT (thứ tự ưu tiên):** (1) Option-click Mac / Alt-click Windows → RSVP thẳng; (2) chuột phải icon → menu "Đọc nhanh"; (3) nút "Đọc nhanh" trong panel dịch; (4) menubar/tray; (5) shortcut global chỉ là fallback. Cộng thêm Settings toggle đổi click → RSVP cho người dùng RSVP là chính.
- **Vị trí view đọc RSVP — GIỮ CẢ 2 PHƯƠNG ÁN, quyết ở lúc prototype:** (a) tab 2/3/4 dãn to như max snapback, hoặc (b) panel riêng. Nếu bản tab dãn đọc vẫn tập trung, không giật, không bị auto-hide phá thì làm tab; không thì chuyển panel riêng. Điều kiện bắt buộc nếu làm tab: **ẩn HOÀN TOÀN chức năng panel dịch khi đang đọc** (không chỉ ẩn giao diện mà vẫn bấm được), ẩn hết chrome dịch + hàng chấm, tắt swipe/lăn chuyển tab lúc đang đọc, tạm dừng auto-hide, cân nhắc căn giữa. Lý do giữ 2 hướng: tách ra tránh lag / lỗi đè chéo lên luồng dịch.
- **SwiftRead — ĐÃ ĐỌC SOURCE THẬT (17/11 ~02:30):** Manh gửi 2 file `.crx` (6.11.2.0 + 5.9.2.0). Phát hiện lớn: 3 chế độ Focus/Flow/Spotlight **không có trong source `.crx`** (nằm ở web app host); trong extension chỉ có 1 engine RSVP + toggle hiển thị. Engine legacy: WPM mặc định 275, max 2000, chunk 1–6, micro-pause hệ số nhân, ORP pivot = ký tự giữa, TTS cloud + timepoints server + poll 50 ms (chỉ khi chunk = 1), không có hạn mức ngày trong code. Chi tiết đã bổ sung vào `rsvp-report.md`. **4 kết luận cốt lõi không đổi.**
- **Layout 3 tab kiểu "hub" (Manh 10:33):** Dịch ở GIỮA làm mặc định (chấm 2), trái tab 1 shortcut (tạm thời, sau này thay được), phải tab 3 Fast Read (dự kiến). Lý do: Dịch ở giữa thì vuốt sang 2 bên đều 1 lần.
- **3 chấm hiện từ đầu để trải nghiệm (Manh 10:46):** thay điều kiện cũ "chấm 3 chỉ hiện khi tab có nội dung thật" — khung multi-tab lên main là hiện đủ 3 chấm luôn; tab 3 là placeholder cho tới khi Fast Read ship. Ngoại lệ này chỉ áp cho tab 3 Fast Read (đã có kế hoạch cụ thể), không áp chung cho mọi tab tương lai.
- **Thứ tự làm mới (Manh 10:46): khung multi-tab làm trên main TRƯỚC; nhánh `feature/fast-read-rsvp` sync main rồi mới làm Fast Read window.** Fast Read làm trước TTS (đã chốt 09:52).
- **Fast Read window copy y xì UX SwiftRead; CHỈ ĐỌC, không gồm TTS trong read (Manh 10:46).** SwiftRead có tính năng Listen (TTS cloud + timepoints) nhưng TransPeek KHÔNG copy phần đó vào view đọc — nghe là việc của TTS (click icon), đọc là việc của RSVP; 2 luồng tách hẳn.
- **Menubar mac dùng được submenu (Manh 12:06):** menubar chỉ có 1 hàng nhưng mỗi mục chính mở được list con của chính nó — nên tích hợp thêm menu Tomato/Focus/Fast Read là hoàn toàn khả thi, không sợ menu dài (mục mới nằm trong submenu, không thêm mục top-level). Áp cho cả luồng vào RSVP (mục menubar/tray) và tab timer sau này.
- **Thứ tự triển khai (§8) cập nhật theo các chốt trên** — khung multi-tab lên đầu, RSVP window ngay sau, TTS lùi xuống sau RSVP.

## Cập nhật 26/11/2026 — quy tắc bấm loa TTS + indicator loa tách riêng (Manh chốt, theo hành vi Speechify + NaturalReader)

- **1 nút loa = toggle Play/Pause, KHÔNG có nút Stop riêng.** Áp dụng giống nhau cho mọi unit (1 từ, 1 câu, 1 đoạn — chỉ khác độ dài). Phạm vi: loa click-to-listen (loa panel + indicator loa). Loa trong Read mode (bật/tắt tiếng khi đọc RSVP) là control riêng, giữ nguyên.
- **Chưa phát → bấm loa = play** từ đầu unit. **Đang phát → bấm = pause**, giữ nguyên vị trí từ/câu đang dừng. **Đang pause → bấm = resume** đúng chỗ dừng (không phát lại từ đầu). **Hết unit → stop tự động**: reset vị trí về đầu, gỡ highlight, ẩn indicator loa.
- **KHÔNG có cách dừng giữa chừng** (không nút Stop, không Esc — Manh chốt bỏ Esc 26/11 23:27): pause thì cứ kệ; khi indicator tự ẩn theo luật thường thì phiên kết thúc lặng lẽ.
- **Pause thì GIỮ NGUYÊN highlight** ở từ đang dừng (không gỡ như NaturalReader) — để user thấy đang dừng ở đâu, resume nhìn rõ.
- **Pause kết thúc khi indicator tự ẩn**: không có timeout riêng kiểu "sau 1 phút tự stop" — pause kéo dài được bao lâu tùy indicator còn hiện (hover vào indicator thì timer tạm dừng); indicator tự ẩn sau 5s không tương tác thì phiên kết thúc lặng lẽ. (Sửa 26/11: luật cũ "pause vô thời hạn" bỏ — vì indicator phải có đường tự ẩn, nếu không sẽ kẹt.)
- **Play mới thay play cũ**: bấm loa unit khác trong lúc đang phát/pause thì dừng cái cũ (kèm indicator cũ), phát unit mới từ đầu (auto-detect ON: hover block khác + click; OFF: select text mới + click). Bấm lại đúng unit đang pause thì resume. Chỉ bấm loa mới mới hủy phiên cũ — select/hover text mới chỉ hiện icon float mới, phiên cũ vẫn chạy (không chồng tiếng vì chỉ có 1 phiên tại 1 thời điểm).
- **Indicator loa TÁCH RIÊNG khỏi icon float (CHỐT 26/11 23:59)**: 2 phần tử độc lập, mỗi cái tự quản lifecycle của mình. Icon float lifecycle bình thường mọi lúc (auto-hide 5s, dismiss khi block trôi, hover/select mới hiện ở chỗ mới) — không bao giờ bị phiên loa ghim hay chặn. Indicator là phần tử nổi riêng, hiện ở đúng chỗ user bấm loa (vị trí tự nhiên, không bám theo text), hiện ⏸ lúc đang phát / ▶ lúc đang pause, bấm để pause/resume. Hiện trong lúc ĐANG PHÁT; lúc ĐANG PAUSE thì tự ẩn sau 5s (hover vào thì timer tạm dừng), ẩn thì phiên kết thúc lặng lẽ; resume được trong lúc còn hiện.
- **Biểu tượng theo trạng thái** (CHƯA CÓ — làm khi triển khai): nút loa panel + indicator loa đổi biểu tượng theo trạng thái (chưa phát: loa thường; đang phát: ⏸; đang pause: ▶). Icon float KHÔNG hiện trạng thái phát nhạc nữa. Hiện tại (26/11): panel chỉ có 2 dạng loa, icon float chỉ có 1 dạng loa cho cả phiên phát, code vẫn ghim icon lúc đang phát/pause + chặn hover lúc đang phát (sẽ bỏ khi làm indicator).
- Spec đầy đủ (nguồn chính): `docs/FEATURES/SPEECH_PLAYER.md` §1 (gồm mục indicator loa tách riêng); icon float: `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` (§4 auto-hide, §8 stale — đã bỏ mọi ngoại lệ lúc đang phát). Đã báo sang repo Windows để làm theo (26/11 22:23); cập nhật tách indicator báo tiếp sau commit này.

---

## 1. Kết luận tổng — Path HỖN HỢP (không phải thuần 1 hay thuần 2)

**Khuyến nghị: Path 1 cho phần lớn tính năng + Path 2 chỉ cho riêng Model B.**

| Tính năng | Đường đi | Lý do ngắn gọn |
|---|---|---|
| TTS đọc to (click icon → nghe), highlight câu/từ | **Path 1 — tích hợp native** | macOS `AVSpeechSynthesizer` cho word-range miễn phí; Windows dùng WinRT TTS + highlight theo câu (hoặc cloud TTS có speech marks nếu muốn highlight theo từ). |
| Model A: hover block text → hiện icon loa | **Path 1 — tích hợp, có giới hạn** | Hit-test qua Accessibility (mac) / UI Automation (Windows) khả thi; chỉ tốt ở app expose text, cần quyền Accessibility + track chuột toàn cục, giữ flow bôi chọn làm fallback. |
| Quick panel (ENVI-style): hover → panel nhỏ chỉ có bản dịch | **Path 1 — tích hợp** | Quyết định sản phẩm chuyển trực tiếp; chỉ cần viết lại phần bắt từ-dưới-con-trỏ và định vị panel bằng API native. |
| Điều chỉnh nhanh khi đang phát (tốc độ/giọng) | **Path 1 — tab 2/3 của panel** | Xem §6. |
| RSVP đọc nhanh | **Path 1 — tích hợp native; view đọc = WINDOW RIÊNG (Manh chốt 09:52 + 10:46), UX copy y xì SwiftRead, chỉ đọc không TTS** | Engine RSVP là logic thuần nhỏ, port sang Swift/C# dễ; capture text dùng pipeline selection sẵn có. Tab panel chỉ là thử nghiệm sau (xem §5). |
| Multi-tab panel (chấm tròn) | **Path 1 — tích hợp, tối đa 3 tab** | Pattern đơn giản, API cử chỉ công khai cả 2 nền tảng. |
| Timer nhắc nghỉ mắt/Pomodoro | **Path 1 bản NHẸ trong tab panel, hoặc dùng app riêng** | Xem §5. Không tích hợp full break-app. |
| **Model B: icon hiển thị sẵn trong mọi block text (không cần hover)** | **KHÔNG LÀM (Manh chốt 17/11)** | Quét liên tục cây Accessibility/UI Automation đắt, không có MutationObserver/scroll notification, icon không tự bám scroll; chỉ trong DOM web mới thực tế — và ngay cả Speechify cũng chỉ làm Model B ở site quen có selector viết tay, trang lạ dùng Model A. |

**Không nên làm extension chỉ vì Model B ngay bây giờ** — Model B là tính năng duy nhất bắt buộc extension, mà nó chỉ là "tiện hơn một chút" so với Model A. Thứ tự ưu tiên: làm tốt Path 1 trước (TTS + Model A + Quick panel + RSVP + tab panel), rồi mới cân nhắc extension Edge/Chrome cho Model B khi app native đã ổn định. Làm extension sớm = gánh thêm 1 codebase, 1 quy trình phát hành (Web Store review), 1 bề mặt bảo trì — trong khi giá trị nó mang lại (icon hiện sẵn) chưa chứng minh là deal-breaker.

---

## 2. Verdict Model B (icon hiển thị sẵn) — native vs website

**Kết luận: website-only trong thực tế; native là feasible-with-limitations nặng, không nên làm.**

Bằng chứng từ source:
- **Speechify:** Model B chỉ tồn tại trên các site đã biết trước (selector viết tay cho ChatGPT, Gmail, Facebook, LinkedIn, Reddit, X, YouTube, Google Search…) qua MutationObserver, và trên PDF (1 pill/document). Trên trang web bất kỳ, Speechify **không** hiện sẵn icon cho mọi block — nó dùng Model A (hover paragraph >10 từ → icon tròn trắng bên trái dòng đầu, tính bằng DOM Range + `getBoundingClientRect`, chống che khuất bằng `elementFromPoint`).
- **NaturalReader:** Model B cũng chỉ trong 3 app riêng (ChatGPT, Gmail, Outlook) bằng selector riêng; cơ chế chính là selection-triggered (bôi chọn → icon play ở vị trí chuột, tự ẩn sau 3 giây, tối thiểu 20 ký tự).
- **ENVI:** không có Model B ở đâu cả — tooltip dịch hiện thẳng khi hover (không icon), flow từ điển dùng icon-sau-bôi-chọn (Model A).

Vì sao native không làm được Model B tử tế:
1. **Không có DOM để quét:** web có MutationObserver báo thay đổi + scroll event; native phải quét lại toàn bộ cây Accessibility/UI Automation theo chu kỳ — đắt CPU, chậm, và không biết khi nào app đích đổi nội dung.
2. **Icon không bám scroll:** trong DOM, icon là phần tử trong trang nên cuộn theo nội dung; native phải dùng floating window riêng và tự poll vị trí block để bám theo — trễ, giật, sai khi app đích cuộn mượt.
3. **App không expose text thì mù hoàn toàn:** text vẽ custom (Canvas), ảnh chứa text, Electron với cây Accessibility thô — không lấy được vị trí dòng để đặt icon.
4. **Z-order và focus:** cửa sổ nổi của TransPeek phải luôn ở trên app khác nhưng không được cướp focus/click — làm được nhưng mong manh theo từng app.

**Model A thì khác — native-feasible với giới hạn:** khi chuột hover, hit-test 1 điểm (`AXUIElementCopyElementAtPosition` trên mac, `IUIAutomation.ElementFromPoint` trên Windows) + lấy rect của dòng (`AXBoundsForRange` / `TextPattern.GetBoundingRectangles()`), đặt icon nổi gần đó, debounce ~150 ms, poll rect trong lúc hiện để bám scroll. Cần quyền Accessibility (mac) và hook chuột toàn cục; chỉ tốt ở app expose text; luôn giữ flow bôi-chọn-hiện-icon làm fallback. Lưu ý: analogy với con trỏ I-beam không chuyển trực tiếp được — I-beam do chính app đích tự đổi, còn TransPeek phải hit-test từ bên ngoài.

---

## 3. TTS — tích hợp như thế nào (Path 1)

**Nên tích hợp vào app native.** Những gì học được:

- **Player:** học Speechify/NaturalReader — điều khiển nằm ngay trong player (minibar/side panel), không popup rời: play/pause, nhảy câu trước/sau, thanh tiến trình, tốc độ, chọn giọng.
- **Highlight khi đọc:** NaturalReader bọc mỗi câu trong span + 2 lớp highlight (câu + từ), auto-scroll `scrollIntoView`. Trên macOS làm tốt hơn cả extension nhờ `AVSpeechSynthesizer willSpeakRangeOfSpeechString` (word-range miễn phí). Trên Windows, `SpeechSynthesizer` WinRT **không có** word-boundary callback → highlight theo câu, hoặc dùng cloud TTS trả speech marks (kiểu NaturalReader: MP3 + speech marks qua header) nếu muốn highlight theo từ — cần spike kiểm chứng trước khi chốt.
- **Giọng đọc:** tầng miễn phí = giọng hệ thống (Web Speech API bên extension; `AVSpeechSynthesizer` / WinRT bên native). Giọng cloud chất lượng cao (Azure, giọng riêng) là backend trả phí của họ — TransPeek không copy được; nếu muốn giọng hay hơn giọng hệ thống thì phải tự tích hợp một cloud TTS (Azure/Google) + tự trả phí, hoặc chấp nhận giọng hệ thống ở v1.
- **Chunking:** tách câu → chẻ câu dài >500 ký tự theo dấu câu → gom chunk 50–250 ký tự; preload vài câu trước/sau. Logic này port thẳng sang Swift/C#.
- **Tốc độ:** NaturalReader dùng WPM 50–900 (mặc định 180); Speechify slider 0.4x–4.5x (free cap 1.5x). TransPeek nên dùng hệ số tốc độ (0.5x–2x) cho dễ hiểu, preset xem §6.

---

## 4. Quick panel (ENVI) — tích hợp như thế nào (Path 1)

**Nên tích hợp.** ENVI chứng minh concept "Quick panel / instantly translate" là đúng:
- Bubble nhỏ (~200px, chỉ có bản dịch, không nguồn/pronunciation/ví dụ/nút), bám theo chuột, `pointer-events: none` (click xuyên qua), tự biến mất khi chuột rời đi — không nút đóng, không Esc, không timeout.
- Trigger: hover poll 700 ms + bắt từ/câu dưới con trỏ (`caretRangeFromPoint`); chuột phải di chuyển >3px 2 lần mới kích hoạt (chống trigger nhầm).

Phần phải viết lại native: bắt từ-dưới-con-trỏ bằng AX hit-test + `AXBoundsForRange` (mac) / `TextPattern.RangeFromPoint` (Windows) — không có `Range.expand("sentence")` như DOM; định vị panel tự lật mép (không có Popper.js — tự code); khi cuộn thì **ẩn panel** thay vì bám theo (ENVI cũng không bám scroll, chỉ sống tối đa 1 tick 700 ms sau khi cuộn). Giới hạn cứng: app không expose text qua Accessibility/UI Automation thì không có hover Quick panel — fallback là flow bôi chọn hiện tại.

Lưu ý: ENVI không bundle dữ liệu từ điển — nghĩa tra qua API `en.jpdictionary.com`, dịch qua Google Translate không chính thức. TransPeek dùng provider dịch của mình, không đụng vào đó.

---

## 5. RSVP — verdict tích hợp + flow 1 icon + vị trí + mobile

**Verdict: TÍCH HỢP vào TransPeek native (Path 1), panel đọc RIÊNG.**

- Engine RSVP là logic thuần nhỏ (parser của jetzt ~250 dòng, port sang Swift/C# dễ); render 1 từ/lần bằng Text native với ORP highlight; timing WPM bằng timer hệ thống; capture text dùng pipeline selection sẵn có; PDF qua PDFKit (mac) / Windows.Data.Pdf (Windows); ePub unzip+parse. Chỉ "auto-extract cả trang web" và Kindle/Libby là browser-only — ngoài scope v1.
- **Flow 1 icon, 3 chức năng — giữ hover = dịch, click = nghe (TTS). RSVP vào theo thứ tự MANH CHỐT 17/11:** (1) Option-click Mac / Alt-click Windows → RSVP thẳng; (2) menu chuột phải trên float icon ("Đọc nhanh"); (3) nút "Đọc nhanh" trong panel dịch; (4) mục menubar/tray — menubar mac mở được submenu nên mục Fast Read nằm trong list con, không làm dài menu chính (Manh 12:06); (5) 1 global shortcut duy nhất chỉ là fallback. Cộng thêm Settings toggle đổi click → RSVP thẳng (cho người dùng RSVP là chính). **Loại:** middle-click (không có trên trackpad Mac và hầu hết touchpad laptop Windows), long-press (đụng thao tác kéo icon), chooser hiện mỗi lần click (thêm ma sát cho 2 flow chính).
- **Vị trí reading view — WINDOW RIÊNG là hướng chính (Manh chốt 09:52 + 10:46).** Báo cáo khuyên panel riêng: panel dịch (~400px) quá nhỏ cho từ RSVP 50–110px; panel riêng tránh chuyển tab nhầm giữa lúc đọc và đủ chỗ cho điều khiển WPM/chunk/seek. **Tab panel chỉ là thử nghiệm sau** — nếu làm thì phải **ẩn HOÀN TOÀN chức năng panel dịch** khi đang đọc (không chỉ ẩn giao diện mà vẫn bấm được), ẩn hết chrome dịch + hàng chấm, tắt swipe/lăn chuyển tab, tạm dừng auto-hide, cân nhắc căn giữa. **UX window copy y xì SwiftRead** (cửa sổ riêng, ORP pivot, context ±150 từ khi pause, điều khiển WPM/chunk/seek — xem `rsvp-report.md` §1/§6.1); **chỉ đọc, KHÔNG gồm TTS trong read** — nghe là việc của TTS (click icon), đọc là việc của RSVP, 2 luồng tách hẳn (SwiftRead có Listen nhưng TransPeek không copy phần đó).
- **Shortcut budget: chỉ 1 global shortcut** (mở RSVP từ selection/clipboard); mọi phím trong lúc đọc (Space, ←/→, ↑/↓…) chỉ active khi panel đọc đang focus — 0 xung đột global. Không tách RSVP thành app/extension riêng.
- **Mobile: KHÔNG làm bây giờ.** Thị trường app RSVP mobile đã đông và nặng subscription (Spreeder, Outread, Reedy, Spritz, SwiftRead); lợi thế cốt lõi của TransPeek (float icon trên text của app khác) không tồn tại trên mobile — capture chỉ qua share-sheet/clipboard, panel đọc thành full-screen. Xem lại chỉ sau khi RSVP desktop chứng minh có người dùng.

---

## 6. Điều chỉnh nhanh khi đang phát — tab 2/3 của panel (không làm control rời)

**Khuyến nghị: ý tưởng của Manh — hover icon loa khi đang phát → mở tab 2/3 của panel với chỉnh nhanh — là đúng, nên làm theo hướng này.**

- Speechify và NaturalReader đều đặt speed/voice **ngay trong player đang phát** (Speechify: route `/speed` slider 0.4x–4.5x + `/voices` picker có search/favorite/preview, 1 tap; NaturalReader: nút Speed mở slider WPM + nút Voices trong minibar/side panel). Không ai dùng control rời hay bắt mở Settings.
- TransPeek không có player thường trực như họ, nên "tab 2/3 của panel" chính là bản native của cùng một ý: **speed presets 1x / 1.2x / 1.5x / 2x** (dạng nút bấm nhanh, không slider — nhanh hơn Speechify), **chọn giọng**, **autoswitch voice phát hiện 2 ngôn ngữ** (không thấy trong source Speechify/NaturalReader — phải tự làm: detect ngôn ngữ theo câu rồi đổi giọng; ghi rõ là tính năng tự phát triển, cần spike).
- Lưu ý từ Speechify §8.2: đừng làm loãng ý nghĩa "click = nghe" — tab chỉnh nhanh mở bằng **hover icon khi đang phát** (không phải click), đúng như Manh đề xuất; click vẫn là play/pause.

---

## 7. Multi-tab panel + break reminders

**Chấm tròn: NÊN LÀM, tối đa 3 tab.** Chấm là chỉ báo vị trí, không phải điều hướng chính (Apple HIG) nên discoverability thấp — luôn có đường khác: icon "?" ở Tab 1 → Tab 2, nút quay lại, click chấm, phím ←/→. **Layout kiểu "hub" (Manh chốt 10:33): Dịch ở GIỮA làm mặc định (chấm 2), trái tab 1 shortcut (tạm thời, sau này thay được), phải tab 3 Fast Read (dự kiến).** **3 chấm hiện từ đầu để trải nghiệm (Manh 10:46)** — thay quy tắc cũ "chỉ tạo chấm khi tab có nội dung thật": khung multi-tab lên main là hiện đủ 3 chấm luôn, tab 3 là placeholder cho tới khi Fast Read ship (ngoại lệ này chỉ áp cho tab 3 Fast Read đã có kế hoạch cụ thể). Footer đáy cố định 24–28px, chấm active dạng pill 16–20px, hit-target ≥24×24px, tooltip tên tab, chuyển tab giữ nguyên kích thước panel.

- **Mac:** swipe ngang 2 ngón là chính (ngưỡng ~50px, |dx| > 2×|dy|, chỉ nhận khi bắt đầu ở header/footer để tránh nhảy tab khi cuộn dọc) + click chấm + phím mũi tên. API công khai (`NSPanGestureRecognizer`/`NSEvent`), không cần private framework.
- **Windows:** click chấm là chính; hover + lăn bánh xe là phụ (1 nấc 120 delta → 1 tab, debounce 300 ms, có công tắc tắt trong Settings), dùng `PointerWheelChanged`; hàng chấm đặt ngoài `ScrollViewer` để event không bị nuốt. Nếu test thấy lăn nhầm nhiều thì tắt mặc định.

**Break apps — KHÔNG tích hợp, dùng riêng (đã chốt, research xác nhận).** Phổ cưỡng chế: Pandan (nhẹ nhất — chỉ hiện thời gian dùng máy ở menubar, nhắc nhẹ qua notification/HUD, không ép; macOS 26+, miễn phí) → tadama (Pomodoro 25/5, cửa sổ nghỉ lớn che gần hết màn hình, tự nhảy về sau 30s nếu bị dời; Mac-only) → wnr (nghiêm nhất — fullscreen focus mode chặn cả virtual desktop lẫn mọi màn hình, tắt được cancel/skip/stop; Electron, MPL-2.0; Win/Mac/Linux — lựa chọn duy nhất trong 3 app có bản Windows). Gợi ý nhanh: Mac muốn nhẹ → Pandan; Pomodoro hơi ép → tadama; ép nghỉ thật / cần Windows → wnr.

**Timer — EITHER dùng app riêng, OR tích hợp với KHÔNG thêm icon.** Phương án A (2 menubar/tray icon song song) làm được kỹ thuật (nhiều `NSStatusItem`; nhiều `Shell_NotifyIcon`) nhưng UX tệ: menubar đã dài, icon thứ 2 dễ bị notch che (Mac) / rơi vào overflow (Windows), thứ tự không ổn định. Phương án B (1 icon đổi/gộp trạng thái) cũng làm được nhưng đếm ngược không đọc được ở icon 22px và dễ gây nhầm. **Khuyến nghị: mặc định dùng app riêng; nếu tích hợp thì chỉ bản NHẸ trong tab 2/3 của panel** — notification hệ thống tự tắt, có snooze, không khóa máy, không che màn hình; 2 chế độ 20-20-20 và Pomodoro 25/5; mặc định TẮT; chỉ đếm khi máy hoạt động. **Không thêm icon menubar/tray thứ 2 và không thêm mục top-level mới vào menu chính; mục mới (Tomato/Focus/Fast Read) nằm trong submenu — menubar mac mở được list con từ 1 mục chính (Manh 12:06), nên tích hợp thêm là khả thi, không sợ menu dài.**

Thứ tự làm: (1) khung multi-tab 3 chấm kiểu hub trên main (Dịch giữa mặc định, trái shortcut, phải Fast Read placeholder); (2) tab timer bản nhẹ sau (nếu Manh vẫn muốn); (3) không làm: app nhắc nghỉ đầy đủ, icon menubar/tray thứ 2, icon gộp trạng thái thường trực.

---

## 8. Thứ tự triển khai (cập nhật 17/11 theo chốt của Manh — khung multi-tab trước, RSVP window sau, TTS lùi xuống)

1. **Khung multi-tab trên main** (layout hub 3 chấm: Dịch giữa mặc định, trái shortcut, phải Fast Read placeholder) — làm trước, để nhánh sync về.
2. **RSVP window** (nhánh `feature/fast-read-rsvp` sync main rồi làm; UX copy y xì SwiftRead, chỉ đọc không TTS; luồng vào đã chốt 17/11: Option/Alt-click → chuột phải icon → nút trong panel dịch → menubar/tray → shortcut global fallback + toggle đổi click).
3. **TTS click-to-listen** (giọng hệ thống + highlight câu; mac word-highlight miễn phí qua AVSpeechSynthesizer; Windows spike highlight từ trước).
4. **Quick panel** (Settings toggle; hover block → bubble nhỏ chỉ có bản dịch; ẩn khi cuộn).
5. **Model A hover icon** (hit-test AX/UIA; debounce; fallback bôi chọn).
6. **Tab chỉnh nhanh khi đang phát** (tab 2/3: preset tốc độ, chọn giọng, autoswitch 2 ngôn ngữ).
7. **Timer nhẹ** trong tab panel (mặc định TẮT) — hoặc bỏ qua, dùng Pandan/tadama/wnr riêng.
8. **Sau cùng, nếu cần: extension Edge/Chrome riêng** chỉ để làm Model B (icon hiện sẵn trong trang web) — cân nhắc lại sau khi app native ổn định.

---

## 9. Rủi ro & giới hạn cần nhớ

- Mọi tính năng hover (Model A, Quick panel) đều **chỉ tốt ở app expose text** qua Accessibility/UI Automation; app vẽ custom/Canvas/ảnh-text/Electron thô sẽ không hỗ trợ — phải nói rõ trong UI/Settings, không hứa hẹn chung chung.
- Windows highlight theo từ cần spike (WinRT không có word callback); đừng chốt UI highlight-từ trên Windows trước khi spike xong.
- Autoswitch voice 2 ngôn ngữ chưa có mẫu trong các extension đã đọc — tự thiết kế + spike.
- Các ngưỡng cử chỉ (swipe 50px, wheel 120 delta, debounce 300 ms) là điểm khởi đầu để test bằng prototype, chưa kiểm chứng.
- SwiftRead .crx **đã đọc được source thật từ 17/11** (Manh gửi 2 file 6.11.2.0 + 5.9.2.0) — xem ghi chú ở đầu file và `rsvp-report.md`. Sprint Reader .crx vẫn chưa tải được (proxy chặn endpoint Web Store, mirror 404) nhưng đủ qua GitHub open source.

---

## Tham khảo chéo — báo cáo liên quan (TTS word-sync highlight)

- `swiftread-apk-read-tts-report.md` §11.10 + §12.4 — verdict kết hợp: kiến trúc WordPlayer + token map của SwiftRead (phân tích binary APK 1.10.3) + timestamp native theo nền tảng; §12.2 giá Azure, §12.3 list TTS tham khảo của Manh.
- `speechify-report.md` §5 — highlight 2 lớp câu+từ bằng overlay rect (không sửa DOM), §6 (block → playable → câu).
- `naturalreader-report.md` §4–§6 — highlight câu/từ 4 theme, speech marks, chunk 60 ký tự, word timer 50ms.
- `rsvp-report.md` §1 + §6 — engine RSVP SwiftRead (đã đọc source thật .crx), khả thi tích hợp native.
