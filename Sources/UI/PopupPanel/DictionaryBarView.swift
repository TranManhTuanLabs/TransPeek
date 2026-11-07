import AppKit
import Defaults
import SwiftUI

/// Bottom row of dictionary links in the float panel (SPEC §3.2).
///
/// One button per link from `DictionaryLink.load()`. Tapping opens the link
/// for the current source text in the default browser (new tab vs. window is
/// the browser's choice). Favicons load asynchronously via `FaviconService`;
/// until one arrives the button shows the link's SF Symbol, or the first
/// letter of its name in a rounded tile.
///
/// Renders nothing for empty source text. The parent (`PopupView`) places this
/// at the bottom of the panel; links are reloaded whenever the panel opens so
/// Settings changes apply without relaunching.
struct DictionaryBarView: View {
    let sourceText: String

    @Default(.dictionaryDisplayMode) private var displayMode
    @Default(.popupFontSize) private var fontSize
    @StateObject private var faviconService = FaviconService.shared
    @State private var links: [DictionaryLink] = DictionaryLink.load()

    var body: some View {
        if sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 12) {
                ForEach(links) { link in
                    dictionaryButton(for: link)
                }
            }
            .padding(.horizontal, 4)
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
            guard let url = link.url(for: sourceText) else { return }
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
        .background { InteractiveMarker() }
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
