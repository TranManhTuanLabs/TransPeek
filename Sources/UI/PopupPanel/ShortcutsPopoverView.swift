import KeyboardShortcuts
import SwiftUI

/// The "?" shortcuts table (Manh 2026-11-17): embedded at the top of the
/// popup's output box. It WAS a popover; a popover is a separate window,
/// so opening it took focus off the panel and the panel's click-outside
/// auto-hide closed the panel before the table could be clicked (Manh
/// 2026-11-17, build #204). Embedding the table as panel content ends
/// that fight — there is no separate window to lose focus to.
///
/// Each row lists a global shortcut with a Run button that triggers the
/// action directly — so the user can run an action by clicking instead of
/// pressing the physical keys. Run uses the same dispatch as the physical
/// hotkey, so a capture action (OCR, Screenshot) hides the panel to
/// capture and shows it again with the result, exactly like pressing the
/// keys. The table closes after Run (the action is chosen; the result
/// should be visible, not the table).
///
/// The table is a plain section, NOT a provider card (Manh 2026-11-17
/// 12:01): it does not translate anything, it just lists shortcuts.
/// The list is the same 9 shortcuts as Settings → Keyboard Shortcuts, in
/// the same tray order (Manh 2026-11-15). The key shown is the shortcut
/// currently assigned (default or the user's own); "Not set" means the
/// shortcut has no keys assigned yet — it can still be run from here.
///
/// This view is kept embeddable (no fixed width, no popover) so it can
/// also be the content of tab 1 (shortcuts) when the multi-tab frame
/// lands. The "?" button does NOT jump to tab 1 (Manh 2026-11-17 12:01):
/// shortcuts stay with "?" even after tab 1 becomes the
/// rest-eyes/focus/tomato timer.
struct ShortcutsTableView: View {
    /// Runs the named shortcut (AppDelegate.performShortcut — the same
    /// dispatch the physical hotkeys use). Nil in previews / when the
    /// panel is shown without an app behind it.
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?
    /// Hides the table (called by the close button and after a Run button).
    var onClose: (() -> Void)?

    /// Title + shortcut name, in tray order (Settings → Keyboard Shortcuts).
    private static let entries: [(title: String, name: KeyboardShortcuts.Name)] = [
        ("Smart Translation", .smartTranslation),
        ("Manual Translation", .inputTranslation),
        ("OCR Screen Translate", .ocrScreenshot),
        ("OCR to Clipboard", .silentOCR),
        ("OCR to Clipboard - Translated", .silentOCRTranslated),
        ("Translate Selection", .translateSelection),
        ("Translate Clipboard", .clipboardTranslation),
        ("Screenshot Copy", .screenshotCopy),
        ("Scan Barcodes/QR Codes", .scanBarcodes),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close shortcuts")
                // InteractiveMarker: without it PopupPanel treats a click
                // here as a window drag, so the button never fires (Manh
                // 2026-11-17: the × and Run buttons in build #207 did
                // nothing). Every other clickable control in this panel
                // carries one — see PopupView / ProviderResultCard.
                .background { InteractiveMarker() }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            ForEach(Self.entries, id: \.name) { entry in
                HStack(spacing: 8) {
                    Text(entry.title)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(KeyboardShortcuts.getShortcut(for: entry.name)?.description ?? "Not set")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)

                    Button("Run") {
                        onRunShortcut?(entry.name)
                        onClose?()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Run \(entry.title)")
                    // InteractiveMarker: without it PopupPanel treats a
                    // click here as a window drag, so Run never fires
                    // (Manh 2026-11-17, build #207). See the × button
                    // above and ProviderResultCard for the same pattern.
                    .background { InteractiveMarker() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            Text("Click Run to trigger an action without pressing keys.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
