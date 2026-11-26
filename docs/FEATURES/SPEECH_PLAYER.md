# Speech Player (bản nháp)

> Trạng thái: **bản nháp** — mô tả player TTS (nút loa, auto-play, đọc nhanh RSVP).

## 1. Nút loa — play/pause/resume, hết mới stop; indicator loa TÁCH RIÊNG khỏi icon float (CHỐT 26/11/2026, thay luật cũ "bấm lần nữa là stop")

Luật cũ (trước 26/11): bấm loa lần nữa là stop luôn. Luật mới theo hành vi Speechify + NaturalReader (đã đọc source thật cả 2 extension — xem `docs/RESEARCH/tts-speechify-naturalreader/`): 1 nút loa = toggle Play/Pause, KHÔNG có nút Stop riêng. Áp dụng giống nhau cho mọi unit (1 từ, 1 câu, 1 đoạn — chỉ khác độ dài). Phạm vi: loa click-to-listen từ icon float (indicator loa). Nút loa panel (input/output) GIỮ NGUYÊN tạm thời (Manh 27/11 00:12) — không đổi glyph, không đổi hành vi (vẫn toggle = stop như cũ), vì user không nghe ở đó là chính. Loa trong Read mode (bật/tắt tiếng khi đọc RSVP) là control riêng, giữ nguyên.

- **Chưa phát → bấm loa = play** từ đầu unit.
- **Đang phát → bấm loa = pause**, giữ nguyên vị trí từ/câu đang dừng.
- **Đang pause → bấm loa = resume** đúng chỗ dừng (không phát lại từ đầu).
- **Hết unit → stop tự động**: reset vị trí về đầu, gỡ highlight, ẩn indicator loa.
- **KHÔNG có cách dừng giữa chừng** (không nút Stop, không Esc — Manh chốt bỏ Esc 26/11): pause thì cứ kệ; khi indicator tự ẩn theo luật thường thì phiên kết thúc lặng lẽ (xem mục indicator bên dưới).
- **Pause thì GIỮ NGUYÊN highlight** ở từ đang dừng (không gỡ như NaturalReader) — để user thấy đang dừng ở đâu, resume nhìn rõ.
- **Pause kết thúc khi indicator tự ẩn**: không có timeout riêng kiểu "sau 1 phút tự stop" — pause kéo dài được bao lâu tùy indicator còn hiện (hover vào indicator thì timer tạm dừng, resume lúc nào cũng được trong lúc đó); indicator tự ẩn sau 5s không tương tác thì phiên kết thúc lặng lẽ. (Sửa 26/11: luật cũ "pause vô thời hạn" bỏ — vì indicator phải có đường tự ẩn, nếu không sẽ kẹt.)
- **Play mới thay play cũ**: bấm loa unit khác trong lúc đang phát/pause thì dừng cái cũ (kèm indicator cũ), phát unit mới từ đầu (auto-detect ON: hover block khác + click; OFF: select text mới + click). Bấm lại đúng unit đang pause thì resume. Chỉ bấm loa mới mới hủy phiên cũ — select/hover text mới chỉ hiện icon float mới, phiên cũ vẫn chạy (không chồng tiếng vì chỉ có 1 phiên tại 1 thời điểm).
### Indicator loa — phần tử nổi RIÊNG, tách khỏi icon float (CHỐT 26/11 23:59)

Lý do tách: icon float chỉ có 1 cửa sổ — lúc đang phát, nó bị phiên loa chiếm (hover text khác không dịch được, mà select mới thì làm mất nút pause của tiếng cũ — tiếng cũ vẫn phát mà không còn nút nào). Cả Speechify (Pill Player) lẫn NaturalReader (minibar) đều tách player khỏi icon trigger. Tách rồi thì 2 phần tử độc lập, mỗi cái tự quản lifecycle của mình, không biết gì về nhau; điểm chung duy nhất là phiên TTS.

