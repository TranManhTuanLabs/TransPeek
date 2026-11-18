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
/// The list is the same 10 shortcuts as Settings → Keyboard Shortcuts, in
/// the same tray order (Manh 2026-11-15; Fast Read added 2026-11-17). The key shown is the shortcut
/// currently assigned (default or the user's own); "Not set" means the
/// shortcut has no keys assigned yet — it can still be run from here.
///
/// This view is kept embeddable (no fixed width, no popover) so it can
/// also be the content of tab 1 (shortcuts) when the multi-tab frame
/// lands. The "?" button does NOT jump to tab 1 (Manh 2026-11-17 12:01):
/// shortcuts stay with "?" even after tab 1 becomes the
/// rest-eyes/focus/tomato timer.
///
/// Two header modes (Manh 2026-11-18, round 9): in panel left the card
/// is COLLAPSIBLE — the header shows a chevron and toggles collapse,
/// like the "How the icon works" card above it, so both cards can stay
/// collapsed and leave room for the future focus/tomato timer. In panel
/// center ("?" table) it is NOT collapsible — the header shows × and
/// hides the table, as before. The mode is chosen by the parent passing
/// (or not passing) `isCollapsed`. The Run buttons always call `onClose`
/// in both modes (panel center: hide the table; panel left: switch to
/// the translate tab to show the result).
struct ShortcutsTableView: View {
    /// Runs the named shortcut (AppDelegate.performShortcut — the same
    /// dispatch the physical hotkeys use). Nil in previews / when the
    /// panel is shown without an app behind it.
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?
    /// Hides the table (called by the close button and after a Run button).
    var onClose: (() -> Void)?
    /// Collapse state (panel left only, Manh 2026-11-18, round 9). When
    /// set, the header toggles collapse instead of closing; when nil
    /// (panel center "?" table) the header closes the table as before.
    var isCollapsed: Binding<Bool>?

    /// True when this instance is collapsible (panel left).
    private var isCollapsible: Bool { isCollapsed != nil }
    /// True when the card is currently collapsed (false when not
    /// collapsible — the "?" table is never collapsed).
    private var collapsed: Bool { isCollapsed?.wrappedValue ?? false }

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
        ("Fast Read (RSVP)", .fastRead),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — the WHOLE top bar of the card is the toggle
            // (Manh 2026-11-18): tapping anywhere on it — the title
            // text, the empty middle, or the padding at the edges —
            // acts on the card, like the provider card's header. The
            // padding lives INSIDE the button label (and
            // `.contentShape(Rectangle())` fills the gaps), so the
            // button's hit area is the full bar, edge to edge — not
            // just the title text. (Same pattern as FlowIntroCard,
            // whose whole top bar toggles collapse.)
            // What the tap does depends on the mode (Manh 2026-11-18,
            // round 9): panel left collapses the card (chevron), panel
            // center hides the table (×).
            Button {
                if let isCollapsed {
                    isCollapsed.wrappedValue.toggle()
                } else {
                    onClose?()
                }
            } label: {
                HStack(spacing: 6) {
                    // Keyboard icon at the left of the title (Manh
                    // 2026-11-18, round 8): the card looks bare without
                    // one, like the "How the icon works" card's cursor
                    // icon above it.
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    Spacer()
                    if isCollapsible {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, collapsed ? 10 : 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(collapsed ? "Show keyboard shortcuts" : (isCollapsible ? "Hide keyboard shortcuts" : "Close shortcuts — tap the title to close"))
            // InteractiveMarker: without it PopupPanel treats a click
            // here as a window drag, so the button never fires (Manh
            // 2026-11-17: the × and Run buttons in build #207 did
            // nothing). Every other clickable control in this panel
            // carries one — see PopupView / ProviderResultCard.
            .background { InteractiveMarker() }

            if !collapsed {
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
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
