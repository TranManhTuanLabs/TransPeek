import SwiftUI

/// Intro card for the translate panel (Manh 2026-11-18): a short, friendly
/// introduction to the floating icon's flow, above the "?" keyboard
/// shortcuts table. Tapping the header expands/collapses it; the state is
/// remembered (Defaults `flowIntroCollapsed`), so once the reader knows the
/// flow they can keep it collapsed and the shortcuts table is the main
/// thing on show.
///
/// Content (Manh 2026-11-18, phrased for clarity): the icon is more than
/// a translator — Hover translates, Click listens, Option+Click Fast Reads.
/// Click and Option+Click can be swapped in Settings, so the card says so.
struct FlowIntroCard: View {
    /// Whether the card is collapsed (header only). Owned by PopupView,
    /// persisted to Defaults.
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand/collapse.
            Button {
                isCollapsed.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow.click")
                        .foregroundStyle(.secondary)
                    Text("How the icon works")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Show how the icon works" : "Hide how the icon works")
            // InteractiveMarker: without it PopupPanel treats a click here
            // as a window drag, so the button never fires (Manh 2026-11-17,
            // build #207). Every other clickable control in this panel
            // carries one — see ShortcutsTableView / ProviderResultCard.
            .background { InteractiveMarker() }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, isCollapsed ? 10 : 6)

            if !isCollapsed {
                Text("Not just a translator — it improves your learning experience.")
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                flowRow(gesture: "Hover", action: "Translate the selected text")
                flowRow(gesture: "Click", action: "Listen — hear it read aloud")
                flowRow(gesture: "Option + Click", action: "Fast Read — read it faster")

                Text("Tip: swap Click and Option + Click in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func flowRow(gesture: String, action: String) -> some View {
        HStack(spacing: 6) {
            Text(gesture)
                .font(.callout)
                .bold()
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(action)
                .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
    }
}
