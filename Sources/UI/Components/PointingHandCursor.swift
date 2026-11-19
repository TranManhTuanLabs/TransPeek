import AppKit
import SwiftUI

/// Shows the pointing-hand cursor while hovering (Manh 2026-11-19, 0.1.5).
/// SwiftUI `Link`/`Button` do not change the cursor on their own — the hand
/// is what tells the user "this is clickable". This is the macOS link
/// convention: links (and link-like rows) get the hand, standard push
/// buttons keep the arrow cursor.
///
/// Push/pop must stay balanced: the cursor is popped when the hover ends.
/// The views this is applied to are stable (they do not disappear while
/// hovered), so the balance holds.
private struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    /// Show the pointing-hand cursor while the pointer hovers this view.
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}
