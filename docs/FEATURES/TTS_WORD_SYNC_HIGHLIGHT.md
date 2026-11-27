# TTS Word-Sync Highlight — highlight từ/câu theo giọng đọc (bản nháp)

> Trạng thái: **bản nháp** — spec, CHƯA LÀM. Mac làm trước, Windows theo sau (Manh 27/11 01:35, ghi spec cho highlight word/sentence sync, 2 repo).
>
> Ý tưởng: khi giọng đọc tới đâu thì chữ sáng tới đó — từ đang đọc highlight một màu, câu đang đọc highlight một màu khác — để mắt theo kịp tai. Học theo NaturalReader (bọc câu trong span + 2 lớp highlight câu/từ, auto-scroll) và Speechify, làm bằng API native.

## 1. Phạm vi — 1 component chung cho Reader RSVP (Full + Lite + Nghỉ)

**Tên gọi (Manh 2026-11-27): "Reader RSVP" (trình đọc RSVP).** Cửa sổ Full + panel Lite + cửa sổ Nghỉ đều là các mặt của cùng 1 trình đọc RSVP — cùng 1 engine (`RSVPEngine`) + cùng 1 ViewModel (`RSVPViewModel`), chỉ khác chỗ hiển thị. Tên "Fast Read" trên giao diện (menu, Settings) giữ nguyên — đó là tên tính năng người dùng thấy; "Reader RSVP" là tên khái niệm trong docs/code. Trình đọc file local (PDF/doc/TXT/MD, bước 3) sau này cũng là 1 mặt của cùng Reader RSVP này, không phải trình đọc khác.

- **Làm:** highlight từ đang đọc + câu đang đọc theo giọng, trong 3 bề mặt đọc RSVP — **Full window** (Style 1 RSVP Focus + Style 2 Basic Reading), **Lite panel** (CompactReadingView) và **cửa sổ Nghỉ** — bằng **1 component chung**, không làm 2–3 bản. Component này giữ trạng thái "từ hiện tại + câu hiện tại" và các bề mặt chỉ render lại từ cùng một trạng thái đó.
- **Overlay trên trang đã có sẵn — tham chiếu, KHÔNG làm lại:** khi nghe trên trang (chaining, đọc nối tiếp), `ReadingIndicatorOverlay` (`Sources/UI/ReadingIndicator/ReadingIndicatorOverlay.swift`) đã highlight câu (tím nhạt Speechify) + từ (chàm Speechify) theo giọng, qua `ContinuousSpeakController` + `onWordRange`. Spec này chỉ định nghĩa highlight cho **bề mặt Read**; overlay trên trang giữ nguyên, không sửa, không làm bản thứ hai.
- **Kiến trúc highlight (Manh 2026-11-27): 1 mô hình chung + 2 cách vẽ riêng.** Highlight trong Reader RSVP và highlight overlay trên trang (bước 2, đọc nối tiếp) **dùng chung mô hình** — cùng 1 trạng thái (từ/câu/cụm/block nào đang đọc), cùng bảng màu + các lớp (đã chốt theo Speechify — xem §2), cùng luật (pause thì giữ highlight, hết unit thì gỡ). Nhưng **cách vẽ tách riêng**, vì 2 chỗ vẽ khác nhau về bản chất:
  - Reader RSVP: chữ là của mình, tự vẽ chữ nên tô highlight trực tiếp lên chữ được — chính xác, không cần AX, không cần cửa sổ overlay.
  - Overlay trên trang: chữ là của app khác (Safari/Chrome/Preview...), không sửa được chữ của họ nên phải vẽ 1 cửa sổ overlay trong suốt đè lên trên, vị trí lấy qua AX (rect — xem khái niệm ở §3). Rect có thể lệch/thiếu tùy app, phải ẩn khi cuộn và lấy lại rect.
  Hệ quả: **trải nghiệm giống nhau** (cùng màu, cùng luật pause/hết — người dùng chỉ thấy highlight đi theo giọng, không phân biệt là trong Reader hay trên app khác); **trình bày nhìn giống nhau** (cùng màu, cùng lớp) nhưng **độ chính xác khác nhau** (trong Reader luôn chính xác vì chữ của mình; trên app khác phụ thuộc AX). Khi làm highlight cho trình đọc file local (bước 3) thì nối vào mô hình chung này, không viết hệ highlight mới.