- **Indicator là phần tử nổi riêng** (tái dùng máy móc cửa sổ nổi của icon float), hiện ở đúng chỗ user bấm loa — vị trí tự nhiên, không bám theo text, không can thiệp vị trí thêm.
- **Biểu tượng theo trạng thái** (theo nguyên tắc "glyph cho biết lần bấm tới sẽ làm gì"): đang phát: ⏸ (`pause.fill`, bấm để pause); đang pause: ▶ (`play.fill`, bấm để resume). Nút loa panel (input/output) GIỮ NGUYÊN tạm thời — không đổi biểu tượng theo trạng thái (xem phạm vi ở đầu §1). Icon float KHÔNG hiện trạng thái phát nhạc nữa (xem `FLOAT_ICON_UX_SPEC.md`).
- **Hiện trong lúc ĐANG PHÁT** để user luôn bấm được để pause. Trong lúc **ĐANG PAUSE**, indicator chạy theo luật ẩn bình thường (auto-hide sau 5s, hover vào thì timer tạm dừng như luật auto-hide thường); khi indicator ẩn thì phiên kết thúc lặng lẽ (stop). Resume được trong lúc indicator còn hiện.
- **Alternative icon (icon giả trong Read) — click loa của nó = click loa icon float thật** (CHỐT 27/11 00:32): bắt đầu phiên nghe, indicator hiện ở đúng chỗ bấm (chỗ alternative icon đang đứng), ⏸/▶, luật play/pause/resume như thường. Alternative icon KHÔNG đổi sang hình loa khi đang nói nữa — giữ glyph A blue bình thường; trạng thái phát nhạc chỉ hiện trên indicator. Bấm lại alternative icon trong lúc đang phát = phát mới thay phiên cũ (pause/resume là việc của indicator). Hover vẫn dịch như cũ (Lite: chuyển tab center; Full: mở panel tại cursor). Nút loa của cửa sổ Read (bật/tắt tiếng RSVP) là control riêng, KHÔNG đổi, không thuộc luật này. Xem doc thiết kế `docs/UI/UX_DESIGN/FAST_READ_SELECT_ICON.md`.
- **Hiện tại (26/11): CHƯA CÓ** — panel chỉ có 2 dạng loa (`speaker.wave.3.fill` khi nói / `speaker.wave.2` khi không nói), icon float chỉ có 1 dạng loa (`speaker.wave.2.fill`) cho cả phiên phát, code vẫn ghim icon lúc đang phát/pause + chặn hover lúc đang phát (sẽ bỏ khi làm indicator). (Nút Play/Pause trong Read mode đã có sẵn `play.fill`/`pause.fill` — không thuộc phạm vi này.)

- Khi click indicator loa đang phát TTS, hover vào indicator loa hiện panel tab 2/3 chỉnh nhanh
  tốc độ 1x/1.2x/1.5x/2x, chọn giọng, autoswitch voice nhận diện 2 ngôn ngữ — khỏi
  vào Settings; hoặc làm control riêng như Speechify/NaturalReader (định hướng 16/11).

## 2. Đọc nhanh (RSVP) — đã chốt luồng vào 17/11, CHƯA LÀM

- (1) Option-click (Mac) / Alt-click (Windows) → RSVP thẳng.
- (2) Chuột phải icon → menu "Đọc nhanh".
- (3) Nút "Đọc nhanh" trong panel dịch.
- (4) Menubar/tray. (5) Shortcut global chỉ là fallback.
- + Settings toggle đổi click → RSVP cho người dùng RSVP là chính.
- Vị trí view đọc: **giữ cả 2 phương án** (tab dãn / panel riêng), quyết ở lúc prototype.
  Nếu làm tab phải **ẩn HOÀN TOÀN chức năng panel dịch** khi đang đọc.
- Engine RSVP (tham khảo SwiftRead): WPM mặc định 275, max 2000, chunk 1–6,
  ORP pivot = ký tự giữa `floor(n/2)`, chữ cam `#f6861f`.
- **Model A là hướng thực tế cho app native; Model B KHÔNG làm** (ngay cả Speechify
  cũng chỉ Model B ở site quen viết selector tay).

## Liên kết

- [Speech Engine](SPEECH_ENGINE.md)
- [Float Icon](FLOAT_ICON.md)
- [Panel UX (chưa viết)](../UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
