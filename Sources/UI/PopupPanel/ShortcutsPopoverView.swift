import KeyboardShortcuts
import SwiftUI

/// The "?" shortcuts panel (Manh 2026-11-17): a popover listing every
/// global shortcut, each with a Run button that triggers the action
/// directly — so the user can run an action by clicking instead of
/// pressing the physical keys.
///
/// The list is the same 10 shortcuts as Settings → Keyboard Shortcuts, in
/// the same tray order (Manh 2026-11-15; Fast Read added 2026-11-17). The key shown is the shortcut
/// currently assigned (default or the user's own); "Not set" means the
/// shortcut has no keys assigned yet — it can still be run from here.
struct ShortcutsPopoverView: View {
    /// Runs the named shortcut (AppDelegate.performShortcut — the same
    /// dispatch the physical hotkeys use). Nil in previews / when the
    /// panel is shown without an app behind it.
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?

    @Environment(\.dismiss) private var dismiss

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
            Text("Keyboard Shortcuts")
                .font(.headline)
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
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Run \(entry.title)")
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
        .frame(width: 320)
    }
}
