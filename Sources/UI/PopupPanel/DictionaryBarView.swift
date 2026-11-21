import AppKit
import Defaults
import SwiftUI

/// Bottom row of dictionary links in the float panel (SPEC §3.2).
///
/// One button per link from `DictionaryLink.load()`. Tapping opens the link
/// for the current lookup text in the default browser (new tab vs. window is
/// the browser's choice). The lookup text is the text the user selected
/// inside the panel when there is one, otherwise the source text that opened
/// the panel — see `PopupView.lookupText`. Favicons load asynchronously via
/// `FaviconService`; until one arrives the button shows the link's SF Symbol,
/// or the first letter of its name in a rounded tile.
///
/// Renders nothing for empty lookup text. The parent (`PopupView`) places this
/// at the bottom of the panel; links are reloaded whenever the panel opens so
/// Settings changes apply without relaunching.
struct DictionaryBarView: View {
    let lookupText: String

    @Default(.dictionaryDisplayMode) private var displayMode
    @Default(.popupFontSize) private var fontSize
    @StateObject private var faviconService = FaviconService.shared
    @State private var links: [DictionaryLink] = DictionaryLink.load()

    var body: some View {
        if lookupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            // Horizontal scroll so a long list scrolls instead of overflowing/clipping.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(links) { link in
                        dictionaryButton(for: link)
                    }
                }
                .padding(.horizontal, 4)
            }
            // Marks the bar's region for TrackpadSwipeMonitor (Manh
            // 2026-11-20, 10:13): the bar is a hard no-tab-switch zone —
            // a swipe beginning over it never switches tabs. The marker
            // is a background (behind the ScrollView), so it never
            // becomes a hit view and cannot affect clicks or dragging.
            .background { DictionaryBarMarker() }
            .onAppear { links = DictionaryLink.load() }
            .task(id: links) {
                for link in links {
                    _ = await faviconService.image(for: link)
                }
            }
        }
    }

    private func dictionaryButton(for link: DictionaryLink) -> some View {
        Button {
            guard let url = link.url(for: lookupText) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                linkIcon(for: link)
                if displayMode == .iconText {
                    Text(link.name)
                        .font(.system(size: CGFloat(fontSize)))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(link.name)
        .onHover { hovering in
            // Dictionary entries open a website, so they are links:
            // system pointing-hand cursor on hover (Manh 2026-11-20),
            // same as the GitHub links in the bottom bar.
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .background { InteractiveMarker() }
        // Hover highlight (Manh 2026-11-21): the whole button — icon +
        // text — lights up, like every other panel button. (Manh let
        // me choose text-only vs icon+text; the whole button is the
        // consistent choice — the tint wraps the button, and a text-only
        // tint would look off next to the icon.)
        .panelHoverHighlight()
    }

    @ViewBuilder
    private func linkIcon(for link: DictionaryLink) -> some View {
        if let favicon = faviconService.cachedImage(for: link) {
            Image(nsImage: favicon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else if let symbolName = link.iconSystemName, !symbolName.isEmpty {
            Image(systemName: symbolName)
                .font(.system(size: 14))
                .frame(width: 16, height: 16)
        } else {
            // First-letter tile (SPEC §3.2 fallback when no favicon is available).
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                Text(String(link.name.prefix(1)).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 16, height: 16)
        }
    }
}

/// NSView marker placed as `.background()` on the dictionary link bar's
/// ScrollView. `TrackpadSwipeMonitor` treats the bar as a hard
/// no-tab-switch zone (Manh 2026-11-20, 10:13): it finds this marker by
/// rect containment (same pattern as `InteractiveMarkerView` in
/// `PopupPanel.shouldStartWindowDrag`). A plain NSView — it draws
/// nothing and, as a background behind the ScrollView, never becomes a
/// hit view, so it cannot affect clicks or window dragging.
final class DictionaryBarMarkerView: NSView {}

struct DictionaryBarMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> DictionaryBarMarkerView { DictionaryBarMarkerView() }
    func updateNSView(_: DictionaryBarMarkerView, context: Context) {}
}