- **Ngoài phạm vi:** PDF/file reader (Step 3, làm sau, riêng — nhưng khi làm thì là 1 mặt của Reader RSVP, dùng chung mô hình highlight ở trên, không phải trình đọc khác); highlight trên panel dịch (panel dịch là chỗ xem bản dịch, không phải chỗ nghe-đọc theo giọng); highlight trên icon float (icon không hiện trạng thái phát nhạc — xem `SPEECH_PLAYER.md` §1).

## 2. Hành vi — luật highlight (CHỐT theo luật loa)

- **Từ hiện tại highlight chàm Speechify, câu hiện tại highlight tím nhạt Speechify** — đúng 2 màu đã dùng ở overlay trên trang, để mắt user không phải học lại 2 bộ màu. Màu lấy từ Settings **"Highlight colors"** (6 lớp) — **không hardcode màu mới trong spec này**. Màu mặc định hiện tại: từ `#5666F0`, câu `#ABB3FE` (đoạn `#BFF2B3`, cụm `#FFC2D1`, vạch dọc `#8CBFFF`, gạch chân `#5666F0` — 4 lớp này chỉ dùng ở overlay trên trang, không dùng trong Read).
- **Pause thì GIỮ NGUYÊN highlight ở từ đang dừng** (không gỡ như NaturalReader) — cùng luật với `SPEECH_PLAYER.md` §1: để user thấy đang dừng ở đâu, resume nhìn rõ. Highlight chỉ gỡ khi phiên kết thúc.
- **Hết unit thì gỡ highlight** — đọc hết đoạn/bài thì reset vị trí về đầu, gỡ highlight (cùng luật "hết unit → stop tự động" ở `SPEECH_PLAYER.md` §1).
- **Highlight đi theo giọng (follow):** khi giọng sang từ ở slide/dòng khác thì focus + highlight chuyển theo tới slide/dòng chứa từ đó (auto-scroll/follow, không để highlight chạy ra ngoài màn hình). Style 1: chuyển slide chứa từ; Style 2: chuyển dòng chứa từ.
- **Resume thì highlight tiếp tục từ chỗ dừng** — không phát lại từ đầu, không highlight lại từ đầu; vị trí từ/câu được giữ như vị trí phát lại của `speakContinuous` (xem §3).
- **Tắt loa (speaker OFF) thì không highlight** — Read chạy bằng đồng hồ WPM im lặng thì chỉ có focus RSVP (chữ cam ORP pivot) như hiện tại, không thêm highlight từ/câu.

## 3. Cơ chế (mac) — dùng sẵn `speakContinuous` + `onWordRange`

Hiện trạng code (đã đọc, khớp thực tế):

