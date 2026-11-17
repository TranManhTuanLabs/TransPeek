# Float / Popup Panel — UX Spec (CHỐT)

> **Trạng thái: CHỐT — 17/11/2026, theo build #200 (commit `3bad511`) + các đổi mới sau đó trên main (slogan 16, loa/Copy cố định từng card, bỏ Remember Last Popup Position).**
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
| Actions | **"?" + Pin + Settings.** Căn phải, Spacing 4. "?" (nút `questionmark.circle`) đứng ngay bên trái Pin; Pin trước, Settings sau (như Windows) | Xem §7 |
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

## 7. Nút "?" bảng shortcut (Manh 17/11, build #200)

- Nút `?` (`questionmark.circle`) đứng ngay bên trái nút Pin ở hàng Actions.
- Bấm mở 1 **popover** neo vào nút (bấm ra ngoài hoặc bấm lại "?" là đóng),
  liệt kê **9 shortcut** theo đúng thứ tự Settings → Keyboard Shortcuts:
  Smart Translation, Manual Translation, OCR Screen Translate, OCR to
  Clipboard, OCR to Clipboard - Translated, Translate Selection, Translate
  Clipboard, Screenshot Copy, Scan Barcodes/QR Codes.
- Mỗi dòng có tên + phím tắt hiện tại (chưa gán thì "Not set") + nút **Run** —
  bấm là chạy thẳng hành động đó, khỏi bấm phím vật lý. Nút Run gọi đúng code
  path như bấm phím tắt (`AppDelegate.performShortcut`), nên click và phím
  không bao giờ lệch nhau.

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

## 9. Layout 3 tab panel — hướng sau này (CHƯA LÀM, chỉ ghi quyết định)

> **Quyết định đã chốt (Manh 17/11 ~10:33, từ chat TTS). Chưa triển khai tab
> lúc này** — chỉ ghi lại để lúc làm multi-tab (mục 5 theo thứ tự research)
> thì làm theo layout này, không làm theo thứ tự cũ (Dịch là tab 1).

- **Layout kiểu "hub": Dịch ở GIỮA làm mặc định (chấm 2), trái là tab 1
  shortcut, phải là tab 3 Fast Read.**
  - Tab 2 (giữa, mặc định): Dịch — màn chính.
  - Tab 1 (trái): trang shortcut đầy đủ.
  - Tab 3 (phải, dự kiến): Fast Read (đọc RSVP).
- **Lý do Manh:** Dịch ở giữa thì vuốt sang 2 bên đều 1 lần; để Dịch ở tab 1
  thì sang Fast Read phải qua 2 lần. Có tiền lệ: Snapchat (camera ở giữa,
  vuốt trái ra chat, phải ra stories). Khác thứ tự research cũ (Dịch là tab 1)
  nhưng lý do chính đáng nên đổi.
- **3 chấm hiện từ đầu để trải nghiệm (Manh 10:46 — thay điều kiện cũ).**
  Khung multi-tab lên main là hiện đủ 3 chấm luôn; **tab 3 là placeholder cho
  tới khi Fast Read ship**. Ngoại lệ này chỉ áp cho tab 3 Fast Read (đã có kế
  hoạch cụ thể), không áp chung cho mọi tab tương lai. Nội dung placeholder
  tab 3 (vd text "Fast Read — sắp có") bên mac tự quyết cho gọn.
- **Thứ tự làm (Manh 10:46): khung multi-tab làm trên main TRƯỚC** (layout
  hub 3 chấm); **nhánh `feature/fast-read-rsvp` sync main rồi mới làm Fast
  Read window.** Fast Read làm trước TTS (đã chốt 09:52).
- **Fast Read window copy y xì UX SwiftRead; CHỈ ĐỌC, không gồm TTS trong
  read (Manh 10:46).** SwiftRead có tính năng Listen nhưng TransPeek KHÔNG
  copy phần đó vào view đọc — nghe là việc của TTS (click icon), đọc là việc
  của RSVP; 2 luồng tách hẳn. Chi tiết engine + UX window xem
  `docs/RESEARCH/tts-speechify-naturalreader/rsvp-report.md`.
- **Tab 1 là ô linh hoạt, không cố định là shortcut.** Hiện tại ghi tạm là
  shortcut; sau này thay được bằng nội dung khác (không khóa tab 1 = shortcut
  vĩnh viễn).
- **Nút "?" popover shortcut (§7) giữ nguyên** — xem nhanh shortcut trong
  panel Dịch; tab 1 là trang shortcut đầy đủ, không thay thế nút "?".

## Liên kết

- [Icon float UX](FLOAT_ICON_UX_SPEC.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
- [Kiến trúc](../../ARCHITECTURE.md)
- [Việc đang làm / chờ](../../TASK_QUEUE.md)
- [Trạng thái dự án](../../PROJECT_STATE.md)
- [Chỉ mục UX](../../UI_DESIGN.md)
- [Panel UX Windows (đã chốt)](https://github.com/TranManhTuanLabs/TransPeek-Windows/blob/main/docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
