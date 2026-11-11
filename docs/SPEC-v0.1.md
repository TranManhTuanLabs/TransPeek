# TransPeek — SPEC v0.1 (SPEC + TÊN ĐÃ CHỐT 2026-11-07, chưa thực thi)

Ngày: 2026-11-07 — Trạng thái: SPEC + TÊN ĐÃ CHỐT. Chưa code.
Tên app: **TransPeek** — Tagline: *Translate anywhere, peek instantly.* (Nhìn là dịch ngay.)

## 0. Tên + Bundle ID — ĐÃ CHỐT TẠM 2026-11-07: TransPeek (repo đã đổi tên xong, có thể đổi lại sau nếu nghĩ ra tên hay hơn)

- Tên app: **TransPeek**
- Repo macOS: **TranManhTuanLabs/TransPeek** — ĐÃ ĐỔI TÊN XONG, kiểm chứng 2026-11-07: cùng repo ID 1433519010, URL cũ PeekTrans redirect về đây, vẫn là fork của cosZone/MoePeek, nhánh main.
- Bundle ID macOS: `com.tranmanhtuanlabs.transpeek` — TẠM GIỮ DẠNG DÀI này cho Phase 1, để khỏi làm lại giữa chừng.
- URL scheme: `transpeek`
- Sparkle feed: trỏ về repo TranManhTuanLabs/TransPeek (không trỏ về cosZone)
- Repo Windows sau này: **TransPeek-Windows**
- Ý nghĩa: Trans = dịch (đứng đầu, nhìn là biết app dịch), Peek = nhìn nhanh (giữ gốc MoePeek) — "dịch ở đâu cũng được, liếc là thấy".
- TRÙNG TÊN ĐÃ BIẾT, MANH CHẤP NHẬN: TransPeek trùng với `yinapsc30/TransPeek` (tool Swift dịch cửa sổ macOS bằng OCR + floating panel, tạo 24/10/2026, mới ~2 tuần) và app iOS TransPeek dịch màn hình của ByuTech. Manh chốt cho trùng luôn vì repo kia còn mới/nhỏ, rủi ro thực tế thấp. Sau này nếu nghĩ ra tên hay hơn thì đổi tên + bundle ID lại (đổi lúc chưa có user thì rẻ, đổi sau khi phát hành thì vỡ Keychain/UserDefaults/App Groups/Sparkle).
- Ghi chú PeekTrans: từng chốt rồi đổi sang TransPeek theo ý Manh. PeekTrans đọc lên đồng âm với PeakTrans, mà PeakTrans search ra peaktrans.org (site "Peak Trans" về tranh luận giới tính, hashtag #PeakTrans) — va chạm thương hiệu nặng, nên PeekTrans không quay lại trừ khi Manh chấp nhận rõ va chạm đó.
- **Chuẩn bundle ID cho sau này (Manh dặn đồng bộ):** ưu tiên rút gọn tổ chức thành **ManhTuanLabs** — dạng `com.manhtuanlabs.<app>` (ví dụ `com.manhtuanlabs.transpeek`); hoặc dạng app `com.<app>.app` (ví dụ `com.transpeek.app`, giống SeekZip dùng `com.seekzip.app`). Dạng dài `com.tranmanhtuanlabs.<app>` chỉ giữ tạm cho TransPeek Phase 1, các app/tên mới sau này dùng 1 trong 2 dạng trên cho đồng bộ. Lưu ý: bundle ID phải duy nhất trên App Store — dạng `com.<app>.app` của TransPeek có thể đã bị bên kia đăng ký (app TransPeek thật), nên dạng `com.manhtuanlabs.<app>` an toàn hơn vì gắn với tổ chức của Manh.
- Quy tắc đã chốt: đổi tên repo ngay sau khi chốt tên, TRƯỚC khi code Phase 1 đẩy lên; bundle ID + URL scheme + Sparkle feed đổi theo tên mới trong commit đầu.
- **Cách đẩy code (Manh chốt 2026-11-07): làm local hết tới cuối Phase/milestone lớn rồi mới đẩy lên GitHub MỘT đợt, không đẩy lẻ từng file giữa chừng — tránh gián đoạn chờ permission từng file.**
- Tên đã loại: TransLearn, TransLex, WordPeek, HoverTrans, TextTrans, LexiPeek (kafeg/lexipeek), TransSeek (cụm sS), TranSeek (trùng Immersive Translate "TranSeek Free Translation Services" + 4 repo GitHub), TransPeak (app Transpeak + peaktrans.org), TransSummit (Intuit Trans+ Summit), TransFlex (dratct/TransFlex app macOS dịch LLM), TransOCR (13 repo GitHub + model EMNLP 2025, hẹp brand về OCR), SeekTrans (app iOS "SeekTrans - Offline Translator" $0.99 v1.1.3), PeekTransOCR (dài, hẹp brand về OCR), WordSeek (71 repo GitHub + game word search), DictSeek / LexiSeek / LinguaSeek (sạch nhưng không được chọn — DictSeek là tên sạch nhất nếu sau này đổi tên).

- Tên hiển thị đổi dễ (chuỗi trong Info.plist). Bundle ID đổi muộn thì vỡ: Keychain, UserDefaults (`defaults delete <bundle-id>`), App Groups, Sparkle update, quyền Accessibility/Screen Recording đã cấp, và user đang dùng sẽ mất setting.

### Chạy song song app chính chủ MoePeek
- MoePeek gốc có bundle ID `com.nahida.MoePeek`, URL scheme `mopeek`, Sparkle feed về `github.com/cosZone/MoePeek`.
- Fork PHẢI đổi bundle ID + scheme + feed như trên, nếu không macOS coi là cùng 1 app: ghi đè nhau trong /Applications, dùng chung setting, Sparkle có thể tự cập nhật fork về bản upstream.
- Cài chính chủ ở `/Applications/MoePeek.app`, bản fork ở `/Applications/TransPeek.app`.
- Cấp lại Accessibility + Screen Recording riêng cho bundle ID mới (hệ thống sẽ hỏi lại).
- Không chạy 2 app cùng lúc với cùng phím tắt (mặc định ⌥D, ⌥S…): hoặc tắt 1 app khi test app kia, hoặc đổi phím tắt của fork trong lúc test.
- Xem có gì mới ở upstream chủ yếu qua GitHub Watch/Releases + `git fetch upstream`, không cần chạy 2 app cùng lúc hàng ngày.

## 1. Phạm vi & repo

- 2 repo riêng biệt, không dùng branch để chứa 2 nền tảng.
- Repo 1 — macOS: `TranManhTuanLabs/TransPeek` (fork của `cosZone/MoePeek`, Swift 6, AGPL-3.0, head 15ec28e lúc fork).
  Đổi tên repo KHÔNG mất sync upstream (GitHub giữ quan hệ fork theo ID, chỉ cần `git remote set-url origin <url-mới>` ở local).
- Repo 2 — Windows 11: repo mới `TransPeek-Windows`, không phải fork MoePeek. Stack đề xuất WinUI 3 + C#.
  Làm sau, mirror y nguyên spec mac; chỉ thêm tính năng riêng khi Windows mạnh hơn ở điểm đó.
- Nguyên tắc chung: không chung code, chỉ chung spec — cùng danh sách tính năng, cùng format config, cùng tên setting.

## 2. Hành vi mặc định — ĐÃ CHỐT

```
selected text -> show icon -> hover -> show float panel
                              -> click icon -> TTS ngay (bổ sung, không đổi hover)
```

- Hover: chờ 0.3s (setting được 300/500ms) rồi mở float panel dịch.
- Click icon: hủy hover timer, phát TTS ngay, KHÔNG mở panel. Icon giữ trạng thái đang đọc, bấm lại để dừng. Icon tự ẩn sau 3s nếu không tương tác (giữ như MoePeek gốc).
- Trong float panel luôn có nút loa riêng — đây là đường TTS chắc chắn nhất; click icon chỉ là đường tắt nhanh.
- Setting: `Click icon = Phát âm (mặc định mới) / Dịch (kiểu cũ)`.

Lý do cần cơ chế này: code MoePeek gốc hover và click đều gọi dịch, nên click = TTS mà không hủy hover timer sẽ bị đua (hover >0.3s là panel đã mở, icon không còn để click).

## 3. Dịch + học English — làm trước

### 3.1 Máy dịch flexible (Phase 1)
- Giữ provider protocol của MoePeek (đã có Google, Bing, DeepL, Apple Translation, OpenAI, Anthropic, DeepSeek, Ollama, LM Studio…).
- Settings: chọn provider chính, provider dự phòng, bật/tắt từng provider, API key lưu Keychain, Custom OpenAI-compatible endpoint (base URL + model).
- Fallback dịch (luôn có, không fail im lặng): chính -> dự phòng -> Apple/Google free -> báo lỗi rõ trong panel.

### 3.2 Từ điển ở bottom panel (Phase 1)
- Hàng icon link ở đáy float panel. Mỗi link là template:
  - `{word}` = từ đầu tiên của text tra cứu, **viết thường trước khi thay vào link** (Oxford/Cambridge phân biệt chữ hoa/thường ở đường dẫn: "Word" mở ra `.../Word` sẽ báo "Word not found in the dictionary", phải là `.../word`).
  - `{text}` = toàn bộ text tra cứu, URL-encoded, giữ nguyên chữ hoa/thường (dùng cho Google / search và YouGlish).
- Mặc định: Oxford, Cambridge, Google, YouGlish.
  - Oxford dùng `{word}` + `?q={word}` (giống link khi tự tra trên web Oxford).
  - YouGlish dùng `{text}` (không dùng `{word}` nữa): YouGlish tra được cả cụm từ/câu, nghe phát âm cả cụm trong video thật.
- **Text tra cứu = "lựa chọn đang hiện hành" — ĐÃ CHỐT 2026-11-08 (từ test live của Manh):**
  - Mặc định: link tra theo đoạn text ban đầu đã bôi đen để mở panel.
  - Bôi đen lại text trong panel (ô nhập source) → link đổi theo lựa chọn mới đó.
  - Bỏ chọn trong panel (chỉ đặt con trỏ, không bôi đen gì) → link về lại đoạn ban đầu.
  - Lý do: link `{word}` chỉ có nghĩa với 1 từ; bôi đen cả đoạn thì lấy từ đầu tiên gần như vô ích (từ điển không có mục từ cho cả câu, từ đầu tiên thường không phải từ cần tra). Cách xử lý đúng là để user bôi đen lại đúng từ cần tra trong panel.
  - Phạm vi v1: theo dõi lựa chọn trong ô nhập source (`SourceTextEditor`, NSTextView, delegate `textViewDidChangeSelection`). Bản dịch trong panel dùng SwiftUI Text với `.textSelection(.enabled)` — SwiftUI không có API đọc lại đoạn text đang được bôi đen, nên v1 chưa theo dõi lựa chọn trong bản dịch.
  - **Mở rộng 2026-11-08 (theo yêu cầu của Manh): lựa chọn trong ô ĐÃ DỊCH cũng đổi link theo.** Bản dịch hiển thị bằng `SelectableResultTextView` (NSTextView chỉ đọc, báo lựa chọn qua delegate giống ô source; Markdown được parse thành attributed string giữ bold/italic/code/link). Lựa chọn mới nhất thắng — dù chọn ở ô nguồn hay ô dịch; bỏ chọn ở ô nào thì về lại text gốc. Ngoại lệ: chế độ Rich Text có ảnh đính kèm vẫn dùng Textual `MarkdownResultView` nên không theo dõi được lựa chọn ở chế độ đó.
  - Nơi giữ trạng thái: `PopupView` giữ `lookupText: String?` (`nil` = dùng text gốc mở panel); `DictionaryBarView(sourceText:)` nhận text tra cứu hiệu quả (`lookupText ?? coordinator.sourceText`); đổi text gốc mới (`coordinator.sourceText` đổi) thì reset `lookupText` về `nil`.
- User thêm/sửa/xóa link trong Settings. Bấm mở bằng trình duyệt mặc định (tab mới hay cửa sổ mới do setting trình duyệt quyết, app không ép 100% được).
- Hiển thị: setting `Icon + Text / Chỉ icon`.
  - Icon lấy từ favicon của trang web đó (thử `https://<domain>/favicon.ico`, fallback qua dịch vụ favicon của Google/DuckDuckGo), cache local, load bất đồng bộ, không chặn panel.
  - Nếu không lấy được favicon: fallback icon chung (quả cầu / chữ cái đầu của tên link).

### 3.3 Screenshot OCR lên float panel (Phase 1 mac, Phase 4 Windows) — ĐÃ CHỐT 2026-11-07
- **Trước khi làm: kiểm tra repo gốc MoePeek trước, làm cho phù hợp — MoePeek đã có gần hết OCR rồi (Vision OCR, chọn vùng chụp màn hình, phím `⌥ S`, menubar). Chỉ thêm phần còn thiếu: nút OCR lên float panel, interface `IOcrProvider` + Tesseract fallback, 2 chế độ sau OCR (panel dịch + auto copy / chỉ copy), không viết lại OCR từ đầu.**
- Thêm nút OCR vào float panel (hiện OCR chỉ ở menubar / phím `⌥ S`).
- Flow: ẩn panel tạm thời -> chọn vùng màn hình -> OCR -> dịch -> hiện kết quả lại trong chính panel đó.
- macOS dùng Vision OCR đã có sẵn.
- **Windows — OCR provider flexible, giống provider dịch/TTS (thiết kế `IOcrProvider`: `id, tên, cần mạng/key không, ngôn ngữ hỗ trợ, trạng thái`):**
  - `Windows.Media.Ocr` (mặc định, built-in, offline, không cần cài thêm): dùng trước. Chất lượng tiếng Việt phụ thuộc language pack OCR đã cài trên máy, thường yếu hơn Tesseract với dấu tiếng Việt.
  - `Tesseract` (mặc định cho tiếng Việt, offline, miễn phí): engine của dpScreenOCR — dpScreenOCR (danpla/dpscreenocr, C++/Qt, zlib license, v1.5.2, 300 sao, Windows + Linux) là app độc lập, **không phải thư viện để nhúng trực tiếp vào WinUI 3**, nhưng chứng minh đúng workflow cần học: hotkey chọn vùng -> Tesseract OCR -> copy text vào clipboard, hỗ trợ 100+ ngôn ngữ, tiếng Anh có sẵn, ngôn ngữ khác cài qua language manager, bản Windows chỉ ship sẵn tiếng Anh. Trong app mình: nhúng Tesseract qua NuGet / binary kèm theo app + file `vie.traineddata` + `eng.traineddata` (ưu tiên `tessdata_best`, kèm preprocessing upscale/grayscale), có language manager trong Settings để tải thêm ngôn ngữ, giống dpScreenOCR. Fallback: Tesseract -> Windows.Media.Ocr -> báo lỗi rõ.
  - `Cloud OCR` (tùy chọn, Phase 4 sau): Azure AI Vision Read / Google Cloud Vision, cần key user, online, trả phí — chỉ khi cần độ chính xác cao / chữ viết tay / ảnh xấu.
  - `dpScreenOCR ngoài` (phương án dự phòng, không phải mặc định): nếu user đã cài dpScreenOCR, app có thể gọi nó qua "Run executable" của nó rồi đọc clipboard — UX rời rạc, chỉ dùng tạm, không thay tích hợp trong app.
- **macOS — cũng provider flexible, KHÔNG port nguyên app dpScreenOCR sang mac:** dpScreenOCR chỉ có bản Windows + Linux, không có bản mac (bảng Tesseract ghi dpScreenOCR Linux X, Mac trống, Windows X). Port nguyên app Qt sang mac phải viết lại chụp màn hình (ScreenCaptureKit + quyền Screen Recording), hotkey, UI Qt không native — tốn công mà trùng hết UI float panel / hotkey MoePeek đã có. Cách đúng: chỉ port **engine Tesseract** sang mac làm provider thứ 2, chung interface `IOcrProvider` với Windows.
  - `Vision` (mặc định mac, đã có trong MoePeek): `VNRecognizeTextRequest`, `.accurate`, `recognitionLanguages = ["vi-VN", "en-US"]`. Vision đã hỗ trợ tiếng Việt (18 ngôn ngữ, có Vietnamese; bảng macOS Tahoe ghi `vie | Vietnamese | ✓` ở chế độ accurate) — nhưng hỗ trợ tiếng Việt phụ thuộc phiên bản macOS, phải kiểm tra `supportedRecognitionLanguages` lúc chạy, và tắt `usesLanguageCorrection` tiếng Anh nếu máy không có tiếng Việt (không thì Vision sẽ "sửa" chữ Việt thành chữ Anh).
  - `Tesseract` (tùy chọn trên mac, Phase 2): qua SwiftyTesseract / Tesseract macOS framework (ObjC + Swift, x86 + arm64) hoặc XCFramework cộng đồng Tesseract 5.5.1 arm64 macOS 11+ qua SPM, kèm `vie.traineddata` + `eng.traineddata`, tải ngôn ngữ theo nhu cầu như dpScreenOCR (không bundle hết để khỏi phá ưu thế app ~5MB). Tiền lệ: VietOCR là GUI Tesseract trên mac hỗ trợ tiếng Việt. Chỉ thêm Tesseract trên mac sau khi so sánh Vision vs Tesseract bằng ảnh tiếng Việt thật ở Phase 1 — nếu Vision đã đọc tiếng Việt ngon thì để Tesseract làm fallback, không ép làm mặc định.
  - Fallback mac: Vision -> Tesseract (nếu đã cài/bật) -> báo lỗi rõ.
- **Sau OCR — 2 chế độ, Manh đã xác nhận flow 2026-11-07 (ĐÃ CHỐT):**
  - **Chế độ 1 — OCR + panel dịch + auto copy bản dịch (mặc định):** chụp vùng -> OCR -> dịch -> **tự động copy bản dịch vào clipboard** (không cần bấm nút) -> hiện float panel với text gốc OCR được + bản dịch. Trong panel có **2 nút copy riêng, đặt cạnh từng đoạn**: [Copy gốc] cạnh text gốc OCR được, [Copy dịch] cạnh bản dịch — không dùng chung 1 nút copy (dùng chung sẽ không biết copy đoạn nào). Nút [Copy dịch] để copy lại bản dịch sau khi user đã bấm [Copy gốc] hoặc copy thứ khác. Lưu ý: auto copy sẽ ghi đè clipboard hiện tại, nên có setting `Tự động copy bản dịch sau OCR: Bật (mặc định) / Tắt` trong Settings.
  - **Chế độ 2 — OCR chỉ copy (không dịch, không float panel):** chụp vùng -> OCR -> copy thẳng text gốc vào clipboard, không gọi máy dịch, không mở float panel, chỉ hiện toast "Đã copy". Dùng khi chỉ cần lấy text trong ảnh/PDF/video để paste đi làm việc khác.
  - Chọn chế độ trong Settings (`Sau OCR: Mở panel dịch / Chỉ copy`) và/hoặc phím tắt riêng cho từng chế độ.
- Ngôn ngữ OCR v1: EN + VI (mặc định), user thêm ngôn ngữ khác trong Settings. Test tiếng Việt bằng ảnh chụp thật (sách, web, PDF scan) ở Phase 4, vì dấu tiếng Việt là điểm yếu hay gặp của OCR.

## 4. TTS — làm SAU CÙNG, cái khó làm kiểu develop/thử nghiệm

Thứ tự: dịch + học English ngon trước, rồi mới làm TTS nâng cao.

### 4.1 Phase 1 — chỉ System TTS (đi kèm click icon)
- MoePeek đã có `AppleTTSProvider` (AVSpeechSynthesizer). Chỉ nối click icon + nút loa trong panel vào nó.
- 1 từ: phát âm nhanh tại panel. Đoạn dài: đọc cả đoạn. Có nút dừng.

### 4.2 Ngôn ngữ & giọng (Phase 1 + develop)
- V1: chỉ EN + VI.
- User được flexible chọn luôn: Settings cho phép thêm ngôn ngữ/giọng khác, chọn từ danh sách giọng đã cài trên hệ điều hành — không hardcode chỉ EN/VI.
- Autoswitch voice theo ngôn ngữ phát hiện: tính năng develop/thử nghiệm.
  - Dùng LanguageDetector đã có trong MoePeek để đoán ngôn ngữ của text.
  - Bảng map giọng theo ngôn ngữ trong Settings: `en -> giọng X, vi -> giọng Y`.
  - Nếu engine không có giọng cho ngôn ngữ đó: fallback giọng mặc định của engine cho ngôn ngữ đó -> giọng System cho ngôn ngữ đó -> giọng EN.
  - Nếu autoswitch khó / không ổn định: để ở chế độ develop, tắt mặc định, không chặn Phase 1.

### 4.3 Engine TTS (Phase 2–3, theo provider interface)
Thiết kế `TTSProvider` giống `TranslationProvider`: mỗi engine có `id, tên, cần mạng/key không, ngôn ngữ hỗ trợ, chất lượng, trạng thái`.

| Engine | Khi nào dùng | Trạng thái |
|---|---|---|
| System (mặc định) | Offline, miễn phí, phát âm nhanh | Phase 1. macOS: AVSpeechSynthesizer. Windows: SpeechSynthesis/SAPI. |
| EdgeTTS | Giọng neural hay, miễn phí, không cần key | Phase 2, làm tùy chọn trước. Dễ làm + test ổn định thì mới lên mặc định online. Endpoint không chính thức (`speech.platform.bing.com`, Read Aloud của Edge), thỉnh thoảng 403/rate-limit, bắt buộc fallback về System. |
| Dictionary audio | Chỉ 1 từ | Lấy mp3 phát âm từ Oxford/Cambridge. Không dùng cho cả đoạn. |
| ElevenLabs (API) | Đọc đoạn dài, giọng hay nhất | Phase 3, tùy chọn. Cần API key của user, trả phí theo ký tự, gọi thẳng REST API từ Swift (không nhúng Python SDK). |
| VieNeu-TTS (repo ngoài) | Giọng Việt hay, on-device | Phase 3, tùy chọn. v3 Turbo open source (Apache-2.0), v4 proprietary chỉ qua API. Là TTS tiếng Việt, không phải engine phát âm tiếng Anh chính. |
| Repo khác trong list của Manh | Xem xét sau | List: https://github.com/stars/TranManhTuanLabs/lists/tts-service — sherpa-onnx, VoiceStudio, ViFastTts, VoxCPM, audio.cpp, GPT-SoVITS… 3 app Android (HayaiTTS, CloneTTS, NekoSpeak) chỉ tham khảo model/giọng, không dùng trực tiếp trên mac/Windows. |

- Fallback TTS (luôn có): engine đã chọn -> EdgeTTS (nếu online) -> System -> Dictionary audio (chỉ 1 từ) -> báo lỗi rõ, không fail im lặng.
- Nút tải repo/engine ngoài: Settings > TTS > External engines, mỗi engine có trạng thái Chưa cài / Đã cài / Đang chạy + nút Tải mở trang release/installer chính thức. App chỉ kiểm tra local server có chạy không rồi mới cho chọn. Không tự tải ngầm, không nhúng Python + model vài GB vào app (sẽ phá ưu thế ~5MB của MoePeek).
  - Lưu ý: VieNeu bản Windows đã có installer, bản mac installer đang sắp ra, nên trên mac v1 chỉ hướng dẫn cài qua `uv`/Docker hoặc để sang v2.
- TTS KHÔNG tách app riêng. Thử nghiệm trong app dịch trước. Nếu sau này nhu cầu đọc tài liệu dài thật sự lớn, làm Reader Mode trong cùng app trước, rồi mới tính tách.

### 4.4 Tham khảo UX (không nhúng code)
- NaturalReader: 150+ giọng, 20+ ngôn ngữ, free giới hạn giọng Premium 20 phút/ngày.
- Speechify: 1000+ giọng, 60+ ngôn ngữ, screenshot-to-audio, floating widget.
- Học ở họ: highlight từ đang đọc, chỉnh tốc độ, screenshot đọc thành tiếng. Đây là sản phẩm đóng, không có SDK native để nhúng.

## 5. Plan thực thi — milestone + cổng kiểm tra (Manh chốt 2026-11-07)

Quy tắc cổng kiểm tra: mỗi milestone làm local hết → đẩy GitHub 1 đợt cuối milestone → CI xanh → Manh test live trên Mac (Windows ở M6) → Manh ok / báo lỗi → sửa xong → mới sang milestone sau. Không tự động làm tiếp, không làm hết tới cuối rồi test một thể.

- **M1 — Phase 1 mac (đã xong code, đang chờ test):** dịch flexible + từ điển bottom panel (template + favicon + icon-only) + OCR lên float panel + click icon TTS System. Head b7bad69.
- **M2+M3 — Phase 2 mac, GỘP 1 LƯỢT TEST (Manh chốt 2026-11-07; làm trên NHÁNH RIÊNG m2-m3-tts-ocr ngay, không chờ M1 qua cổng — main giữ sạch để Manh test M1 riêng được):** TTS provider interface + EdgeTTS (tùy chọn trước, lên mặc định nếu spike dễ + ổn định) + fallback TTS + autoswitch giọng theo ngôn ngữ phát hiện (develop, tắt mặc định nếu không ổn định) + Tesseract OCR mac làm fallback (chỉ sau khi so sánh Vision vs Tesseract bằng ảnh tiếng Việt thật ở M1; trên nhánh thì Tesseract để tắt mặc định). Nhánh đẩy lên GitHub 1 đợt cuối milestone, KHÔNG merge vào main cho tới khi M1 qua cổng; nếu M1 phải sửa thì rebase nhánh theo main đã sửa. Lưu ý: test.yml chỉ chạy khi push main / PR / workflow_dispatch, nên push nhánh không tự chạy CI — chạy Tests bằng workflow_dispatch chọn nhánh, hoặc mở draft PR về main.

**Quy tắc "nền trước, nhánh sau" (Manh chốt 2026-11-07 — nhắc lại mỗi lần sửa CI):** khi CI đỏ ở cả main và nhánh, LUÔN test/sửa main TRƯỚC rồi mới sửa nhánh. Nhánh = main + commit mới, lỗi trên nhánh có thể gồm cả lỗi main — sửa nhánh trước dễ sửa nhầm chỗ hoặc sửa trùng 1 lỗi 2 lần. Thứ tự: CI main → sửa main → rebase nhánh theo main đã sửa → CI nhánh, lỗi còn lại mới là của nhánh. Áp dụng cho mọi milestone sau.
- **M4 — Phase 3 mac:** ElevenLabs (cloud REST, ~0MB nhúng, cần API key user, trả theo ký tự) + VieNeu-TTS v3 Turbo (on-device, nặng ~500–750MB weights+runtime, KHÔNG nhúng vào app — chạy server local ngoài qua POST /v1/audio/speech, app chỉ kiểm tra server có chạy không) + nút tải repo/engine ngoài, theo list TTS của Manh.
- **Đổi tên target/scheme MoePeek → TransPeek — làm LUÔN từ 2026-11-08, TRƯỚC khi test live (Manh đổi ý 2026-11-08, không chờ test live nữa vì chưa cài Xcode):** app build ra hiện vẫn tên MoePeek.app, dễ lẫn/ghi đè app MoePeek gốc Manh đang cài song song. Đổi target/scheme trong Project.swift + tên file (34 file, commit local ed3ce86, đã xong) + sửa test.yml/release.yml (phần workflow cần Manh sửa trên web GitHub, connector 403). Thứ tự bắt buộc: đẩy code lên main trước (Manh duyệt thẻ lúc 7h sáng 2026-11-08) → Manh sửa 2 file workflow ngay sau → chạy lại CI xanh → rebase nhánh m2-m3-tts-ocr theo main đã đổi tên → rồi mới cài Xcode và test live bản TransPeek.app, xong mới sang M4.
- **M5 — Phát hành mac:** signing/notarize mac, Sparkle feed thật, dọn nợ còn lại (API key chuyển sang Keychain, fallback dịch retry thật). Bản mac coi như xong ở đây.
- **M6 — Phase 4 Windows (Manh đổi ý 2026-11-08: làm TRƯỚC với scope thu hẹp, không chờ mac xong hết nữa; stack ĐÃ CHỐT WinUI 3 + C#):** Windows v0.1 = mirror tính năng gốc MoePeek (bôi chọn → dịch, float panel, providers — trừ Apple Translation vì không có trên Windows) + từ điển link+icon + OCR (Windows.Media.Ocr + Tesseract mặc định cho tiếng Việt, theo kiểu dpScreenOCR). CHƯA làm TTS (click icon đọc, EdgeTTS, autoswitch) — đợi mac ổn (test live xong + merge PR + M4/M5) mới làm tiếp TTS và phần còn lại. Repo riêng TransPeek-Windows, native Windows, gọi thẳng UI Automation / Windows.Media.Ocr / SpeechSynthesis, app ~10–20MB, C# thông dụng dễ bảo trì (Visual Studio Community miễn phí, NuGet). Dự phòng nếu WinUI 3 làm khó ở đóng gói: WPF + C#. Thay adapter nền tảng (UI Automation, OCR provider flexible, SpeechSynthesis). Thêm tính năng riêng chỉ khi Windows mạnh hơn. OCR sau chụp có nút Copy text vào clipboard + chế độ OCR chỉ copy. Installer Windows làm ở bước này. **Trạng thái 2026-11-08: v0.1 ĐÃ ĐẨY lên GitHub (commit fc008c79, 68 file, main) — base + từ điển + OCR + About (link+icon GitHub, release notes theo bản) + nút Check for Updates đơn giản (Velopack để sau lúc phát hành), KHÔNG TTS; chưa build/test được (VM không có dotnet) — cần Manh tự tạo `.github/workflows/build.yml` trên web rồi CI Windows xanh, rồi test live trên máy Windows theo docs/WINDOWS-v0.1-TESTING.md.**

## 6. Câu hỏi còn mở
1. EdgeTTS: sau spike mới quyết mặc định hay tùy chọn — đã chốt nguyên tắc “dễ thì mặc định, khó thì tùy chọn”, luôn có fallback.
2. Tên app/repo: ĐÃ CHỐT TẠM TransPeek (2026-11-07). Repo đã đổi tên xong TranManhTuanLabs/TransPeek, bundle ID `com.tranmanhtuanlabs.transpeek` (tạm giữ dạng dài), URL scheme `transpeek`. Sau này nghĩ ra tên hay hơn thì đổi lại trước khi phát hành. Phase 1 làm local hết rồi đẩy GitHub một đợt cuối milestone, không đẩy lẻ từng file.

## 7. Nhật ký quyết định — lý do chọn stack Windows (Manh chốt 2026-11-07)

Câu hỏi của Manh: bên Windows nên native hay chọn ngôn ngữ nhẹ, thông dụng, dễ bảo trì?

**Kết luận: WinUI 3 + C# — vì với app này, native và nhẹ/dễ bảo trì không đối lập nhau.**

App này không phải app hiển thị thông thường — nó cần chọc sâu vào hệ điều hành: lấy text đã bôi chọn trong app khác (UI Automation), phím tắt toàn cục, icon nổi, panel không cướp focus (Win32/WinRT), chụp màn hình OCR (`Windows.Media.Ocr` có sẵn), đọc TTS (SpeechSynthesis/SAPI có sẵn). Trong C# + WinUI 3, mấy cái đó gọi thẳng API của Windows là xong; framework nhẹ/cross-platform thì phải viết thêm lớp cầu nối, hoặc dùng plugin mà plugin cũng không đủ sâu.

| Hướng | Dung lượng / RAM | Bảo trì | Lý do chọn / loại |
|---|---|---|---|
| **WinUI 3 + C# — CHỐT** | App ~10–20MB, RAM ~50–80MB, ngang tầm bản mac (~5MB / ~50MB) | C# là một trong những ngôn ngữ thông dụng nhất, tài liệu + NuGet + cộng đồng đông, Visual Studio Community miễn phí, Microsoft bảo trì dài hạn | Native + nhẹ + dễ bảo trì cùng lúc. Tiền lệ: dTran, Easydict for Windows đều WinUI 3. |
| WPF + C# — dự phòng | Tương đương WinUI 3 | C# như trên, trưởng thành hơn WinUI 3 | Chỉ dùng nếu WinUI 3 làm khó ở khâu đóng gói; giao diện ít hiện đại hơn WinUI 3 một chút. |
| Tauri (Rust + giao diện web) | Nhẹ nhất (~5–10MB), giao diện JS/TS dễ viết | Phải bảo trì 2 ngôn ngữ (Rust + JS), phần native (UI Automation, hotkey, OCR) vẫn phải viết bằng Rust | Nhẹ nhưng panel nổi + accessibility yếu hơn WinUI, tổng công bảo trì không ít hơn. |
| Electron (JS) | ~150MB, RAM cao, khởi động chậm | JS dễ viết nhất, cộng đồng đông | Loại — đi ngược mục tiêu nhẹ như bản mac. |
| Flutter (Dart) | ~20–30MB | Dart ít người hơn C#, plugin cho hotkey/UI Automation trên Windows còn non | Loại — plugin chưa đủ sâu cho tính năng cốt lõi. |
| Python (PyQt/Tkinter…) | Đóng gói ~100MB+, khởi động chậm, hay bị antivirus báo | Viết nhanh nhất | Loại — viết nhanh nhưng phát hành và bảo trì khổ. |

Ghi chú: 2 repo riêng (mac Swift / Windows C#), chỉ chung spec — danh sách tính năng, format config link từ điển, tên setting — không chung code.

## 8. Quyết định menubar + quét mã (2026-11-10)

### Smart Translation vs Clipboard Translation — giữ cả hai
- Smart Translation là 3 nấc: bôi chọn → clipboard → nhập tay. Clipboard Translation chỉ đọc clipboard.
- Hai cái chỉ giống nhau khi không bôi chọn gì và clipboard có text (Smart rơi về nhánh clipboard).
- Khác nhau khi: có text đang bôi chọn (Smart dịch phần bôi chọn, Clipboard dịch clipboard), hoặc clipboard trống (Smart mở panel nhập tay, Clipboard báo lỗi "Clipboard is empty").
- Cả hai đều là tính năng gốc của upstream MoePeek (code y hệt). Giữ cả hai để đồng bộ với upstream; bỏ Smart là mất tính năng không có gì thay thế.

### Quét mã vạch / QR Codes
- Dùng Apple Vision (`VNDetectBarcodesRequest`) trên ảnh chụp vùng màn hình, xử lý on-device, không mạng.
- Học theo OwlOCR (owlocr.com): nếu payload là URL (http/https) thì tự mở tab bằng browser mặc định. OwlOCR không ghi rõ cách xử lý payload không phải URL, nên TransPeek tự quyết: payload không phải URL (số điện thoại, số tài khoản ngân hàng, text thường, Wi-Fi, vCard...) thì copy vào clipboard + hiện toast, không tự mở gì cả.
- Menubar có 2 mục headline xám mờ ("Text Capture from Screen", "Barcodes / QR Codes") theo mẫu OwlOCR; "Silent OCR" đổi tên thành "Clipboard OCR" (đúng bản chất: chụp → OCR → copy vào clipboard, không hiện panel); "Onboarding Guide..." đổi thành "Permissions Guide..." (cửa sổ đó thực chất là hướng dẫn cấp quyền).
- Tính năng mới trong batch 2026-11-10 (commit 313847f): Screenshot Copy (chụp vùng → copy ảnh vào clipboard, dùng `screencapture -i -c`), Scan Barcodes/QR Codes, top bar + bottom bar ở panel, nút copy ở input, "Google Dictionary" đổi thành "Google".
- Panel 2026-11-11 (theo ảnh chụp bản 0.21.0 CI #99): hàng input để icon loa + nút Copy sang phải (giống hàng kết quả: nút bordered mini, icon loa cùng màu với bên output), gợi ý phím tắt ở trái; nhãn giọng (US) giữ lại gộp trong nút loa cho vui mắt, chỉ hiện khi nhận ra tiếng Anh (không làm nhãn theo từng ngôn ngữ vì ngôn ngữ đã hiện ở hàng chọn ngôn ngữ); nút loa và nút Copy cùng chiều rộng tối thiểu 56pt để nhìn đều; bottom bar để icon mèo + link GitHub vào giữa (bấm vào mở repo mac https://github.com/TranManhTuanLabs/TransPeek), version vẫn ở phải.
- Panel đợt 2 2026-11-11 (feedback từ bản 0.21.0 CI #103): slogan mới "Translate anywhere, Peek instantly!" (P hoa + dấu !) — panel + About + key trong catalog đổi theo, README EN/ZH đổi theo cùng đợt; gợi ý phím tắt căn trái; bỏ minWidth 56 ở cả 4 nút loa/Copy (minWidth chỉ thêm padding, làm 2 nút cách xa nhau) và phóng to chính icon loa (+2pt, 14pt ở cỡ mặc định); link GitHub ở bottom bar bấm không được vì panel coi click không có InteractiveMarker là kéo cửa sổ — đã thêm marker vào nhóm GitHub, chưa kiểm chứng live; About: link đổi thành "Github/TranManhTuanLabs", copyright gộp 1 dòng "Copyright © 2025-2026 TransPeek Licensed under AGPL-3.0" (mất dòng Fork of MoePeek khỏi About, README vẫn ghi), thêm link Email mailto:tuanmanhtran.vn@gmail.com.
- Panel đợt 3 2026-11-11: About đổi link thành "Github.com/TranManhTuanLabs" (dẫn tới trang org github.com/TranManhTuanLabs, không còn repo); hàng output (ProviderResultCard) đổi HStack sang spacing 4pt cho loa + Copy sát nhau như hàng input (trước đây output dùng mặc định 8pt); chữ version ở góc phải bottom bar panel lúc đầu bỏ hẳn, sau đó giữ lại nhưng làm mờ (quaternary, giống shortcut hint ở hàng input) để vẫn nhận ra bản đang chạy khi báo lỗi — xem đợt 3b.
