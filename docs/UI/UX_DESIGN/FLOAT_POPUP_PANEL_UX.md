# Float / Popup Panel — UX Spec (CHỐT)

> **Trạng thái: CHỐT — 17/11/2026, theo build #200 (commit `3bad511`) + các đổi mới sau đó trên main (slogan 16, loa/Copy cố định từng card, bỏ Remember Last Popup Position). Panel center + Panel left CHỐT thêm 19/11/2026, theo v0.1.4 (build 248) — xem §10.**
>
> **FINALIZED 2026-11-20 (Manh): the panel UX/UI + button / scroll / position logic in this doc (§3, §10, §10.1–§10.10) is the LOCKED-IN official design — 3 tabs, Read lite, hover + pressed, swipe rules, panel-vs-window. Do not re-decide or change any locked number or behaviour without Manh's approval. Open items are listed separately in §10.10 — do not treat them as settled.**
>
> Các con số trong doc này là **spec**. Đổi bất kỳ số đã chốt nào cũng cần Manh duyệt trước.
>
> Spec đã bao gồm: size 420×450 / min 400×450 / max 600×800 (#198) + nút "?" bảng
> shortcut (#200) + loa/Copy cố định ở đáy card, text cuộn trong card (17/11, theo
> Windows) + slogan 16 (17/16/13, khớp Windows) + bỏ Remember Last Popup Position.
>
> **Định hướng: học theo panel Windows.** Windows làm trước, mac theo sau cho giống —
> 5 số cốt lõi giống nhau hoàn toàn, hành vi giống nhau (xem §8). Khi Windows đổi,
> đối chiếu lại doc này.
>
> Doc này chỉ cho **mac**. Đối chiếu với bản Windows
> (`TranManhTuanLabs/TransPeek-Windows`,
> `docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md` — đã chốt 17/11/2026, build #162):
> **5 số cốt lõi giống nhau hoàn toàn** (xem §8).

## 1. Kích thước chốt (locked sizes)

| Hạng mục | Số chốt | Nguồn trong code |
|---|---|---|
| Mở mặc định | **420 × 450** | `Constants.popupDefaultWidth = 420`, `popupDefaultHeight = 450` |
| Tối thiểu | **400 × 450** | `PopupPanel.minimumSize = 400×450`; OS kẹp qua `NSWindowDelegate.windowWillResize` |
| Tối đa | **rộng 600 / cao 800** | `PopupPanel.maximumSize = 600×800` |
| Cap ô output | **260** | `PopupPanelSizing.autoFitOutputCap = 260` — text dài cuộn trong ô, không dãn panel |
| Chiều cao ô nhập mặc định | **48** | `Constants.popupInputHeight = 48` (tự cao tối đa 6 dòng, xem §2) |

Baseline tham chiếu: **#198** (mở mặc định 420×450, min 400×450, max rộng 600 / cao 800,
cap output 260, auto-fit + snap-back ngang/dọc, kẹp min/max ở OS).
Nếu một bản sau phá layout thì quay về số của #198 rồi sửa lại từ đó.

## 2. Khung layout (VStack — top bar, input, divider, language, kết quả, Actions, Dictionary, footer)

Panel mac là một `VStack` (padding ngang 14), các hàng theo thứ tự từ trên xuống:

| Hàng | Nội dung | Số liệu chốt |
|---|---|---|
| Top bar | **Tên app + slogan + hint, căn giữa.** Tên app "TransPeek" Bold, slogan "Translate anywhere, Peek instantly!" (chỉ hoa T và P, Manh cố ý), hint "Hover icon to translate, Click to listen". **Cả hàng là vùng kéo di chuyển** (`TopBarDragMarker`) — panel không có title bar riêng | Cỡ chữ theo Settings `popupTopBarFontSize` mặc định **17**: tên app = N, slogan = N−1 (sàn 8), hint = N−4 (sàn 8). Mặc định: 17 / 16 / 13 (khớp Windows) |
| Ô nhập | **SourceInputView** — ô nhập, sửa được, cao mặc định 48, tự cao tối đa 6 dòng (`inputSixLineHeight`). Enter = dịch lại, Shift+Enter = xuống dòng. Dưới ô text là 1 hàng riêng: hint phím tắt (trái) + View picker + loa + Copy (phải) — loa/Copy **nằm ngoài ô text** (dưới ô), lúc nào cũng thấy | `popupInputHeight` 48 |
| Divider kéo | **DraggableDividerView** — kéo để đổi chiều cao ô nhập | |
| Hàng ngôn ngữ | **Source ⇄ Target + Capture OCR.** Pickers ngôn ngữ trái, nút Swap ⇄ giữa, nút "Capture OCR" (icon + chữ) phải | |
| Divider | Đường kẻ ngang | |
| Kết quả | **ScrollView chứa các ProviderResultCard** (1 card / provider). Mỗi card: header (tên provider + trạng thái) / text kết quả (chọn được, báo selection cho DictionaryBar) — text **cuộn trong card** (cap 260, xem §6) / hàng loa + Copy **cố định ở đáy card**, dưới ô text cuộn (xem §6) | Cap text 260; text dài cuộn trong card, nút luôn thấy |
| Actions | **"Fast Read" + "?" + Settings.** Căn phải, Spacing 4. "Fast Read" (icon `book.pages` + chữ, chạy Fast Read theo setting "Run FastRead in:", xem §10.7) ở đầu trái của hàng; "?" (nút `questionmark.circle`) + Settings ở đầu phải. **Pin KHÔNG còn ở hàng này — đã dời lên hàng chấm (dotsRow, đầu trái), xem §10.1** | Xem §7, §10.8 |
| DictionaryBar | **DictionaryBarView** — link tra từ điển theo text đang chọn (trong ô nhập hoặc trong kết quả) | |
| Footer | **Link GitHub căn giữa + text version căn phải** ("Version 0.1.3 (Build CI #200)" — ẩn số build khi = 1) | |

### Cỡ chữ theo Settings (chạy lúc mở panel và khi lưu Settings)

- **"App name & Slogan Font Size"** (`popupTopBarFontSize`, mặc định **17**, slider 12–24): tên app = N Bold, slogan = N−1, hint = N−4 (sàn 8). Mặc định: 17 / 16 / 13 (khớp Windows; slogan mac trước đây là N−2 = 15, đổi lên 16 ngày 17/11).
- **"Popup Font Size"** (`popupFontSize`, mặc định **14**, slider 12–24): chữ trong cả 2 ô Source + Translation.
- Slogan giữ nguyên "Translate anywhere, Peek instantly!" — chỉ hoa T và P (Manh cố ý), không đổi thành Title Case.

## 3. Hành vi (behaviour) — đặc tính panel hiện tại

- **Auto-fit mỗi lần panel hiện:** đo nội dung rồi vừa khung; text dài cuộn trong ô output (cap 260), panel không tự dãn. **Thử lại 1 lần** khi thiếu số đo.
- **Settings chỉ đặt giá trị mặc định, trong giải từ tối thiểu đến tối đa:** slider "Default Width" chỉ cho chọn trong 400...600, "Default Height" chỉ cho chọn trong 450...800 — đúng giải [min, max] của panel, không đặt được ngoài giải. **Mỗi lần mở panel về đúng mặc định (420×450)**; Settings không nhớ cỡ đã kéo.
- **Kéo tay không lưu:** kéo tay chỉ to ra thêm trong phiên đó. Cỡ kéo tay KHÔNG lưu vào Settings, đóng panel rồi mở lại là về mặc định.
- **Mở panel: luôn ở vị trí con trỏ.** Panel KHÔNG nhớ vị trí lần trước — setting "Remember Last Popup Position" đã **bỏ hẳn ngày 17/11** (cùng code lưu vị trí + migration V4) vì nó vô nghĩa với đặc tính mới: auto-fit mỗi lần mở + Settings chỉ đặt mặc định + kéo tay không lưu thì không còn "vị trí lần trước" nào đáng nhớ nữa; panel mở ở con trỏ là đúng nhất (tra từ đang đọc ở đâu, panel hiện ở đó).
- **Snap-back NGANG (+8):** kéo rộng thừa cho text ngắn → thả ra co về rộng mặc định 420; text dài thì giữ nguyên rộng đã kéo.
- **Snap-back DỌC (+8):** kéo cao thừa → thả ra co về chiều cao nội dung.
- **Thu/mở provider card:** card thu thì chỉ còn header, panel thụt theo (auto-fit lại ngay cả sau khi đã kéo tay).
- **Kéo di chuyển:** bằng cả hàng top bar (`TopBarDragMarker`). **Kéo resize:** grip 3 vạch chéo 20×20 ở góc dưới-phải (đổi chuột + kéo 2 chiều) + tay nắm viền phải (chỉ đổi rộng, con trỏ `resizeLeftRight`) + tay nắm viền dưới (chỉ đổi cao, con trỏ `resizeUpDown`) — các tay nắm viền là dải trong suốt 6pt. Min/max được OS kẹp qua `windowWillResize` (tương đương `WM_GETMINMAXINFO` bên Windows), nên không bao giờ kéo được dưới min hay trên max.
- **Ẩn panel:** click chuột ra chỗ khác. **KHÔNG có nút đóng tay, và cũng KHÔNG CẦN** — workflow của Manh là tra xong click ra chỗ khác, rồi tra cái mới.
- **Mở panel:** mặc định ở kích thước Settings (420×450), không mở compact, không nhớ cỡ kéo cũ.

> **Panel stays a panel — NOT converted to a window (Manh 2026-11-20, applies to mac AND Windows):** the translate UI stays a panel (`NSPanel` with `.nonactivatingPanel` on macOS; the equivalent non-activating popup on Windows) and is never converted to a regular window, on either platform. Reason: the panel exists for a quick "peek" — it does not activate the app or steal focus, it opens at the cursor, and it dismisses on outside click / Esc, so the user stays in the app they were working in. A regular window would steal focus on every translation and lose click-away dismissal, breaking the quick-translate workflow (the "Peek" in TransPeek). The hover-highlight limitation of a non-activating panel is fixed with a custom `.onHover` highlight (approved 2026-11-20), not by converting to a window. The window role already exists for the right job — the Fast Read window (Window Read RSVP) for long reading. Panel = quick translate, Window = long reading.

### Tay kéo / tay cầm (grip + tay nắm viền) — lý do làm và cảnh báo

- **Lý do làm:** panel là `NSPanel` borderless (không có title bar, không có viền hệ thống) nên macOS **không cho kéo resize native** — không có viền để túm, không có góc để kéo. Muốn đổi cỡ panel thì bắt buộc phải tự làm: 1 grip 3 vạch ở góc dưới-phải (kéo 2 chiều) + 2 tay nắm viền trong suốt 6pt (phải = chỉ rộng, dưới = chỉ cao). Windows không cần tự làm vì cửa sổ WinUI có viền native resize sẵn.
- **Lý do giữ nguyên, không động vào:** cụm này đã qua nhiều vòng sửa lỗi và giờ đã ổn — con trỏ đổi đúng khi di từ ngoài vào góc (cắt margin về 0, #191), hover lần đầu đã đổi chuột (tay nắm dùng `Color.white.opacity(0.001)` thay vì `Color.clear` vì `clear` không vẽ gì nên hover không bắt được, #198), kéo không giật (guard `isUserResizing` + `dragStartMouse`), kẹp min/max ở OS (`windowWillResize`). Mỗi lần động vào là sinh lỗi mới.
- **⚠️ KHÔNG ĐỘNG VÀO CODE NÀY KHI KHÔNG CẦN THIẾT:** `ResizeGripView` + `EdgeResizeHandle` trong `PopupView.swift`, `PopupPanel.windowWillResize` trong `PopupPanel.swift`, `finishPanelResize` + `popupFittedFrame` trong `PopupView.swift`. Sửa layout panel thì đối chiếu với khung này trước, sửa xong test kỹ: hover góc/viền lần đầu, kéo 2 chiều, kéo quá min/max, kéo rồi thả (snap-back).

## 4. Text dài / text ngắn

- **Text ngắn:** card ở chiều cao tối thiểu, panel ở chiều cao mặc định/tối thiểu. Nút loa/Copy nằm gọn trong card, dưới text kết quả.
- **Text dài (từ ~6 line trở lên):** text cuộn **trong card** (cap 260); panel không tự dãn thêm. **Hàng loa/Copy cố định ở đáy card, lúc nào cũng thấy — không cần kéo panel xuống đáy mới copy được** (xem §6). Chỉ kéo tay mới dãn panel, lúc đó cap 260 được nâng theo để ô dãn cùng.
- **Nguồn dài:** ô nhập cao tối đa 6 dòng, cuộn trong ô.
- **Thu provider:** card chỉ còn header, panel thụt theo; mở lại thì auto-fit về đúng nội dung.

## 5. Chiều cao tối thiểu (cố định + kẹp OS)

- Min là **cố định 400×450** (`PopupPanel.minimumSize`). Không có công thức min động
  như Windows (`ComputeMinPanelHeight`) — panel mac không cần, vì cấu trúc card
  nằm trong ScrollView nên không có bài toán "hàng `*` bị bóp" như Windows.
- Min/max được kẹp ở **2 lớp**: (1) `NSWindow.minSize` / `maxSize` đặt từ
  `minimumSize` / `maximumSize`; (2) `PopupPanel` tự làm `NSWindowDelegate` và
  `windowWillResize` kẹp mọi lần resize về `[minimumSize, maximumSize]` — lớp
  này là bắt buộc vì `NSHostingView` có thể reset `minSize` của window khi layout
  (bug #191). Tương đương `WM_GETMINMAXINFO` bên Windows.

## 6. Loa/Copy cố định ở đáy card — text cuộn trong card (Manh chốt 17/11, theo Windows)

Mỗi provider có nút loa/Copy riêng ngay dưới text của chính nó
(`ProviderResultCard`). Text dài thì **cuộn trong card** (ô text bị cắt ở cap
260, cuộn bằng `NSScrollView` bên trong; bản Markdown cũng cuộn trong
`ScrollView`), còn hàng loa/Copy là 1 hàng riêng **cố định ở đáy card, ngoài
vùng cuộn** — nên lúc nào cũng thấy, không cần kéo panel xuống đáy mới copy
được. Đây là cách Windows làm từ trước: `TranslationTextBox` có
`MaxHeight="260"` (text cuộn trong ô) và loa/Copy là overlay cố định ở góc
dưới-phải ô text (không trôi theo text).

- **Vẫn mỗi provider 1 nút riêng, không thêm logic định tuyến.** Nút nằm trong
  card của provider đó, bấm là đọc/copy đúng text của card đó — không cần biết
  nút thuộc provider nào, provider đang load thì sao (đó là lý do ngày 17/11
  buổi sáng Manh giữ nguyên không đưa nút ra ngoài thành hàng cố định chung).
  Cách này giữ nguyên quyết định đó mà vẫn hết nhược điểm "text dài phải kéo
  xuống đáy mới copy được".
- **Kéo tay dãn panel thì cap nâng theo:** cap text bình thường là 260; khi
  người dùng kéo panel cao hơn, cap được nâng theo chiều cao viewport
  (`PopupView.resultTextCap`) để ô text dãn cùng, không để thừa khoảng trống
  dưới card — giống Windows (nâng cap khi kéo).
- **Panel cao thêm 1 chút cho text dài:** để cả card (text 260 + header +
  hàng nút) vừa trong viewport, cap của `frameToFit` là 260 + 90 (chrome của
  card: header + divider + hàng nút + padding), nên panel khi text dài cao
  hơn trước ~90pt. Đây là giá để nút luôn thấy; vẫn trong max 800.

(Ngược lại, loa/Copy của **ô nhập** nằm ở hàng riêng **dưới** ô text — ngoài ô
cuộn — nên lúc nào cũng thấy, không cần kéo. Đó là mẫu "đưa ra ngoài" mà Manh
nhắc tới lúc đầu; chỉ áp được cho ô nhập vì ô nhập chỉ có 1, không có bài
toán nhiều provider.)

## 7. Nút "?" bảng shortcut + nút "Fast Read" (Manh 17/11, build #204 → đổi ở bản sau #204 / nhánh `feature/fast-read-rsvp`)

- Nút `?` (`questionmark.circle`) ở đầu phải hàng Actions, bên trái nút Settings (Pin đã dời lên hàng chấm — xem §10.1).
- **Đổi từ popover sang NHÚNG (Manh 17/11 ~11:50, từ test build #204):**
  bấm "?" thì panel tự ẩn nên không bấm được bảng; pin panel cũng không ổn
  vì chụp OCR sẽ bị panel che mất nội dung chụp. Popover là cửa sổ riêng —
  vừa mở là panel mất focus rồi tự ẩn (click-outside auto-hide). Nhúng bảng
  vào trong ô output thì bảng là nội dung của chính panel, không còn cửa sổ
  riêng để đấu nữa.
- Bấm "?" → bảng hiện **nhúng ở ĐẦU ô output** (trong ScrollView kết quả,
  ngay trên các card provider), là 1 khối riêng có tiêu đề "Keyboard
  Shortcuts" + nút đóng [×]. Provider vẫn nằm dưới bảng, **không bị ẩn**
  (ưa nhúng hơn phương án tạm ẩn provider). Bảng cuộn chung với nội dung;
  panel tự vừa khung khi bảng hiện, cao quá thì cuộn trong ô.
- Bấm "?" lần nữa hoặc bấm [×] → bảng biến mất, về lại chỉ có các card
  provider. Nút "?" đổi màu (accent, icon đầy) khi bảng đang hiện.
- Bảng liệt kê **10 shortcut** theo đúng thứ tự Settings → Keyboard
  Shortcuts: Smart Translation, Manual Translation, OCR Screen Translate,
  OCR to Clipboard, OCR to Clipboard - Translated, Translate Selection,
  Translate Clipboard, Screenshot Copy, Scan Barcodes/QR Codes, Fast Read (RSVP).
- Mỗi dòng có tên + phím tắt hiện tại (chưa gán thì "Not set") + nút **Run** —
  bấm là chạy thẳng hành động đó, khỏi bấm phím vật lý. Nút Run gọi đúng code
  path như bấm phím tắt (`AppDelegate.performShortcut`), nên click và phím
  không bao giờ lệch nhau. **Bấm Run thì ẩn panel để chụp** — hành vi ẩn
  panel khi chụp đi kèm sẵn theo code path phím tắt (panel ẩn, chụp xong
  hiện lại với kết quả), không cần logic riêng. Bảng cũng đóng lại sau khi
  bấm Run (đã chọn hành động, kết quả cần được thấy, không phải bảng).
  **Riêng các hành động chụp (OCR, Screenshot, Scan) thì Run ẩn panel
  TRƯỚC khi chụp (Manh 17/11 13:00):** lúc bấm Run người dùng đang nhìn
  panel nên panel sẽ che mất vùng cần chụp — giống hệt nút "Capture OCR"
  (`performPanelOCR` ẩn panel rồi mới chụp). Các hành động không chụp thì
  panel vẫn hiện để xem kết quả.
- **Nút [×] và Run phải có `InteractiveMarker` (Manh 17/11 12:39, từ test
  build #207):** bản #207 bấm [×] và Run không có tác dụng — vì 2 nút này
  thiếu `InteractiveMarker` nên panel coi click là kéo cửa sổ, nút không
  nhận được click. Mọi nút khác trong panel đều có marker này
  (xem `PopupView` / `ProviderResultCard`); nút nào mới thêm vào panel cũng
  phải có, không thì bấm không ăn.
- **Bảng này KHÔNG phải card provider** (nó không dịch gì, chỉ liệt kê
  shortcut) và **nút "?" KHÔNG nhảy sang panel shortcut (tạm thời, ở
  trái)** (Manh 17/11 12:01): panel shortcut tạm là bảng shortcut
  (decor/placeholder), sau này thành timer rest-eyes/focus/tomato; khi đó
  shortcut vẫn ở lại với nút "?" (nhúng trong ô output). Xem §9.
- **Hướng này đã CHỐT (Manh 17/11 12:19):** bảng nhúng ở ĐẦU ô output,
  provider không bị ẩn, bấm "?" lần nữa/[×] thì về lại chỉ có card
  provider, bấm Run thì ẩn panel để chụp — đúng như §7 này. Hướng này
  KHÁC đề xuất đổi nội dung ô output của chat TTS lúc 11:56 (đề xuất đó
  chỉ là ý kiến, Manh chốt theo khung bên mac). Về sau đừng ai sửa ngược
  lại thành đổi nội dung ô output khi chưa hỏi anh.
- Nút **"Fast Read"** (`book.pages` + chữ) ở đầu trái hàng Actions: bấm mở
  cửa sổ đọc RSVP riêng với đúng text đang dịch trong panel (không cần bôi
  lại). Chi tiết engine + cửa sổ đọc xem `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`.

## 8. So sánh với Windows (đối chiếu §1–§7 với doc Windows)

**5 số cốt lõi giống nhau hoàn toàn** — mac lấy từ Windows (#198, Manh 17/11):

| Hạng mục | mac | Windows | Giống? |
|---|---|---|---|
| Mở mặc định | 420×450 | 420×450 | ✅ |
| Tối thiểu | 400×450 | 400×450 | ✅ |
| Tối đa | rộng 600 / cao 800 | rộng 600 / cao 800 | ✅ |
| Cap ô output | 260 | 260 | ✅ |
| Snap-back | +8 ngang + dọc | +8 ngang + dọc | ✅ |

**Hành vi giống nhau:** auto-fit mỗi lần hiện; Settings chỉ đặt mặc định trong giải
[min, max], mở lại về mặc định, kéo tay không lưu; thử lại auto-fit 1 lần; text
cuộn trong card (cap 260), loa/Copy cố định ở đáy card; mở ở vị trí con trỏ,
không nhớ vị trí cũ; hàng Actions Pin + Settings căn phải, Pin trước; click ra
ngoài để ẩn, không nút đóng tay; Enter = dịch lại, Shift+Enter = xuống dòng;
thu/mở provider card; cỡ chữ nội dung mặc định 14 (slider 12–24).

**Khác nhau (cấu trúc, không phải số):**

| Hạng mục | mac | Windows | Lý do |
|---|---|---|---|
| Cấu trúc panel | VStack: top bar / input / divider kéo / language / ScrollView kết quả / Actions / Dictionary / footer | RootGrid 8 hàng: TitleBar / Source / Hint / Language / Output card (`*`) / Actions / Dictionary / Footer | Khác framework (SwiftUI vs WPF) |
| Min height | Cố định 400×450 | Động: `max(450, fixedH + cardMin + cardMargin + 24)` | Windows cần công thức động vì card nằm ở hàng `*` của Grid; mac không cần vì card trong ScrollView |
| Min output card | Không có (panel min 450 chi phối) | 218 | Windows cần min card để tính min panel động |
| Cap ô nguồn | Ô nhập cao tối đa 6 dòng | SourceTextBox MaxHeight 120 | Khác cách đo (dòng vs pixel) |
| Kéo resize | Grip 3 vạch 20×20 + tay nắm viền 6pt trong suốt + kẹp OS `windowWillResize` | Viền native (BottomBorder 7, RightBorder 8) + grip trang trí 12×12 + kẹp OS `WM_GETMINMAXINFO` | mac không có viền native resize cho panel borderless nên tự làm tay nắm |
| Kéo di chuyển | Cả hàng top bar (`TopBarDragMarker`) | Vùng caption là TitleBar (Row 0) | Tương đương |
| Hint | 3 dòng trên top bar (tên app + slogan + hint), căn giữa | 1 dòng riêng dưới ô nhập ("Select a word, then click Dictionary to look it up", phải vừa 1 dòng ở 400px) | mac gộp hint vào top bar; Windows tách hint thành hàng riêng |
| Cỡ chữ top bar | Tên 17 Bold / slogan 16 / hint 13 | Tên 17 Bold / slogan 16 / hint 13 | ✅ (slogan mac đổi 15 → 16 ngày 17/11) |
| Nút "?" | Có (#200), bên trái Pin | Đang làm (giao 17/11), vị trí tương tự | Cùng spec, mac làm trước |
| Loa/Copy ô nhập | Hàng riêng dưới ô text | Overlay trong ô (góc dưới-phải) | mac tách ra ngoài cho đỡ cuộn; Windows giữ overlay |

## 9. Layout 3 tab panel — khung đã lên main (Manh 17/11, build #208)

> **Khung multi-tab đã triển khai trên main (Manh 17/11 ~12:35 — "xong cả
> khung multi-tab trên main rồi mới qua nhánh + Fast Read").** 3 tab đổi được
> bằng chấm + vuốt; panel dịch là mặc định; panel Fast Read vẫn là
> placeholder cho tới khi Fast Read window xong (nhánh
> `feature/fast-read-rsvp` sync main rồi mới làm tiếp, sau khi khung này
> xanh).

- **Layout kiểu "hub": panel dịch ở GIỮA làm mặc định, trái là panel
  shortcut (tạm thời), phải là panel Fast Read.**
  - **panel dịch (ở giữa, mặc định)** — màn chính.
  - **panel shortcut (tạm thời, ở trái)**: trang shortcut đầy đủ.
  - **panel Fast Read (ở phải)**: đọc RSVP (dự kiến).
- **Lý do Manh:** panel dịch ở giữa thì vuốt sang 2 bên đều 1 lần; để
  panel dịch ở trái thì sang panel Fast Read (phải) phải qua 2 lần. Có
  tiền lệ: Snapchat (camera ở giữa, vuốt trái ra chat, phải ra stories).
  Khác thứ tự research cũ (panel dịch ở trái) nhưng lý do chính đáng nên
  đổi.
- **3 chấm hiện từ đầu để trải nghiệm (Manh 10:46).** Hàng chấm nằm dưới
  nội dung tab, trên footer (GitHub + version): 3 chấm tròn 8pt, cách nhau
  8pt, căn giữa, cao ~20pt. Chấm đang chọn màu accent, còn lại mờ.
  **Bấm chấm để đổi tab.**
- **Hàng chấm căn đều giữa nội dung tab và icon GitHub (Manh 13:00):**
  12pt trên chấm (padding trên của hàng chấm) và 12pt dưới chấm (padding
  trên của footer) — chấm nằm chính giữa khoảng trống giữa link dictionary
  / nội dung tab và icon GitHub, không lệch về bên nào.
- **Vuốt đổi tab:** vuốt ngang trên **hàng chấm** thì đổi tab (vuốt trái →
  tab bên phải, vuốt phải → tab bên trái; chỉ tính vuốt ngang rõ ràng,
  >50pt và ngang hơn dọc). Vuốt KHÔNG đặt trên nội dung tab — vì kéo chuột
  trên kết quả/input là bôi chọn text, đặt gesture vuốt lên đó sẽ cướp mất
  bôi chọn.
- **Panel shortcut (tạm thời, ở trái) dùng lại đúng `ShortcutsTableView`**
  của nút "?" (§7) — không viết bảng mới. Bấm Run thì chạy đúng code path
  phím tắt rồi **về lại panel dịch** (kết quả hiện ở panel dịch, không ở
  tab shortcut); bấm [×] cũng về panel dịch. Bảng cuộn trong ScrollView
  riêng và báo chiều cao qua cùng layout preference như kết quả dịch, nên
  auto-fit vẫn vừa khung cho tab này.
- **Panel Fast Read (ở phải) là placeholder:** icon sách + text
  "Fast Read — coming soon" + 1 dòng giải thích, căn giữa. Panel giữ chiều
  cao tối thiểu (450) ở tab này. Nội dung placeholder do bên mac tự quyết.
- **Dịch mới luôn về panel dịch:** khi có source text mới (dịch mới) thì
  panel tự về panel dịch — người dùng mở panel là để xem bản dịch, không
  phải tab họ bỏ lại lần trước.
- **Hàng chấm làm panel cao thêm ~20pt:** chiều cao fitted cho text ngắn
  từ ~480 lên ~510 — test `dismissAndReopenDiscardsPendingResize` đổi
  khoảng 450–480 thành 450–510 trong cùng commit (16pt lúc đầu, 20pt sau
  khi căn đều giữa theo Manh 13:00).
- **Vuốt 2 ngón trackpad đổi tab (Manh 13:00, làm sau #209):** vuốt ngang
  2 ngón trên trackpad (trái/phải) đổi tab. **ĐÃ ĐẢO CHIỀU 20:28 (Manh
  test thấy chiều đầu ngược):** vuốt 2 ngón sang trái → tab bên trái,
  sang phải → tab bên phải — tức là NGƯỢC chiều vuốt chuột trên hàng
  chấm (chuột kéo trái → tab phải, giữ nguyên). **DragGesture trên hàng
  chấm chỉ nhận chuột kéo, KHÔNG nhận vuốt trackpad:** vuốt 2 ngón đi
  thành event `.scrollWheel` (deltas `scrollingDeltaX/Y`), không phải
  `swipeWithEvent:` (cái đó chỉ cho vuốt 3 ngón, tuỳ System Preferences).
  Nên panel dùng 1 local monitor `NSEvent` cho `.scrollWheel`
  (`TrackpadSwipeMonitor.swift`): chỉ nhận event có gesture phase
  (trackpad, `phase != []`), tích luỹ `scrollingDeltaX` ngang trội
  (|X| > |Y| × 1.5), đủ 50pt thì đổi 1 tab (1 lần vuốt = 1 tab, bỏ qua
  momentum), vuốt dọc thì cho qua để ScrollView kết quả cuộn bình thường.
  Vuốt trackpad là scroll event, không phải chuột kéo, nên không bao giờ
  cướp bôi chọn text.
- **Chuyển tab có animation (Manh 20:38, nhanh hơn 23:55):** đổi tab mượt bằng fade
  (`.transition(.opacity)` + `.animation(.easeOut(0.15s), value:
  selectedTab)`) — trước đó đổi tab tức thì nên cảm giác đột ngột.
  0.25s ease-in-out ban đầu hơi chậm (Manh 23:55) nên rút xuống 0.15s
  ease-out cho nhanh mượt hơn. Tốc độ nhận vuốt không đổi (50pt,
  1 vuốt = 1 tab); chỉ thêm chuyển động lúc đổi tab.
- **Thứ tự làm (Manh 10:46): khung multi-tab làm trên main TRƯỚC** (layout
  hub 3 chấm); **nhánh `feature/fast-read-rsvp` sync main rồi mới làm Fast
  Read window.** Fast Read làm trước TTS (đã chốt 09:52).

- **Layout kiểu "hub": panel dịch ở GIỮA làm mặc định, trái là panel
  shortcut (tạm thời), phải là panel Fast Read.**
  - **panel dịch (ở giữa, mặc định)** — màn chính.
  - **panel shortcut (tạm thời, ở trái)**: trang shortcut đầy đủ.
  - **panel Fast Read (ở phải)**: đọc RSVP (dự kiến).
- **Lý do Manh:** panel dịch ở giữa thì vuốt sang 2 bên đều 1 lần; để
  panel dịch ở trái thì sang panel Fast Read (phải) phải qua 2 lần. Có
  tiền lệ: Snapchat (camera ở giữa, vuốt trái ra chat, phải ra stories).
  Khác thứ tự research cũ (panel dịch ở trái) nhưng lý do chính đáng nên
  đổi.
- **3 chấm hiện từ đầu để trải nghiệm (Manh 10:46 — thay điều kiện cũ).**
  Khung multi-tab lên main là hiện đủ 3 chấm luôn; **panel Fast Read (tên
  tạm) là placeholder cho tới khi tính năng này ship**. Ngoại lệ này chỉ áp
  cho panel Fast Read (đã có kế hoạch cụ thể), không áp chung cho
  mọi tab tương lai. Nội dung placeholder panel Fast Read (vd text
  "Fast Read — sắp có") bên mac tự quyết cho gọn.
- **Thứ tự làm (Manh 10:46): khung multi-tab làm trên main TRƯỚC** (layout
  hub 3 chấm); **nhánh `feature/fast-read-rsvp` sync main rồi mới làm Fast
  Read window.** Fast Read làm trước TTS (đã chốt 09:52).
- **Fast Read window copy y xì UX SwiftRead; CHỈ ĐỌC, không gồm TTS trong
  read (Manh 10:46).** SwiftRead có tính năng Listen nhưng TransPeek KHÔNG
  copy phần đó vào view đọc — nghe là việc của TTS (click icon), đọc là việc
  của RSVP; 2 luồng tách hẳn. Chi tiết engine + UX window xem
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`. **Thiết kế
  lại window (Manh 17/11 21:40, sửa 22:35):** Focus mode (Space chạy → chỉ
  line đang focus, dừng → đủ block text như trang sách, line đang đọc to
  nổi bật), góc trái trên có Estimated reading time + 2 slider + picker
  word num, góc phải trên có Settings (Color Scheme White on Black / Black
  on White) + "?" hotkey, Rewind/Play/Fast-forward/Toggle maximize window
  căn giữa đáy (KHÔNG dùng Fullscreen — window đã có 3 nút đỏ/vàng/xanh),
  đọc xong hiện "Cool! You just read X words..." trên thanh progress — xem
  `rsvp-report.md` §14. Làm sau khi tách module, trong thư mục `FastRead/`
  mới.
- **Panel shortcut (tạm thời, ở trái) là ô linh hoạt, không cố định là
  shortcut.** **Lộ trình panel ở trái (Manh 12:01): tạm thời panel này chỉ
  là bảng shortcut (decor/placeholder); SAU NÀY panel này dành cho
  rest-eyes/focus/tomato** — tab nhắc nghỉ nhẹ: 20-20-20 nghỉ mắt, focus,
  Pomodoro (theo research break reminders, bản nhẹ trong tab panel, mặc
  định TẮT).
- **Nút "?" KHÔNG nhảy sang panel shortcut (tạm thời, ở trái) (Manh
  12:01).** "?" chỉ nhúng bảng shortcut trong ô output (theo hướng 11:50 —
  nhúng đổi nội dung ô output, không tạo card mới). Lý do: bây giờ nhảy
  cũng vô nghĩa vì panel ở trái đang là bảng shortcut (cùng nội dung với
  bảng nhúng); sau này panel ở trái thành timer thì nhảy tới đó để xem
  shortcut càng sai chỗ. Khi panel ở trái đổi thành timer, shortcut vẫn ở
  lại với nút "?" (nhúng trong ô output).

## 10. Panel center + Panel left — thiết kế CHỐT (19/11/2026, v0.1.4 / build 248)

> Mục này chốt thiết kế HIỆN TẠI của panel center (dịch) và panel left
> (shortcut) như đã ship trong v0.1.4. Nó bổ sung / thay thế §9 ở những
> chỗ khác nhau (vị trí hàng chấm, nội dung panel left). Các số nền tảng
> ở §1–§8 không đổi (420×450 / min 400×450 / max 600×800 / cap output
> 260 / snap-back +8).

### 10.1 Khung 3 tab (hub) — thứ tự và hàng chấm

- Thứ tự: **panel left (1) / translate (giữa, 2, mặc định) / Fast
  Read (phải, 3)**. Panel left chứa đúng 4 mục: Instructions ("How
  the icon works") + Focus-Rest + Keyboard Shortcuts + Share (xem
  §10.3). Panel dịch ở giữa thì vuốt sang 2 bên đều 1 lần.
- Top bar + bottom bar giống nhau trên mọi tab; chỉ nội dung giữa đổi
  theo tab. Đổi tab có animation fade 0.15s ease-out.
- **Hàng chấm nằm ngay dưới top bar (CHỐT, Manh 2026-11-19 19:36 —
  không còn tạm thời, không dời nữa).** Pin ở đầu trái hàng chấm
  (`.padding(.leading, 10)`, xem §10.8), rồi chevron.left + 3 chấm +
  chevron.right căn giữa. (Mục §9 ghi hàng chấm dưới nội dung tab là vị
  trí cũ 17/11, đã lỗi thời.)
- Hàng chấm gồm: nút `chevron.left` + 3 chấm tròn 8pt (cách nhau 8pt,
  căn giữa) + nút `chevron.right`. Chấm đang chọn màu accent, còn lại
  mờ. Chevron bị mờ + không bấm được ở 2 đầu. Bấm chấm / chevron để đổi
  tab; vuốt ngang trên hàng chấm cũng đổi tab (vuốt rõ ràng >50pt, ngang
  hơn dọc); vuốt 2 ngón trackpad cũng đổi tab (50pt = 1 tab, bỏ momentum).
  Gesture vuốt đặt trên hàng chấm, KHÔNG đặt trên nội dung tab — vì kéo
  chuột trên kết quả/input là bôi chọn text.
- **Hover sáng nút (Manh 2026-11-20, "Làm cả 2"):** panel là
  `.nonactivatingPanel` nên app không bao giờ active khi panel hiện —
  macOS chỉ vẽ hiệu ứng hover khi app active, và nút `.plain` vốn không
  có gì để sáng. Nên tự vẽ hover bằng modifier chung
  `PanelHoverHighlight` (`.onHover`): nền mờ nhẹ bo tròn khi trỏ chuột
  lên nút — áp cho mọi nút panel (Pin, Capture OCR, Fast Read, "?",
  Settings, Copy, loa, "Copy source/translation", nút hàng điều khiển
  Read lite, chevron hàng chấm, nút "Read in panel" / "Done" /
  Settings / "?" ở panel phải, loa + Copy phía nguồn, nút swap ngôn
  ngữ). Không đổi style nút, không đổi viền 0.25, không kích hoạt app
  khi panel hiện. Ô nhập (source text) + 2 ô chọn ngôn ngữ (Source /
  Target) cũng có cùng highlight này (Manh 2026-11-20, 10:11).
  (Bảng đầy đủ mọi nút panel: §10.8.)
  - **Lỗi bấm không ăn, build 285 (Manh 2026-11-20, 10:11) — NGUYÊN
    NHÂN GỐC:** bản đầu vẽ tint bằng `.overlay` Shape thường — Shape
    đó nằm TRÊN nút và bắt được hit-test, nên thành hit view của cú
    click: AppKit đưa mouse-down cho view trên cùng, Shape không làm
    gì với nó, nút bên dưới không bao giờ nhận được click. (Ô nhập +
    ô chọn ngôn ngữ lúc đó chưa có modifier nên vẫn bấm được — chỉ
    khác nhau ở modifier.) **CÁCH SỬA:** tint có
    `.allowsHitTesting(false)` — highlight chỉ để nhìn, không bao giờ
    tham gia hit-test, click tới đúng nút như trước khi có modifier.
    Trạng thái gốc trước sửa: nút không có highlight tự vẽ, chỉ dựa
    vào hiệu ứng hover của hệ thống (vốn không hiện vì panel không
    active) — bấm vẫn ăn bình thường.
  - **Trạng thái bấm khác hover (Manh 2026-11-20, 10:11):** chỉ hover
    thì chưa đủ phân biệt — bấm xuống phải sáng khác hẳn. Modifier
    theo dõi trạng thái bấm bằng simultaneous `DragGesture`
    (minimumDistance 0, không chặn tap của nút, không thêm view bắt
    hit-test): hover = tint 0.08, bấm = tint đậm hơn 0.18.
- **Vuốt ngang trên thanh link từ điển — VÙNG CẤM ĐỔI TAB CỨNG
  (Manh 2026-11-20, 10:13):** vuốt 2 ngón bắt đầu trên thanh link từ
  điển thì KHÔNG BAO GIỜ đổi tab — cuộn link khi link tràn, không làm
  gì khi link vừa khung (không cuộn được). Vuốt ở chỗ khác vẫn đổi tab
  như cũ. `TrackpadSwipeMonitor` kiểm tra vị trí bắt đầu vuốt
  (`.began`) có nằm trong vùng thanh link không (thanh link mang
  `DictionaryBarMarkerView` làm background, tìm bằng rect-containment
  như `InteractiveMarkerView`); nếu có thì nhường toàn bộ gesture cho
  ScrollView. (Bản trước, "Làm cả 2", chỉ nhường khi link tràn —
  nội dung rộng hơn khung nhìn — còn link vừa khung thì vuốt trên đó
  vẫn đổi tab; Manh đổi thành vùng cấm cứng.) (Luật swipe đầy đủ: §10.9.)
- Panel phải là **Read lite** — đọc trong panel (§10.7), không còn là
  placeholder. "Fast Read — coming soon" chỉ còn là tiêu đề của trạng
  thái chưa đọc trong §10.7.

### 10.2 Panel center (dịch, tab mặc định)

- **Top bar:** tên app "TransPeek" (Bold, màu accent / xanh biển, cỡ N)
  + slogan "Translate anywhere, Peek instantly!" (N−1, nghiêng, màu
  secondary) + hint "Hover icon to translate, Click to listen" (N−4,
  màu tertiary), căn giữa. Cả hàng là vùng kéo di chuyển
  (`TopBarDragMarker`). N = `popupTopBarFontSize`, mặc định 17
  (17 / 16 / 13, khớp Windows). Tên app màu accent từ vòng 9 (trước đó
  màu mặc định).
- **Nội dung dịch (VStack):** ô nhập (cao mặc định 48, tự cao tối đa 6
  dòng, có highlight hover + bấm như nút — Manh 2026-11-20, 10:11) +
  hàng ngôn ngữ (Source ⇄ Target + Capture OCR, 2 ô chọn ngôn ngữ cũng
  có highlight hover + bấm như nút) + các card kết
  quả provider trong ScrollView (text cap 260, loa/Copy cố định ở đáy
  card) + bảng shortcut của nút "?" nhúng ở ĐẦU ô output khi bấm + hàng
  Actions + DictionaryBar. Hàng ngôn ngữ: 2 ô chọn là dropdown tìm kiếm
  (Manh 2026-11-19, 0.1.5) — bấm hiện popover với list tìm được (Popular
  20 đầu, rồi toàn bộ 249 ngôn ngữ + alias `pt` xếp A–Z theo tên tiếng Anh);
  bấm trong popover không ẩn panel (dismiss monitor coi popover là 1 phần
  của panel). List trong popover CĂN GIỮA (hàng + tiêu đề section,
  Manh 2026-11-20 — left để hở khoảng trống bên phải trông buồn cười;
  dấu check ở mép phải, chữ vẫn căn giữa đúng).
- **Hàng Actions:** nút "Fast Read" ở đầu trái (`book.pages` + chữ
  "Fast Read", HStack spacing 4 — icon và chữ cách nhau 4pt, Manh
  2026-11-19, 0.1.5: spacing 0 trước đó vẫn quá dính, gấp đôi lên) +
  Spacer + nút "?" + Settings ở đầu phải. **Pin KHÔNG ở hàng này** —
  đã dời lên hàng chấm (đầu trái, §10.1). Nút Fast Read chạy theo
  setting "Run FastRead in:" (§10.7).
- **Bảng "?" :** nhúng ở đầu ô output (trong ScrollView kết quả, ngay
  trên các card provider), tiêu đề "Keyboard Shortcuts" + nút đóng [×].
  Liệt kê 10 shortcut + nút Run (bấm Run thì chạy đúng code path phím
  tắt rồi về lại panel dịch; hành động chụp thì ẩn panel trước khi chụp).
  Bảng này KHÔNG nhảy sang panel left. Mọi nút trong panel đều phải có
  `InteractiveMarker`, không thì bấm không ăn (bài học #207).
- **Bottom bar (giống nhau mọi tab):** icon mèo GitHub 16pt + link
  "GitHub" căn giữa, text version ("Version X (Build CI #N)", ẩn số
  build khi = 1) mờ ở bên phải. Khoảng trên/dưới đều 12pt.

### 10.3 Panel left (tab 1 — Instructions + Focus-Rest + Shortcuts + Share)

- Panel left là **tab 1** với nội dung đã chốt, đúng 4 mục theo thứ
  tự từ trên xuống: (1) **Instructions — "How the icon works"**,
  (2) **Focus-Rest**, (3) **Keyboard Shortcuts**, (4) **Share** — không
  thêm, không bớt. (Nhãn "tạm thời" cũ bỏ — thẻ Focus-Rest đã ở đây,
  §10.6.)
- Nội dung nằm trong ScrollView (để auto-fit vẫn tính đúng chiều cao),
  theo thứ tự từ trên xuống:
  1. **Thẻ "How the icon works" (`FlowIntroCard`)** — ĐỘNG: các dòng
     theo đúng setting Click (Hover → dịch; Click → Fast Read / Nghe /
     Dịch; Option+Click → hành động còn lại). Thu gọn được (bấm header),
     trạng thái lưu trong `flowIntroCollapsed`. Header thẻ bấm được toàn
     bộ (có `InteractiveMarker`, không thì click bị coi là kéo cửa sổ).
  2. **Thẻ "Focus & Rest" (`FocusTimerCard`)** — Pomodoro + rest
     eyes + "Run reminder in:" (chi tiết §10.6). Ngay dưới "How the
     icon works", trên bảng Shortcuts (Manh 2026-11-20, 07:06 — dời
     lên từ dưới bảng Shortcuts).
  3. **Bảng "Keyboard Shortcuts" (`ShortcutsTableView`)** — cùng bảng
     với nút "?" ở panel center. Thu gọn được (vòng 9), trạng thái lưu
     trong `shortcutsCollapsed`. Bấm Run thì chạy shortcut rồi về lại
     panel dịch. (Bảng "?" ở panel center KHÔNG dùng chế độ thu gọn —
     header của nó vẫn là ẩn bảng như trước.)
  4. **Dãy share** — ở cuối nội dung cuộn: nhãn "Share TransPeek"
     (caption, màu secondary, căn giữa) + `ShareRowView` (6 icon, căn
     giữa). KHÔNG tạo card mới, KHÔNG dùng Spacer đẩy xuống đáy — khi
     các thẻ trên thu gọn thì khoảng trống còn lại đến đáy.
- Panel left KHÔNG ẩn bottom bar (icon mèo + version vẫn hiện).

### 10.4 Hàng chấm — mac vs Windows

| Hạng mục | mac | Windows |
|---|---|---|
| Vị trí hàng chấm | Ngay dưới top bar (**CHỐT**, Manh 2026-11-19 19:36 — giữ như hiện tại) + nút chevron 2 bên | Ở bottom bar, dưới icon GitHub (tạm thời) |
| Sau này | Đã chốt ở top bar, không dời nữa | Có thể dời lên top bar như mac (Manh 19/11) — hiện tại để tạm |

- Hàng chấm là bộ chuyển tab trên cả 2 nền tảng (bấm chấm/chevron,
  vuốt trên hàng chấm, vuốt trackpad). Panel phải bên Windows cũng là
  placeholder như mac.
- Nút pin (Manh 2026-11-20, 07:08 + 07:10 + 07:54, tạm thời) ở đầu trái hàng
  chấm, trước chevron.left, gần mép trái panel với padding nhỏ 10pt
  (chi tiết §10.7).

### 10.5 Đã làm trong 0.1.5 (19/11/2026, nhánh `feature/015-deferred-batch`)

- Nút Fast Read ở panel center: HStack spacing 0 → 4 (icon và chữ cách
  nhau thêm, gấp đôi cảm giác dính trước đó).
- Vị trí hàng chấm (mac): **CHỐT ở ngay dưới top bar** (Manh 2026-11-19
  19:36) — không còn tạm thời, không chờ quyết nữa.
- Window Read: text giữa top bar → "Rapid Serial Visual Presentation"
  (KHÔNG thêm hậu tố "— RSVP" — Manh 2026-11-19 21:10, dài và xấu;
  tiêu đề cửa sổ vẫn là "TransPeek — Fast Read RSVP"); version hiển thị
  ở góc phải trên, bên trái nút Settings (cùng dạng "Version X (build)"
  như footer panel).
- Window Read: bước đổi cỡ chữ khi vuốt trackpad dọc 8pt → 16pt / 50pt
  (trước đó phải vuốt 2–3 lần mới tới cỡ muốn).
- Ngôn ngữ: mở rộng 20 → 249 + alias `pt` (Popular 20 đầu đúng thứ tự
  Manh chốt, rồi toàn bộ A–Z); 2 ô chọn ngôn ngữ thành dropdown tìm kiếm
  (Popover + List + ô tìm TextField riêng, native — không NSComboBox,
  không tự chế); `.searchable` KHÔNG dùng được ở đây: nó đặt ô tìm vào
  toolbar mà cửa sổ popover không có toolbar — bọc `NavigationStack`
  (sửa vụ CI258) vẫn không hiện ô tìm, Manh test v0.1.5 / CI264 vẫn
  thấy thiếu; sửa 2026-11-20 bằng TextField thật đặt đầu popover
  (kèm kính lúp + nút xoá, tự focus khi mở popover). Map Google bỏ
  `pt-BR → pt` (mã biến thể giữ nguyên, không cắt ở "-"); dismiss
  monitor coi popover ngôn ngữ là 1 phần của panel.
- Icon float (Manh 2026-11-20, duyệt 02:41): icon lúc thường LUÔN là A
  thường xanh (Style 1) cho cả Click=Speak và Click=Read (translate-first;
  bỏ Style B preview idle A+/loa cũ); giữ Option → A+ (Click=Speak) hoặc
  loa (Click=Read); đang nói → loa; bấm Read → A+ 2.5s. Bỏ hẳn
  `TriggerActivationMode` (luôn hover) và bỏ "Translate (legacy)" khỏi
  "Click icon" (đổi tên thành "Click icon for:", chỉ còn Read/Speak) —
  dịch là hover, không có flow Click=Translate. Chi tiết:
  `docs/UI/UX_DESIGN/FLOAT_ICON_UX_SPEC.md` §2–§3, §7.
- Panel chính: nút **Capture OCR** có viền xanh dương, nút **Fast Read**
  có viền nghệ (0.78 / 0.50 / 0.05 — cùng màu chữ "A+" của Fast Read);
  chỉ viền lining bao ngoài nút, không tô nền, không đổi màu chữ/icon
  (Manh 2026-11-19 23:56); **làm nhạt hết cỡ, opacity 0.25** (Manh
  2026-11-20: màu đầy quá nổi, mất tập trung).
- Window Read: thêm tuỳ chọn **"Run text automatically"** (on/off,
  mặc định ON) trong Settings của cửa sổ (Manh 2026-11-20 00:47) —
  khi ON, text gửi vào từ icon chọn text tự chạy đọc luôn, không cần
  bấm Space; khi OFF, cửa sổ mở ra ở trạng thái dừng như trước.
  "Reset to default" cũng trả auto-play về ON.
- Con trỏ chuột: **theo đúng hệ thống — hệ thống quyết định hình con trỏ
  theo từng loại tương tác, không ép một loại cố định cho một loại tương
  tác** (Manh 2026-11-20 06:45, sửa quy tắc 00:14). File
  `PointingHandCursor.swift` và mọi tay chỉ tự chế đã gỡ bỏ từ 00:14.
  Link mở URL (GitHub ở bottom bar, link từ điển) hiện tay chỉ
  `NSCursor.pointingHand` của hệ thống khi di chuột lên (đó là chuẩn
  macOS cho link, không phải tay tự chế); nút bấm thường KHÔNG ép đổi
  con trỏ — giữ mặc định hệ thống (mũi tên + nút sáng lên khi hover);
  ô nhập text hiện I-beam (mặc định). Con trỏ resize panel đã ổn định
  và đã chốt, KHÔNG động vào nữa (không nối lại
  `PopupResizeCursorMonitor`; `PopupPanelController.swift` giữ nguyên
  như main).

### 10.6 Thẻ "Focus & Rest" ở panel left (20/11/2026, nhánh `feature/focus-timer-decor`)

- Nằm **ngay dưới "How the icon works", trên bảng "Keyboard
  Shortcuts"** (Manh 2026-11-20, 07:06 — dời lên từ dưới bảng
  Shortcuts). File riêng
  `Sources/UI/PopupPanel/FocusTimerCard.swift`, dễ xoá sau này.
  Thu gọn được (header bấm toàn bộ, trạng thái lưu
  `focusTimerCollapsed), giống 2 thẻ trên.
- **Pomodoro — theo CHUẨN:** Work 25 / Rest 5 mặc định, có picker
  đổi (Work: 5/10/15/20/25/30/45/60; Rest: 5/10/15); nhãn picker ghi
  luôn default ("Work (default: 25 min):"). Sau 4 chu kỳ focus →
  nghỉ dài 15 phút. 4 chấm tròn hiện số chu kỳ đã xong + dòng "Long
  break 15 min after 4 cycles". Nút Start/Pause/Resume + Reset.
  Hết 1 khoảng Work → nhắc nghỉ theo "Run reminder in:"; hết Rest /
  nghỉ dài → về idle, chờ bấm Start (không tự chạy focus tiếp) —
  TRỪ khi bật **"Repeat automatically"** (Manh 2026-11-20, 07:12;
  mặc định BẬT, Manh 2026-11-20, 07:25): toggle trong thẻ, mặc định
  BẬT nên hết Rest / nghỉ dài tự chạy focus tiếp (Work → Rest →
  Work …, nghỉ dài 15 phút sau 4 chu kỳ rồi Work lại), lặp liên tục
  tới khi tắt toggle hoặc bấm Reset/Dừng; TẮT toggle thì hết phiên
  chờ bấm Start như cũ. Chuyển phiên tự động vẫn theo luật nhắc nghỉ
  (đang đọc thì chỉ thông báo, không cướp màn hình — xem dưới).
  **"Auto start focus"** (Manh 2026-11-20, 09:47; toggle trong thẻ,
  mặc định TẮT, nhãn ghi "Auto start focus (default: Off)"): khi BẬT,
  focus tự chạy ngay mỗi lần mở app — như thể user bấm Start (đủ 1
  khoảng Work, rồi nhắc nghỉ / chạy tiếp theo "Repeat automatically"
  như bình thường); không cần mở panel bấm Start. Chỉ chạy từ idle —
  đang chạy thì không khởi động lại. Bật toggle giữa chừng (app đang
  chạy) không tự chạy phiên mới — chỉ có tác dụng từ lần mở app sau.
  Key `focusAutoStart` (`transpeek_focusAutoStart`, mặc định false);
  AppDelegate gọi `focusTimerStore.autoStartFocusIfEnabled()` cuối
  `applicationDidFinishLaunching`, sau khi đã nối xong callback nhắc
  nghỉ.
- **Rest eyes (20-20-20)** — mục riêng trong cùng thẻ: cứ 20 phút
  nhắc nghỉ mắt 20 giây (cố định, không picker — luật 20-20-20 là
  chính nó). Mặc định TẮT (Manh 2026-11-20, 07:25): không nhắc gì
  cho tới khi user bấm "Start eye reminders"; khi bật thì cứ 20 phút
  nhắc 1 lần, lặp lại. Nút Start/Stop riêng, chạy độc lập với
  Pomodoro. Icon: heart (focus) + footsteps (đi bộ / nghỉ).
- **"Run reminder in:"** — 2 lựa chọn: **"New Fast Read Window"**
  (nhắc nghỉ mở cửa sổ Rest riêng) và **"Right Panel"** (nhắc nghỉ
  hiện ngay trong panel phải, không mở cửa sổ riêng). Setting này
  **CHỈ áp cho reminder** — Fast Read có nút chọn RIÊNG ("Run
  FastRead in:" ở panel phải, §10.7); 2 tính năng không dùng chung
  1 setting (Manh 2026-11-20, 05:27).
- **Cửa sổ Rest** (`Sources/FocusTimer/RestWindowController.swift`,
  tiêu đề "TransPeek — Rest", 560×400, min 480×320): RSVP-đọc câu
  nhắc ("You have read, worked, and sat for X minutes continuously.
  Rest your eyes and brain. Stand up and walk around. Be more
  physically active." / "Rest your eyes. Look at something 20 feet
  away for 20 seconds.") bằng ĐÚNG engine + view model của Window
  Read, hiện bằng view đọc gọn riêng (`CompactReadingView` trong
  `PanelFastReadView.swift` — file Window Read `RSVPView.swift` để
  nguyên không sửa, Manh 2026-11-20, 05:36; chỉ dùng chung logic đọc,
  không copy code). Đọc xong →
  hiện countdown nghỉ (5 phút / 20 giây) rồi tự đóng; nút Done đóng
  sớm. Không đụng tới cửa sổ Read đang mở.
- **Nhắc nghỉ lúc đang đọc** (Manh 2026-11-20, 05:33): timer tới giờ
  mà user đang đọc (cửa sổ Read hay trong panel) thì KHÔNG cướp màn
  hình — chỉ hiện banner trong panel (trên mọi tab) + thông báo hệ
  thống macOS, có 2 nút "Take a break" (hiện nhắc nghỉ ngay theo
  "Run reminder in") và "Snooze 5 min" (nhắc lại sau 5 phút). Cứ đọc
  tiếp thì nhắc nghỉ chờ đó (chấm cam ở thẻ Focus & Rest); dừng đọc
  (đóng cửa sổ Read / đóng view đọc trong panel / hết countdown nghỉ)
  thì nhắc nghỉ tự hiện. Không đang đọc thì hiện nhắc nghỉ luôn theo
  setting. Áp cho cả 2 lựa chọn "Run reminder in". (Vị trí hiển thị +
  cơ chế đầy đủ: §10.11.)

### 10.7 Panel phải — đọc trong panel + demo focus (20/11/2026, nhánh `feature/focus-timer-decor`)

- Khi chưa đọc: vẫn có "Fast Read — coming soon" + **demo focus**
  phía dưới: từ **"reading"**, chữ **"a" tô vàng**, gạch nửa trên/dưới
  chỉ vào giữa chữ "a" (như Windows) — dùng chung `ORPLineView` với
  Window Read nên demo không bao giờ lệch với chữ đọc thật. Dưới
  demo là nút **"Read in panel"** (đọc text đang có ở tab dịch, ngay
  trong panel — luôn đọc trong panel, không theo setting dưới) và
  nút chọn **"Run FastRead in:"**.
- **"Run FastRead in:"** (Manh 2026-11-20, 05:27) — 2 lựa chọn bằng
  nút chọn tròn **radio** (Manh 2026-11-20, 07:02, không phải
  dropdown): **"Right Panel"** và **"New Fast Read Window
  (Recommended)"** (mặc định — giữ hành vi hiện tại). Áp TOÀN CỤC
  cho mọi lần mở Fast Read (nút Fast Read ở tab dịch, click icon,
  menubar, phím tắt): chọn 1 trong 2 thì RSVP chỉ hiển thị theo lựa
  chọn đó. Một điểm vào duy nhất ở `AppDelegate.showFastRead(text:)`
  — mọi đường mở đều qua đó nên setting chỉ kiểm tra ở 1 chỗ. Riêng
  với "Run reminder in:" ở panel trái (§10.6): 2 setting độc lập,
  không ảnh hưởng nhau.
- **Nút "Fast Read" ở panel center — hành vi CHỐT:** bấm nút thì chạy
  theo "Run FastRead in:" — chọn "New Fast Read Window" thì mở cửa sổ
  Window Read và chạy chữ ở đó; chọn "Right Panel" thì **tự chuyển tab
  sang panel phải VÀ chạy chữ ngay trong panel** (cùng engine RSVP;
  `AppDelegate.showFastRead(text:)` là điểm vào duy nhất cho mọi đường
  mở). (Manh 2026-11-20, 11:00, bản build 286: bấm nút khi chọn Right
  Panel chưa tự chuyển tab — phải swipe tay sang phải mới thấy chữ chạy.
  Nguyên nhân: `PopupView` giữ store bằng `let` thường nên `.onChange`
  của `panelRightRequest` chỉ chạy khi có state khác re-render body;
  sửa bằng `.onReceive` trực tiếp trên publisher của store — tab tự
  chuyển ngay khi bấm, không cần re-render. Đã sửa sau v0.1.7.)
- Khi đọc trong panel: ẩn hẳn "coming soon" + quyển sách, hiện view
  đọc gọn riêng (`CompactReadingView` trong `PanelFastReadView.swift`
  — chỉ dùng chung LOGIC đọc `RSVPViewModel` + `RSVPEngine` với Window
  Read, KHÔNG copy 2 bộ; file Window Read `RSVPView.swift` để nguyên
  không sửa, Manh 2026-11-20, 05:36). Cỡ chữ focus trong panel
  KHÔNG bị chặn (Manh 2026-11-20, 07:02 — bỏ cap 48/64pt): vuốt
  dọc đổi cỡ chữ bao nhiêu cũng được, user tự chỉnh cho vừa frame;
  setting cỡ chữ không đổi, cửa sổ vẫn mở đúng cỡ user chọn.
- **Hiển thị theo size (Manh 2026-11-20, 04:44; thứ tự khi pause,
  Manh 2026-11-20, 09:16; dòng phím tắt lên trên thanh progress,
  Manh 2026-11-20, 09:41):** khi pause, đọc từ trên xuống là
  [top bar: 4 picker + Settings + "?"] → [vùng đọc] →
  [dòng phím tắt] → [progress: "X / tổng" + thanh] →
  [hàng nút ở dưới cùng].
  Hàng top (cả 2 size) căn dưới (`.bottom`, Manh 2026-11-20,
  09:06) để Settings + "?" ngang hàng với menu picker, không bị
  đẩy lên cao hơn bản cũ (picker là cột 2 tầng nhãn + menu, nút
  icon chỉ 1 tầng nên căn giữa làm nút nổi lên trên). Progress
  vẫn ở DƯỚI vùng đọc, không lên top ("180" của Manh là số build
  CI280, không phải số trang).
  - Đang chạy (play): CHỈ focus text + around text + dòng phím tắt.
  - Pause, panel bé: top row có đủ 4 picker như top bar (Speed /
    Focus size / Context size / Words at once, spacing gọn 6pt cho
    vừa panel 420pt) + Settings + "?" ở góc phải trên (Manh
    2026-11-20, 07:54 — frame nhỏ vẫn đủ ô; "?" đặt cạnh Settings),
    rồi vùng đọc, rồi dòng phím tắt, rồi thanh progress nhỏ, hàng
    nút X / Restart / Rewind / Play / Forward / Maximize căn giữa
    dưới cùng (Manh 2026-11-20, 07:02 — X + Restart có cả khi
    panel bé).
  - Pause, panel gần max (rộng nội dung ≥ 540pt, tức panel ≈ 580+
    trên max 600): đủ nút + mô tả như Window Fast Read — top bar 4
    picker (Speed / Focus size / Context size / Words at once) +
    Settings + "?", rồi vùng đọc, completion + share khi đọc xong,
    dòng phím tắt, progress, hàng 5 nút + Reading time ở góc trái
    (dòng phím tắt đã dời khỏi hàng nút lên trên thanh progress,
    Manh 2026-11-20, 09:41).
- **Tương tác trong panel phải:** vuốt dọc trackpad đổi cỡ chữ
  (±16pt / 50pt, như cửa sổ — monitor riêng chỉ dọc, vuốt ngang vẫn
  chuyển panel 1/2/3 như cũ); phím tắt Space / ←/→ / ↑/↓ vẫn chạy
  (Shift+←/→ = theo câu); lùi/tiến slide bằng phím ←/→ hoặc nút
  Rewind/Forward (KHÔNG vuốt ngang).
- **Nút X + Esc 2 nấc** (Manh 2026-11-20, 07:02): nút X đặt ngay
  TRÁI nút Restart trong hàng nút (cả khi panel bé lẫn full), tooltip
  "Close reading (Esc)" — bấm X đóng bài đọc, về lại panel phải mặc
  định. Phím Esc làm đúng việc đó: Esc lần 1 (đang đọc) đóng bài đọc
  về panel phải; Esc lần 2 (đã về mặc định) mới thoát cả panel. Làm
  bằng hook `onEscape` trong `PopupDismissMonitor` — monitor chặn
  Esc trước SwiftUI nên view đọc không bao giờ thấy phím Esc.
- **Nút pin ở CẢ 3 panel (tạm thời)** (Manh 2026-11-20, 07:08 +
  07:09 + 07:10 + 07:54): nằm ở hàng chấm (dotsRow, dùng chung cả 3 tab nên
  hiện cả 3 panel), bên trái chevron.left, gần mép trái panel với
  padding nhỏ 10pt cho đẹp (was 4pt, dịch phải 6pt, Manh 2026-11-20,
  07:54; không dính sát mép, không padding lớn như hàng thường). Chức năng không đổi: khi bắt đầu đọc trong panel,
  panel tự bật pin (click ra ngoài không làm mất bài đọc); user bấm
  nút để tắt. Đọc trong panel thì auto-fit bị đóng băng
  (cùng cơ chế manual-resize) để panel cao không bị co lại; hết đọc
  thì auto-fit chạy lại. Nút Maximize đổi panel giữa cỡ mặc định
  (420×450) và max (600×800), giữ mép trên cố định — max bị chặn
  thêm bởi khung hiển thị (visible frame, Manh 2026-11-20, 08:11)
  nên không bao giờ che Dock / menu bar khi màn hình nhỏ.
- **Nhắc nghỉ ở panel phải** ("Run reminder in:" = "Right Panel"):
  hết khoảng Work / 20 phút mắt → panel hiện lên (nếu đang ẩn) ở tab
  phải và tự đọc câu nhắc; đọc xong hiện countdown nghỉ (5 phút /
  20 giây) rồi về lại demo. Bấm nút Fast Read ở tab dịch (mở cửa sổ)
  hoặc ẩn panel thì đọc trong panel dừng hẳn (không chạy ngầm).
- **Banner nhắc nghỉ chờ** (Manh 2026-11-20, 05:33): khi timer tới
  lúc đang đọc, banner hiện trên mọi tab (dưới hàng chấm) với 2 nút
  "Take a break" / "Snooze 5 min"; chấm cam ở thẻ Focus & Rest báo
  có nhắc chờ. Banner là view riêng (tự observe store) nên panel
  không re-render theo từng giây của timer.

### 10.8 Buttons — official inventory (finalized 2026-11-20)

Two rules apply to EVERY panel button:

- **`InteractiveMarker` (background) is mandatory.** Without it,
  `PopupPanel` treats the click as a window drag and the button never
  fires (build #207). Every button added to the panel must carry one.
- **`.panelHoverHighlight()` is mandatory** (modifier in
  `Sources/UI/PopupPanel/PanelHoverHighlight.swift`). The panel is
  `.nonactivatingPanel`, so the system hover never draws — the
  highlight is drawn by hand: a rounded translucent tint on
  `.onHover` (hover = `Color.primary` 0.08, pressed = clearly deeper
  0.18, tracked by a simultaneous zero-distance `DragGesture` that
  never blocks the tap). The tint has `.allowsHitTesting(false)` —
  purely visual, never intercepts clicks (build 285 lesson: a
  hit-testable `.overlay` Shape on top of a button swallows the click
  and the button never fires). It does not change the button style
  (`.plain` stays `.plain`, `.bordered` stays `.bordered`) and does
  not touch the settled 0.25-opacity borders.
- **Cursor (see §10.5):** links → system pointing hand; plain buttons
  → system default arrow (+ the highlight above); text fields →
  I-beam; panel resize cursor untouched.
- **Tooltip delay (settled, Manh 2026-11-20):** hover hints (`.help()`)
  appear after **300 ms**, not the macOS default ~1 s. Set once at
  launch in `AppDelegate` (`UserDefaults.standard.register(defaults:
  ["NSInitialToolTipDelay": 300])`) — `register` keeps a hand-set
  value, and it writes to TransPeek's own defaults domain only, so
  other apps and the system-wide setting are untouched. No Settings
  UI for it (fixed 300 ms); all ~80 `.help()` tooltips use it.

| Button | Where | Action | Style / notes |
|---|---|---|---|
| Pin | dotsRow, left end (`.padding(.leading, 10)`), all 3 tabs | Toggle pin — pinned = outside click does NOT dismiss; auto-pins when a panel read starts | `.plain`; `pin` / `pin.fill`, accent when pinned |
| chevron.left / chevron.right | dotsRow, flanking the 3 dots | Previous / next tab; disabled + dimmed (secondary 0.3) at the ends | `.plain`, `.caption` |
| 3 dots | dotsRow, centered (8pt, spacing 8) | Tap = jump to that tab (selected = accent, others secondary 0.4) | `.plain`, Circle 8pt — **no hover tint** (indicators, not buttons) |
| Capture OCR | Language-bar row, right | Capture screen OCR → panel with the result | `.plain`, blue border 0.25 opacity |
| Fast Read | Actions row, left end | Run Fast Read per "Run FastRead in:" (§10.7) | `.plain`, turmeric border 0.25 opacity |
| "?" | Actions row, right (left of Settings) | Toggle the shortcuts table embedded at the top of the output | `.plain`; accent + filled icon while open |
| Settings (gear) | Actions row, right end | Open Settings | `.plain` |
| Copy / speaker (provider card) | Bottom of each provider card, fixed outside the scrolling text | Copy / speak that card's text | `.bordered` |
| Copy source / Copy translation | Result area | Copy the source / translated text | `.bordered` |
| Speaker / Copy (source row) | Under the input box, right side | Speak / copy the source text | Same hover/pressed tint |
| Swap ⇄ | Language bar, between Source and Target pickers | Swap source/target languages | Same hover/pressed tint |
| Source input box | Panel center, top | Editable input (Enter = re-translate, Shift+Enter = newline; max 6 lines) | TextEditor — same hover/pressed tint as buttons |
| Source / Target pickers | Language bar | Open the searchable language popover (Popular 20 first, then all 249 + `pt`) | Dropdown — same hover/pressed tint |
| X (Close reading) | Read lite control row, immediately left of Restart (panel only) | Close the reading, back to panel-right default (= first Esc) | `.bordered` |
| Restart | Read lite control row | Back to slide 0, reset the timer, play from the start | `.bordered` |
| Rewind / Play-Pause / Forward | Read lite control row | Step back / toggle play-pause / step forward | `.bordered` (Play = `.borderedProminent`) |
| Maximize | Read lite control row, right end | Toggle panel default (420×450) ↔ max, clamped to the visible frame (never covers the Dock) | `.bordered` |
| "Read in panel" | Panel-right demo state | Read the translate-tab text right here in the panel — always in-panel, ignores "Run FastRead in:" | `.bordered` |
| "Run FastRead in:" radios | Panel-right demo state | Global Fast Read destination: Right Panel / New Fast Read Window (Recommended), default Window | `.radioGroup` Picker |
| "?" / Settings (Read lite top bar) | Panel-right paused top bar, top-right | Open the hotkeys table / Settings popover | `.plain` |
| GitHub link | bottomBar, centered | Open the repo in the browser | Link — system pointing hand on hover |
| [×] / Run (shortcuts table) | Embedded shortcuts table ("?") and panel-left table | [×] hides the table; Run runs that shortcut's code path, then back to the translate tab | Both carry `InteractiveMarker` |

### 10.9 Scroll / swipe — official rules (finalized 2026-11-20)

- **Trackpad 2-finger horizontal swipe → switch tabs.** Works
  anywhere on the panel EXCEPT the dictionary link bar (hard zone
  below). Local `NSEvent` `.scrollWheel` monitor
  (`TrackpadSwipeMonitor`): only trackpad-phase events
  (`phase != []`), momentum ignored; horizontal must dominate
  (`|X| > |Y| × 1.5`); 50pt accumulated = 1 tab (1 swipe = 1 tab).
  Direction is FLIPPED vs the mouse drag: fingers left → previous
  (left) tab, fingers right → next (right) tab. Vertical 2-finger
  swipes pass through (the result ScrollView scrolls normally).
- **Mouse-drag swipe → dots row ONLY.** `DragGesture`
  (minDistance 20) on the dotsRow: a clear horizontal drag (>50pt,
  wider than tall) switches tabs — drag left → next (right) tab, drag
  right → previous (left) tab. Never on tab content: dragging on
  results/input is text selection.
- **Dictionary link bar = HARD no-switch zone.** A swipe beginning
  over the bar NEVER switches tabs: it scrolls the links (horizontal
  ScrollView) when they overflow, and does nothing when they fit.
  The bar carries a `DictionaryBarMarkerView` background; the monitor
  checks rect containment on `.began` (same pattern as
  `InteractiveMarkerView`). Swipes anywhere else still switch tabs.
- **Panel right vertical swipe → font size.** In panel right, a
  vertical trackpad swipe changes the focus font size (±16pt / 50pt,
  no cap); horizontal swipe still switches panels (except over the
  dictionary bar). Keyboard in the panel: Space play/pause, ←/→ step,
  ↑/↓ speed; the hint row reads "Space play/pause • ←/→ step •
  ↑/↓ speed • Swipe ↑/↓ font size".
- **Other scrolling:** provider results scroll vertically (text
  scrolls inside each card, cap 260, speaker/Copy fixed at the card
  bottom); the language popover list scrolls vertically (search via an
  explicit TextField at the top — `.searchable` does not work in
  popovers, they have no toolbar); panel left scrolls vertically in
  its own ScrollView; the "?" shortcuts table scrolls with the
  results.

### 10.10 Open items (NOT settled — do not treat as final)

- **Name unification (Manh to decide later):** "Context size"
  (picker label, `contextSizeRatio`) vs "Around text size" (the size
  of the text around the focus word) name the same setting; other
  names may also differ between Window Read and Read lite. One name
  will be chosen and applied to UI labels + docs together. Do NOT
  rename anything until Manh approves. (Recorded 2026-11-20.)
- **Share buttons pointing hand (open question, 2026-11-20):** Share
  buttons (`ShareRowView`) open share URLs — should they also show the
  system pointing hand like other links? Currently NOT included.
  Undecided.
- **Reminder / notification language (open question):** the reminder
  text, banner and system notification are English, per the UI-language
  decision (English first, Vietnamese later, Manh 2026-11-11). Manh has
  NOT confirmed whether he wants Vietnamese there. Do not translate
  until he approves.

### 10.11 Focus reminder — where it shows + what happens while reading (finalized 2026-11-20)

A reminder fires when a Pomodoro Work interval ends or a 20-20-20
eye-rest interval ends (Manh 2026-11-20, 05:33). Where it shows
depends on whether the user is reading, and on "Run reminder in:"
(§10.6). The reminder never turns the panel into a window (the
translate UI stays a panel, §3) — the only window involved is the Rest
window, and only when the setting says so.

**Reminder texts** (`FocusReminderKind`,
`Sources/FocusTimer/FocusTimerStore.swift`):
- Work break (X = the Work minutes just finished): RSVP text "You have
  read, worked, and sat for X minutes continuously. Rest your eyes and
  brain. Stand up and walk around. Be more physically active."
  Rest-window title "Take a break". Notification/banner title "X
  minutes of work done — time for a break".
- Eye rest: RSVP text "Rest your eyes. Look at something 20 feet away
  for 20 seconds." Rest-window title "Rest your eyes".
  Notification/banner title "Time to rest your eyes (20-20-20)".

**Not reading — shows directly, per "Run reminder in:"** (§10.6; this
picker applies ONLY to the reminder — Fast Read has its own separate
"Run FastRead in:", §10.7):
- "New Fast Read Window": a separate Rest window (`RestWindowController`,
  title "TransPeek — Rest", 560×400 centered on screen, min 480×320).
  It RSVP-reads the reminder text (same engine + view model as Window
  Read, rendered by `CompactReadingView`; `RSVPView.swift` untouched),
  then shows the rest countdown (5 min for a work break / 20 s for eye
  rest) and closes itself at zero; "Done" closes early, Esc closes. Its
  own window with its own view model — it never touches an open Fast
  Read window. A new reminder closes any previous Rest window first.
- "Right Panel": the panel is brought forward at the cursor, switches
  to the Fast Read tab (panel right), and RSVP-reads the reminder text
  there (`CompactReadingView`, auto-play); after the read it shows the
  rest countdown (5 min / 20 s) and then returns to the demo (see §10.7
  for the Read lite layout).

**Reading — conflict (Manh 2026-11-20, 05:33):** "reading" means a
panel-right read is running OR the Fast Read window is open
(`FocusTimerStore.isReading`). The reminder does NOT steal the screen.
All three appear at once:
- **In-panel banner** (`PendingReminderBanner`,
  `Sources/FocusTimer/PendingReminderBanner.swift`): directly below the
  dots row, above the tab content, on ALL tabs (`PopupView.activeContent`:
  topBar → dotsRow → banner → tab content → bottomBar). Orange bell icon
  + the notification title (bold) + caption "Your reading stays as it
  is." + two buttons: "Take a break" (prominent) and "Snooze 5 min".
  Its own view observing the store, so the panel does not re-render on
  the timer's 1-second ticks.
- **macOS system notification** (`ReminderNotifier`, UserNotifications,
  category `transpeek.focusReminder`): title = notification title, body
  = reminder text, default sound, same two actions ("Take a break" shows
  the reminder at once; "Snooze 5 min" reminds again in 5 minutes).
  Shown even when the app is frontmost. One notification at a time — a
  re-fire replaces the old one instead of piling up. Permission is asked
  on first use if undecided; if denied, nothing is posted and the
  reminder is NOT lost — the banner + card dot still work.
- **Orange dot** on the Focus & Rest card: an 8pt orange circle in the
  card header, right after the "Focus & Rest" title (tooltip "A break
  reminder is waiting"), visible while a reminder is pending.

**The two actions:**
- "Take a break" (`takePendingBreakNow`): shows the pending reminder at
  once, even mid-read, per "Run reminder in:".
- "Snooze 5 min" (`snoozePendingReminder`): keeps the reminder pending
  and fires it again after 5 minutes (5 × 60 s) — if the user is still
  reading it notifies again (banner + notification + dot); if not, it
  shows directly. Spelled "Snooze 5 min" with a space ("5min" without a
  space is wrong).

**When a pending reminder shows on its own:** as soon as reading stops
— the Fast Read window closes, the panel read ends, the panel is
dismissed, or the panel reminder countdown finishes. Applies to BOTH
"Run reminder in:" options. A new read replacing the old one does NOT
trigger it (the user is still reading, so the reminder keeps waiting).

## Liên kết

- [Icon float UX](FLOAT_ICON_UX_SPEC.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
- [Kiến trúc](../../ARCHITECTURE.md)
- [Việc đang làm / chờ](../../TASK_QUEUE.md)
- [Trạng thái dự án](../../PROJECT_STATE.md)
- [Chỉ mục UX](../../UI_DESIGN.md)
- [Panel UX Windows (đã chốt)](https://github.com/TranManhTuanLabs/TransPeek-Windows/blob/main/docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