- `RSVPViewModel.startTTSPlaybackTask()` (Style 1) và `startStyle2TTSPlaybackTask()` (Style 2) trong `Sources/FastRead/RSVPView.swift` đã gọi `ttsCoordinator.speakContinuous(utteranceText, language:)` với callback `onWordRange`. Callback này **đã map được word range → từ toàn cục → slide/dòng chứa từ** (qua `utteranceRanges` + `engine.slides` / `style2LineStartWordIndices) và đã dịch focus theo từ (`currentSlideIndex` / `style2CurrentLineIndex`). **Chưa có highlight trực quan từ đang đọc trong slide/dòng** — callback hiện chỉ đổi focus, chưa vẽ highlight.
- Trong slide/dòng, view hiện chỉ render từ đang đọc dạng RSVP (chữ lớn + ký tự ORP pivot màu cam `#f6861f`) — đó là **focus RSVP, không phải highlight word-sync**. Highlight word-sync là lớp phủ thêm (nền màu) trên từ/câu trong phần text đang đọc, khác với chữ cam ORP.

Cách làm (mac):

- **Dùng sẵn callback `onWordRange`**, không thêm API TTS mới: macOS cho word-range miễn phí qua `AVSpeechSynthesizer willSpeakRangeOfSpeechString` (xem `recommendation.md` §3). Mỗi lần callback bắn, component chung cập nhật (a) từ hiện tại (range của từ trong text gốc) và (b) câu hiện tại (câu chứa từ đó, tách theo cùng cách tách câu của overlay — xem `ContinuousSpeakController.sentenceRanges`).
- **1 trạng thái chung, các bề mặt render:** trạng thái "từ hiện tại + câu hiện tại" sống trong `RSVPViewModel` (chủ của cả Full + Lite + Rest window), các view chỉ đọc trạng thái đó để vẽ highlight. Không làm 2–3 bộ trạng thái riêng (tránh lệch nhau khi chuyển bề mặt).
- **Khi provider không có word-range thì chỉ highlight theo câu/slide:** `speakContinuous` đã có fallback này — nếu provider không hỗ trợ word tracking thì không có range nào được báo, caller chỉ dịch chuyển khi utterance kết thúc (xem comment trong `TTSCoordinator.speakContinuous`). Khi đó highlight từ tắt (không có từ để highlight), chỉ highlight câu/slide hiện tại theo nhịp utterance. **Không bịa range, không ước lượng thời gian từ** — không có range thì không highlight từ.
- **Highlight là lớp nền (background), không sửa text:** vẽ nền màu sau chữ (như overlay trên trang vẽ fill sau text), không chèn tag/sửa DOM (không có DOM để sửa — native khác extension ở điểm này), không đổi màu chữ (trừ ký tự ORP pivot cam đã có sẵn).

### Khái niệm cần biết

- **Rect (khung hình chữ nhật):** vị trí chính xác của 1 từ/câu/cụm trên màn hình — gồm tọa độ x, y (góc trái-trên) + chiều rộng + chiều cao. Muốn tô highlight lên 1 từ thì phải biết chính xác rect của từ đó; không biết rect thì không tô đúng chỗ được, dù biết giọng đang đọc tới từ nào.
- **AX (Accessibility):** bộ công cụ của macOS cho phép app mình hỏi app khác "đoạn text này nằm ở khung nào trên màn hình?" — qua `AXBoundsForRange` (xem `HoverBlockText.bounds(for:in:)`). Bên Windows, công cụ tương đương là UIA (`TextPattern.GetBoundingRectangles()`). AX là cách duy nhất trên macOS để lấy khung của từ/câu/cụm trong app khác (Safari, Chrome, Preview, Word...).
- **Speech marks / timepoints:** mốc thời gian từng từ do dịch vụ TTS cloud trả về — cho biết từ nào bắt đầu/kết thúc lúc nào trong audio. Đây là cách biết giọng đang đọc tới từ nào khi dùng giọng cloud (không có word-range trực tiếp như giọng hệ thống). Azure AI Speech gọi là "timepoints"; NaturalReader gọi là "speech marks" (audio + marks, poll mỗi 50 ms).
- **Vì sao phải thử trên từng app:** không phải app nào cũng trả rect từ đúng. Có app trả khung từ khá chuẩn; có app chỉ trả một phần — có lúc trả khung của cả đoạn thay vì từng từ, hoặc không trả gì. Nên khi làm overlay trên trang (bước 2) phải thử thực tế trên từng app (Word/Edge/Chrome...): app nào cho rect từ chính xác thì mới vẽ highlight từ trên app đó được; app nào không cho thì rơi về chỉ tô cả đoạn.
- **Mac khác Windows ở điểm này:** macOS cho word-range **miễn phí** qua delegate `AVSpeechSynthesizer willSpeakRangeOfSpeechString` — giọng hệ thống đang đọc tới từ nào thì biết ngay, không cần spike (xem cách làm ở trên). Windows không có tương đương (WinRT `SpeechSynthesizer` không có word-boundary callback) nên bên Windows muốn highlight theo từ thì cần spike cloud TTS trả speech marks (xem §6). Nói cách khác: trong Reader RSVP, mac lấy từ đang đọc từ delegate hệ thống; còn rect từ trên app khác (overlay) thì cả 2 nền tảng đều phải lấy qua AX/UIA và đều phải thử từng app.

## 4. Dấu phẩy — hướng sửa theo `rsvp-report.md` §6.5 (bước sau, chưa chốt số)

- **Hiện tại:** code dùng **1 utterance liên tục** (`speakContinuous` → 1 `AVSpeechUtterance` cho toàn bộ text còn lại, giữ nguyên dấu phẩy, không set `preUtteranceDelay`/`postUtteranceDelay`). Khoảng lặng ở dấu phẩy hoàn toàn do giọng Apple tự ngắt; trong khoảng lặng đó không có callback `onWordRange` nào nên highlight đứng yên ở từ trước dấu phẩy — đó là hành vi đúng (highlight chờ giọng), không phải lỗi highlight.
- **Hướng sửa (theo §6.5 — hướng chính, học từ Apple docs): tách utterance theo cụm-câu, chỉnh pause bằng `postUtteranceDelay`.** Cụm kết thúc ở cuối câu/mệnh đề/cuối đoạn (giống `BuildPhrases` bên Windows), mỗi utterance có `postUtteranceDelay` tự chỉnh (vd phẩy ~0.1–0.2 s thay vì pause mặc định của giọng). **Ràng buộc:** cụm phải đủ dài (cap ~20 từ) và **KHÔNG tách ở mọi dấu phẩy** — đoạn phẩy dày (mỗi 4–6 từ lại có phẩy) mà tách ở mọi phẩy thì mỗi utterance chỉ 4–6 từ, càng rời rạc hơn; phẩy chỉ là pause NHẸ bên trong cụm, điểm tách là cuối câu/mệnh đề/cuối đoạn.
- **Đánh đổi khi tách utterance:** phải nối lại word-tracking qua nhiều utterance (range phải cộng dồn offset từng utterance — cùng cách `SpeechPlayer` đã cộng offset khi resume), và có nguy cơ nghe "đứt quãng" nếu delay đặt sai.
- **CHƯA CHỐT — cần test nghe thật trước khi chốt số:** test A/B cùng đoạn text ở 1x vs 2x vs 4x, 2 giọng (en-US/en-GB, nam/nữ), ghi lại pause ở phẩy có dài bất thường không; chỉ chốt số delay sau khi nghe thật. **Hướng tách utterance này là bước sau** — spec word-sync này không bắt buộc làm cùng lúc; làm highlight trước trên 1 utterance liên tục, tách utterance làm sau khi đã test nghe.
- **Không làm:** tiền xử lý text (thay/bớt dấu phẩy) — làm méo text gốc, phải giữ song song 2 bản text (bản hiển thị + bản đọc, dễ lệch range highlight); chỉ cân nhắc nếu hướng tách utterance quá phức tạp.

## 5. Pro gate — word-sync hiện đang FREE, đổi sang Pro cần Manh chốt riêng

- `ProGate.wordSyncEnabled` (`Sources/FastRead/RSVPView.swift` dòng ~5–21) hiện = `true` — **word-sync đang FREE** (Manh 2026-11-21). Đây là điểm cắt duy nhất: đặt thành `false` thì read-along rớt về đồng hồ WPM im lặng ngay cả khi bật loa.
- **Spec này KHÔNG đổi gate.** Word-sync có trong kế hoạch Pro nội bộ (AI TTS + word-sync là mục Pro), nhưng đổi từ FREE sang Pro là quyết định sản phẩm — **cần Manh chốt riêng**, không tự đổi trong spec này và không tự đổi khi triển khai spec này. (Ghi chú trong code: nếu gated thì có thể phát DEMO ngắn bằng giọng khác — ý tưởng demo, CHƯA làm.)

## 6. Chưa chốt / cần spike

- **Số `postUtteranceDelay` cho từng loại dấu câu** (phẩy / chấm / cuối đoạn) — chưa có số, cần test nghe thật (§4) rồi mới chốt.
- **Hành vi khi provider không có word-range** — spec chốt fallback "chỉ highlight câu/slide" (§3), nhưng chưa test thực tế với provider cloud (nếu sau này thêm giọng cloud): highlight câu có nhảy đúng nhịp không, có cần ước lượng thời gian câu không.
- **SSML `<break>` trong 1 utterance** (`AVSpeechUtterance(init?(SSMLRepresentation:))`) — chưa kiểm chứng giọng macOS có tôn trọng `<break time="..."/>` không; nếu có thì chỉnh pause ở phẩy ngay trong 1 utterance mà không cần tách. Cần test nhỏ trước khi dựa vào hướng này.
- **Windows (làm sau mac) — CHƯA spike:** WinRT `SpeechSynthesizer` **KHÔNG có** word-boundary callback → highlight theo câu (không theo từ) là mức làm được ngay; muốn highlight theo từ thì cần cloud TTS trả speech marks (kiểu NaturalReader: MP3 + speech marks) — **cần spike kiểm chứng trước khi chốt** UI highlight-từ trên Windows. Không chốt UI Windows trong spec này.

## Liên kết

- [Speech Player](SPEECH_PLAYER.md) — luật loa play/pause/resume, pause giữ highlight, hết unit gỡ highlight
- [Speech Engine](SPEECH_ENGINE.md)
- [Float Icon UX](../UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md)
- [Kế hoạch thử nghiệm bước 2 (overlay trên trang)](../RESEARCH/tts-speechify-naturalreader/step2-trial-plan.md)
- [Khuyến nghị TTS](../RESEARCH/tts-speechify-naturalreader/recommendation.md) — §3 highlight 2 lớp câu/từ, word-range miễn phí trên macOS, Windows không có word callback
- [RSVP report](../RESEARCH/tts-speechify-naturalreader/rsvp-report.md) — §6.5 dấu phẩy ngắt nhịp (hướng tách utterance theo cụm-câu)
