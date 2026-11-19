import AppKit
import SwiftUI

/// Tracks the language picker's popover window so the dismiss monitor can
/// treat clicks in it as clicks inside the panel (Manh 2026-11-19, 0.1.5).
/// A SwiftUI `.popover` is a separate NSWindow, so without this the
/// `PopupDismissMonitor` would read a click on the popover as "click
/// outside" and hide the panel — killing the popover before anything can
/// be picked. The tracker holds a weak reference; it is nil when the
/// popover is closed.
final class LanguagePopoverTracker {
    weak var window: NSWindow?
}

/// Captures the window of the view it is placed in, into a tracker.
/// Placed inside the language popover content, so the tracker learns
/// which NSWindow is the popover (set when the view moves to the window,
/// cleared when it moves out).
private struct WindowCaptureView: NSViewRepresentable {
    let tracker: LanguagePopoverTracker

    func makeNSView(context: Context) -> NSView {
        WindowCaptureNSView(tracker: tracker)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowCaptureNSView: NSView {
    let tracker: LanguagePopoverTracker

    init(tracker: LanguagePopoverTracker) {
        self.tracker = tracker
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tracker.window = window
    }
}

/// A searchable language dropdown: a button showing the current language,
/// opening a floating popover with a searchable list (Manh 2026-11-19,
/// 0.1.5). Native SwiftUI Popover + List + `.searchable` — no custom
/// dropdown, no NSComboBox (which only auto-completes, it does not filter
/// the list). The panel stays 420×450; the popover floats separately
/// (~300pt × ~380pt), the list scrolls inside, search sits on top.
struct SearchableLanguagePicker: View {
    @Binding var selection: String
    /// Leading option shown at the very top (e.g. "Auto Detect" for the
    /// source picker). Nil for the target picker.
    var leadingOption: (code: String, label: String)? = nil
    /// Display name for the current selection (e.g. "Auto Detect (English)"
    /// for the source picker). Defaults to the native name.
    var displayName: (String) -> String = { SupportedLanguages.nativeName(for: $0) }
    /// The popover window tracker (so the dismiss monitor treats popover
    /// clicks as inside the panel).
    let popoverTracker: LanguagePopoverTracker

    @State private var isPresented = false
    @State private var searchText = ""

    private var popular: [(code: String, nativeName: String, englishName: String)] {
        SupportedLanguages.popularLanguages
    }

    private var others: [(code: String, nativeName: String, englishName: String)] {
        SupportedLanguages.otherLanguages
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Every language (popular + others + the leading option) matching the
    /// search text — by native name, English name, or code. Diacritic- and
    /// case-insensitive, so "tieng viet" finds "Tiếng Việt".
    private var searchResults: [(code: String, nativeName: String, englishName: String)] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let foldedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var all = popular + others
        if let leading = leadingOption {
            all.insert((code: leading.code, nativeName: leading.label, englishName: ""), at: 0)
        }
        return all.filter { entry in
            entry.nativeName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(foldedQuery)
                || entry.englishName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(foldedQuery)
                || entry.code.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(foldedQuery)
        }
    }

    var body: some View {
        Button(displayName(selection)) {
            isPresented.toggle()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                List {
                    if isSearching {
                        ForEach(searchResults, id: \.code) { entry in
                            languageRow(entry)
                        }
                    } else {
                        if let leading = leadingOption {
                            Section {
                                languageRow((code: leading.code, nativeName: leading.label, englishName: ""))
                            }
                        }
                        Section("Popular") {
                            ForEach(popular, id: \.code) { entry in
                                languageRow(entry)
                            }
                        }
                        Section("All languages") {
                            ForEach(others, id: \.code) { entry in
                                languageRow(entry)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search languages")
                .listStyle(.plain)
            }
            .frame(width: 300, height: 380)
            .background { WindowCaptureView(tracker: popoverTracker) }
            .onDisappear {
                searchText = ""
            }
        }
    }

    /// One language row: native name + English name/code dimmed, checkmark
    /// on the selected one. Tapping picks the language and closes the popover.
    private func languageRow(_ entry: (code: String, nativeName: String, englishName: String)) -> some View {
        Button {
            selection = entry.code
            isPresented = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.nativeName)
                    if !entry.englishName.isEmpty {
                        Text("\(entry.englishName) · \(entry.code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if entry.code == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
