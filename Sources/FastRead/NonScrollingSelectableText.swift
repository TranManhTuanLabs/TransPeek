import AppKit
import SwiftUI

/// Selectable text that can never scroll (Manh 2026-11-22).
///
/// Reason: a selectable SwiftUI `Text` is backed by an NSTextView inside
/// a scroll view. `.scrollDisabled(true)` did NOT stop it — as soon as
/// the user clicks into the text, the text view becomes the focused
/// editor and turns into a scroll box for the above/below text. Native
/// SwiftUI has no "selectable but never scrollable" text, so this wraps
/// an NSTextView directly, with NO scroll view around it (Manh was told
/// before building it).
///
/// Behaviour: the reader can click-drag to select a word (the
/// alternative icon appears on the selection, as before), but the text
/// never becomes a scroll box and never moves — the focus line stays
/// pinned at the center. Overflow is clipped, like the old `.clipped()`
/// book page.
///
/// Alignment: `.top` (after-text — words nearest the focus line sit just
/// below it, later words clip off the bottom) or `.bottom` (before-text —
/// words nearest the focus line sit just above it, earlier words clip
/// off the top). The text view is exactly as tall as the text and the
/// container clips it, so the alignment is just where the text view
/// sits in the container.
struct NonScrollingSelectableText: NSViewRepresentable {
    var text: String
    var font: NSFont
    var textColor: NSColor
    var verticalAlignment: VerticalAlignment

    enum VerticalAlignment {
        case top
        case bottom
    }

    func makeNSView(context: Context) -> NonScrollingTextContainerView {
        let container = NonScrollingTextContainerView()
        container.verticalAlignment = verticalAlignment
        container.setText(text, font: font, color: textColor)
        return container
    }

    func updateNSView(_ container: NonScrollingTextContainerView, context: Context) {
        container.verticalAlignment = verticalAlignment
        container.setText(text, font: font, color: textColor)
    }
}

/// The container: a plain NSView that holds one NSTextView and positions
/// it top- or bottom-aligned, clipping any overflow. The text view has
/// NO scroll view, so it can never scroll.
final class NonScrollingTextContainerView: NSView {
    var verticalAlignment: NonScrollingSelectableText.VerticalAlignment = .top

    private let textView = NSTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Selectable, not editable — the reader highlights a word to
        // translate it (the alternative icon appears on the selection).
        textView.isEditable = false
        textView.isSelectable = true
        // No background — the text sits on the reading page like a
        // SwiftUI Text.
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        // Never resize to fit content — the container decides the size.
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        // Clip the text view to this container (NSView doesn't clip
        // subviews by default).
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ string: String, font: NSFont, color: NSColor) {
        // Only touch the string/font/color when they changed, so an
        // in-progress selection is not reset by a re-render.
        if textView.string != string { textView.string = string }
        if textView.font != font { textView.font = font }
        if textView.textColor != color { textView.textColor = color }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        guard width > 0, bounds.height > 0,
              let container = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        // Lay all the text out at the container width (tall container
        // so nothing is cut off while measuring) and measure its height.
        container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let textHeight = layoutManager.usedRect(for: container).height
        // The text view is exactly as tall as the text; the container
        // clips it. Bottom-aligned → its bottom sits at the container
        // bottom (earlier words clip off the top); top-aligned → its
        // top sits at the container top (later words clip off the
        // bottom). (AppKit y = 0 is the bottom.)
        let y: CGFloat
        switch verticalAlignment {
        case .top:
            y = bounds.height - textHeight
        case .bottom:
            y = 0
        }
        textView.frame = NSRect(x: 0, y: y, width: width, height: textHeight)
    }
}
