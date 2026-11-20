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
/// 0.1.5). Native SwiftUI Popover + List + an explicit search TextField —
/// no custom dropdown, no NSComboBox (which only auto-completes, it does
/// not filter the list). The panel stays 420×450; the popover floats
/// separately (~300pt × ~380pt), the list scrolls inside, search sits on
/// top.
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
    @FocusState private var searchFieldFocused: Bool

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
        // Gray border so the picker reads as a BUTTON (Manh 2026-11-20,
        // 18:29 — chosen over bigger padding like Capture OCR: the plain
        // text looked like a label, not a control). Gray/secondary, NOT
        // blue — blue is Capture OCR's border color. Same corner radius
        // (6) as the hover tint, so the two line up. The stroke is
        // visual only (allowsHitTesting false) — the build-285 lesson:
        // a hit-testable overlay shape swallows clicks.
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            // An explicit TextField at the top of the popover — NOT
            // `.searchable`: `.searchable` puts its field in the
            // toolbar, and a popover window has no toolbar, so even
            // inside a NavigationStack (the CI258 fix) macOS shows no
            // search field at all (Manh testing v0.1.5 / CI264 — the
            // list worked but there was still no text input at the top).
            // A real TextField in the content always renders. It takes
            // focus when the popover opens, so the user can type right
            // away.
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search languages", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFieldFocused)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .padding([.horizontal, .top], 8)
                .padding(.bottom, 4)
                Divider()
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
                        Section {
                            ForEach(popular, id: \.code) { entry in
                                languageRow(entry)
                            }
                        } header: {
                            // Centered like the rows (Manh 2026-11-20):
                            // a left header over centered rows leaves the
                            // same lopsided gap the centering removes.
                            Text("Popular")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Section {
                            ForEach(others, id: \.code) { entry in
                                languageRow(entry)
                            }
                        } header: {
                            Text("All languages")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .frame(width: 300, height: 380)
            .background { WindowCaptureView(tracker: popoverTracker) }
            .onAppear { searchFieldFocused = true }
            .onDisappear {
                searchText = ""
            }
        }
    }

    /// One language row: native name + English name/code dimmed, checkmark
    /// on the selected one. Tapping picks the language and closes the popover.
    /// Content is CENTERED (Manh 2026-11-20): left-aligned rows left an
    /// empty gap on the right that looked odd in the 300pt popover.
    /// The checkmark rides in a trailing overlay so the text stays
    /// exactly centered whether or not it shows.
    private func languageRow(_ entry: (code: String, nativeName: String, englishName: String)) -> some View {
        Button {
            selection = entry.code
            isPresented = false
        } label: {
            VStack(alignment: .center, spacing: 0) {
                Text(entry.nativeName)
                    .multilineTextAlignment(.center)
                if !entry.englishName.isEmpty {
                    Text("\(entry.englishName) · \(entry.code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .overlay(alignment: .trailing) {
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

