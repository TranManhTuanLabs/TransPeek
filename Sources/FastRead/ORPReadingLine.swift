import SwiftUI

/// One line of reading text with the ORP (Optimal Recognition Point)
/// pivot character highlighted, pinned at 35% of the width (Manh
/// 2026-11-18, SwiftRead-style): the text before the pivot is
/// right-aligned into the left part, the text after it left-aligned
/// into the right part, so the pivot never moves and the eye always
/// lands on the same spot.
///
/// Extracted from `RSVPView.orpLine` (Manh 2026-11-20, focus timer +
/// panel decor) so the in-panel reading view and the panel-right focus
/// demo render the exact same focus line as the Fast Read window —
/// one layout, no copy-paste. The window view keeps its orange pivot
/// (`Color.orange`); the panel-right demo passes yellow for its "a".
struct ORPLineView: View {
    /// Text before the pivot character.
    let before: String
    /// The pivot character itself (usually one character).
    let pivot: String
    /// Text after the pivot character.
    let after: String
    /// Font size of the whole line.
    let fontSize: Double
    /// Color of the non-pivot text.
    var foreground: Color = .primary
    /// Color of the pivot character.
    var pivotColor: Color = .orange

    var body: some View {
        GeometryReader { geo in
            let pivotX = geo.size.width * 0.35
            let font = Font.system(size: fontSize, weight: .medium)
            HStack(spacing: 0) {
                Text(before)
                    .font(font)
                    .foregroundStyle(foreground)
                    .frame(width: pivotX, alignment: .trailing)
                Text(pivot)
                    .font(font)
                    .foregroundStyle(pivotColor)
                Text(after)
                    .font(font)
                    .foregroundStyle(foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
