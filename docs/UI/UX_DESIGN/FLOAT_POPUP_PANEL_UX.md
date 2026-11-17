# Float / Popup Panel — UX Spec (CHỐT)

> **Trạng thái: CHỐT — 17/11/2026, theo build #200 (commit `3bad511`).**
>
> Các con số trong doc này là **spec**. Đổi bất kỳ số đã chốt nào cũng cần Manh duyệt trước.
>
> Spec đã bao gồm: size 420×450 / min 400×450 / max 600×800 (#198) + nút "?" bảng
> shortcut (#200) + loa/Copy ở trong ô output (chốt 17/11, cả 2 repo).
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
| Top bar | **Tên app + slogan + hint, căn giữa.** Tên app "TransPeek" Bold, slogan "Translate anywhere, Peek instantly!" (chỉ hoa T và P, Manh cố ý), hint "Hover icon to translate, Click to listen". **Cả hàng là vùng kéo di chuyển** (`TopBarDragMarker`) — panel không có title bar riêng | Cỡ chữ theo Settings `popupTopBarFontSize` mặc định **17**: tên app = N, slogan = N−2 (sàn 8), hint = N−4 (sàn 8). Mặc định: 17 / 15 / 13 |
| Ô nhập | **SourceInputView** — ô nhập, sửa được, cao mặc định 48, tự cao tối đa 6 dòng (`inputSixLineHeight`). Enter = dịch lại, Shift+Enter = xuống dòng. Dưới ô text là 1 hàng riêng: hint phím tắt (trái) + View picker + loa + Copy (phải) — loa/Copy **nằm ngoài ô text** (dưới ô), lúc nào cũng thấy | `popupInputHeight` 48 |
| Divider kéo | **DraggableDividerView** — kéo để đổi chiều cao ô nhập | |
| Hàng ngôn ngữ | **Source ⇄ Target + Capture OCR.** Pickers ngôn ngữ trái, nút Swap ⇄ giữa, nút "Capture OCR" (icon + chữ) phải | |
| Divider | Đường kẻ ngang | |
| Kết quả | **ScrollView chứa các ProviderResultCard** (1 card / provider). Mỗi card: header (tên provider + trạng thái) / text kết quả (chọn được, báo selection cho DictionaryBar) / hàng loa + Copy **ở trong card, dưới text** (xem §6) | Cap output 260; text dài cuộn trong ô |
| Actions | **"Fast Read" + "?" + Pin + Settings.** Căn phải, Spacing 4. "Fast Read" (icon `book.pages` + chữ, mở cửa sổ đọc RSVP với text đang dịch) ở đầu trái của hàng; "?" (nút `questionmark.circle`) đứng ngay bên trái Pin; Pin trước, Settings sau (như Windows) | Xem §7 |
| DictionaryBar | **DictionaryBarView** — link tra từ điển theo text đang chọn (trong ô nhập hoặc trong kết quả) | |
| Footer | **Link GitHub căn giữa + text version căn phải** ("Version 0.1.3 (Build CI #200)" — ẩn số build khi = 1) | |

### Cỡ chữ theo Settings (chạy lúc mở panel và khi lưu Settings)

- **"App name & Slogan Font Size"** (`popupTopBarFontSize`, mặc định **17**, slider 12–24): tên app = N Bold, slogan = N−2, hint = N−4 (sàn 8). Mặc định: 17 / 15 / 13.
- **"Popup Font Size"** (`popupFontSize`, mặc định **14**, slider 12–24): chữ trong cả 2 ô Source + Translation.
- Slogan giữ nguyên "Translate anywhere, Peek instantly!" — chỉ hoa T và P (Manh cố ý), không đổi thành Title Case.

## 3. Hành vi (behaviour)

- **Auto-fit mỗi lần panel hiện:** đo nội dung rồi vừa khung; text dài cuộn trong ô output (cap 260), panel không tự dãn. **Thử lại 1 lần** khi thiếu số đo.
- **Snap-back NGANG (+8):** kéo rộng thừa cho text ngắn → thả ra co về rộng mặc định 420; text dài thì giữ nguyên rộng đã kéo.
- **Snap-back DỌC (+8):** kéo cao thừa → thả ra co về chiều cao nội dung.
- **Kéo tay chỉ to ra thêm trong phiên đó.** Settings chỉ đặt giá trị mặc định; **mỗi lần mở panel về đúng mặc định (420×450)**. Cỡ kéo tay KHÔNG lưu vào Settings.
- **Thu/mở provider card:** card thu thì chỉ còn header, panel thụt theo (auto-fit lại ngay cả sau khi đã kéo tay).
- **Kéo di chuyển:** bằng cả hàng top bar (`TopBarDragMarker`). **Kéo resize:** grip 3 vạch chéo 20×20 ở góc dưới-phải (đổi chuột + kéo 2 chiều) + tay nắm viền phải (chỉ đổi rộng, con trỏ `resizeLeftRight`) + tay nắm viền dưới (chỉ đổi cao, con trỏ `resizeUpDown`) — các tay nắm viền là dải trong suốt 6pt. Min/max được OS kẹp qua `windowWillResize` (tương đương `WM_GETMINMAXINFO` bên Windows), nên không bao giờ kéo được dưới min hay trên max.
- **Ẩn panel:** click chuột ra chỗ khác. **KHÔNG có nút đóng tay, và cũng KHÔNG CẦN** — workflow của Manh là tra xong click ra chỗ khác, rồi tra cái mới.
- **Mở panel:** mặc định ở kích thước Settings (420×450), không mở compact, không nhớ cỡ kéo cũ.

## 4. Text dài / text ngắn

- **Text ngắn:** card ở chiều cao tối thiểu, panel ở chiều cao mặc định/tối thiểu. Nút loa/Copy nằm gọn trong card, dưới text kết quả.
- **Text dài (từ ~6 line trở lên):** output cuộn trong ô (cap 260); panel không tự dãn thêm. Chỉ kéo tay mới dãn panel, lúc đó cap 260 được nâng theo để ô dãn cùng.
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

## 6. Loa/Copy ở trong ô output — GIỮ NGUYÊN (Manh chốt 17/11, cả 2 repo)

Mỗi provider có nút loa/Copy riêng ngay dưới text của chính nó
(`ProviderResultCard`). Đưa ra ngoài thành hàng cố định thì phải thêm logic
định tuyến nút về đúng provider (nút thuộc provider nào, provider đang load
thì sao) — phức tạp hơn mà không đáng. Giữ trong ô là đơn giản nhất và đúng
với Windows (loa/Copy cũng ở trong ô output). Nhược điểm đã biết: text dài
thì phải kéo xuống đáy mới thấy nút Copy — chấp nhận, vì đó là giá của việc
mỗi provider có nút riêng.

(Ngược lại, loa/Copy của **ô nhập** nằm ở hàng riêng **dưới** ô text — ngoài ô
cuộn — nên lúc nào cũng thấy, không cần kéo. Đó là mẫu "đưa ra ngoài" mà Manh
nhắc tới lúc đầu; chỉ áp được cho ô nhập vì ô nhập chỉ có 1, không có bài
toán nhiều provider.)

## 7. Nút "?" bảng shortcut + nút "Fast Read" (Manh 17/11, build #200 / nhánh `feature/fast-read-rsvp`)

- Nút `?` (`questionmark.circle`) đứng ngay bên trái nút Pin ở hàng Actions.
- Bấm mở 1 **popover** neo vào nút (bấm ra ngoài hoặc bấm lại "?" là đóng),
  liệt kê **10 shortcut** theo đúng thứ tự Settings → Keyboard Shortcuts:
  Smart Translation, Manual Translation, OCR Screen Translate, OCR to
  Clipboard, OCR to Clipboard - Translated, Translate Selection, Translate
  Clipboard, Screenshot Copy, Scan Barcodes/QR Codes, Fast Read (RSVP).
- Mỗi dòng có tên + phím tắt hiện tại (chưa gán thì "Not set") + nút **Run** —
  bấm là chạy thẳng hành động đó, khỏi bấm phím vật lý. Nút Run gọi đúng code
  path như bấm phím tắt (`AppDelegate.performShortcut`), nên click và phím
  không bao giờ lệch nhau.

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

**Hành vi giống nhau:** auto-fit mỗi lần hiện; Settings chỉ đặt mặc định, mở lại
về mặc định, kéo tay không lưu; thử lại auto-fit 1 lần; loa/Copy trong ô output;
hàng Actions Pin + Settings căn phải, Pin trước; click ra ngoài để ẩn, không nút
đóng tay; Enter = dịch lại, Shift+Enter = xuống dòng; thu/mở provider card;
cỡ chữ nội dung mặc định 14 (slider 12–24).

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
| Cỡ chữ top bar | Tên 17 Bold / slogan 15 / hint 13 | Tên 17 Bold / slogan 16 / hint 13 | Slogan mac nhỏ hơn 1pt (N−2 thay vì N−1) |
| Nút "?" | Có (#200), bên trái Pin | Đang làm (giao 17/11), vị trí tương tự | Cùng spec, mac làm trước |
| Loa/Copy ô nhập | Hàng riêng dưới ô text | Overlay trong ô (góc dưới-phải) | mac tách ra ngoài cho đỡ cuộn; Windows giữ overlay |

## Liên kết

- [Icon float UX](FLOAT_ICON_UX_SPEC.md)
- [Tổng quan UX](APP_UX_OVERVIEW.md)
- [Kiến trúc](../../ARCHITECTURE.md)
- [Việc đang làm / chờ](../../TASK_QUEUE.md)
- [Trạng thái dự án](../../PROJECT_STATE.md)
- [Chỉ mục UX](../../UI_DESIGN.md)
- [Panel UX Windows (đã chốt)](https://github.com/TranManhTuanLabs/TransPeek-Windows/blob/main/docs/UI/UX_DESIGN/FLOAT_POPUP_PANEL_UX.md)
