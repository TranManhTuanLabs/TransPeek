import AppKit
import SwiftUI

/// Read-only selectable rendering of a translation result.
///
/// SwiftUI `Text` (and Textual's `StructuredText`) can be made selectable
/// but offer no API to read back the selection, so results are shown in a
/// plain `NSTextView` instead — the same pattern as the source editor
/// (`SourceInputView`): the delegate reports the selected text, and
/// `PopupView` retargets the dictionary links to it (SPEC §3.2).
///
/// Plain results are shown as-is; Markdown results are parsed by
/// Foundation into an attributed string (bold/italic/code/links kept) with
/// the popup font applied. Results with inline images keep Textual's
/// `MarkdownResultView` (rich mode), where selection tracking is unavailable.
struct SelectableResultTextView: NSViewRepresentable {
    let text: String
    let font: NSFont
    /// Parse `text` as Markdown (falls back to plain text on parse failure).
    var isMarkdown: Bool = false
    var onSelectionChange: ((String?) -> Void)?
    var onContentHeightChange: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.importsGraphics = false
        textView.allowsUndo = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onContentHeightChange = onContentHeightChange
        applyText(to: textView, text: text, isMarkdown: isMarkdown, font: font)
        context.coordinator.lastText = text
        context.coordinator.lastIsMarkdown = isMarkdown
        context.coordinator.lastFont = font
        // updateNSView runs right after this with the laid-out width and
        // reports the real height; this first report only covers the case
        // where SwiftUI never calls update (e.g. static content).
        Task { @MainActor in
            context.coordinator.reportContentHeight()
        }
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelectionChange = onSelectionChange
        coordinator.onContentHeightChange = onContentHeightChange
        if coordinator.lastText != text || coordinator.lastIsMarkdown != isMarkdown {
            applyText(to: textView, text: text, isMarkdown: isMarkdown, font: font)
            coordinator.lastText = text
            coordinator.lastIsMarkdown = isMarkdown
            coordinator.lastFont = font
        } else if coordinator.lastFont != font {
            applyFont(to: textView, font: font)
            coordinator.lastFont = font
        }
        if let container = textView.textContainer, textView.bounds.width > 0 {
            container.containerSize = NSSize(
                width: textView.bounds.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        coordinator.reportContentHeight()
    }

    // MARK: - Content

    private func applyText(to textView: NSTextView, text: String, isMarkdown: Bool, font: NSFont) {
        let attributed: NSAttributedString
        if isMarkdown, let parsed = Self.attributedString(from: text, baseFont: font) {
            attributed = parsed
        } else {
            attributed = NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: NSColor.labelColor]
            )
        }
        textView.textStorage?.setAttributedString(attributed)
        textView.font = font
        // New content resets the selection (and the dictionary lookup) —
        // same rule as the source editor's `setExternalText`.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    /// Re-applies the display font to the current content (font size/name
    /// change), preserving the bold/italic/mono traits of Markdown content.
    private func applyFont(to textView: NSTextView, font: NSFont) {
        guard let storage = textView.textStorage, storage.length > 0 else {
            textView.font = font
            return
        }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let traits = (value as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            storage.addAttribute(.font, value: Self.font(base: font, traits: traits), range: range)
        }
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        storage.endEditing()
        textView.font = font
    }

    /// Parses Markdown into an attributed string with `baseFont` applied,
    /// preserving bold/italic/monospace traits. Returns nil when parsing
    /// fails or yields nothing, so the caller falls back to plain text.
    static func attributedString(from markdown: String, baseFont: NSFont) -> NSAttributedString? {
        let hardened = MarkdownSupport.hardenLineBreaks(markdown)
        // NB: the options type lives on the Swift value type
        // `AttributedString` (`MarkdownParsingOptions`) — there is no
        // `NSAttributedString.MarkdownOptions`, and using that name fails
        // to compile (run #50).
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? NSAttributedString(markdown: hardened, options: options, baseURL: nil),
              parsed.length > 0
        else { return nil }
        let mutable = NSMutableAttributedString(attributedString: parsed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        // The Markdown parser marks bold/italic/code with the
        // `.inlinePresentationIntent` attribute; the `.font` runs it
        // produces are a uniform default font, so reading font traits
        // alone finds no bold/monospace (run #51). Collect the styled
        // ranges first and apply afterwards — never mutate the string
        // while enumerating it.
        var styledRanges: [(range: NSRange, traits: NSFontDescriptor.SymbolicTraits)] = []
        mutable.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            var traits: NSFontDescriptor.SymbolicTraits = []
            if let intent = attrs[.inlinePresentationIntent] as? InlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                if intent.contains(.code) { traits.insert(.monoSpace) }
            }
            // Fall back to the parsed font's own traits, in case the
            // parser styled a run with a concrete font instead.
            if let font = attrs[.font] as? NSFont {
                traits.formUnion(font.fontDescriptor.symbolicTraits)
            }
            if !traits.isEmpty {
                styledRanges.append((range, traits))
            }
        }
        mutable.addAttribute(.font, value: baseFont, range: fullRange)
        for (range, traits) in styledRanges {
            mutable.addAttribute(.font, value: font(base: baseFont, traits: traits), range: range)
        }
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        return mutable
    }

    /// The base popup font with the given symbolic traits applied (bold /
    /// italic / monospace). The system font family has no monospace
    /// variant, so a monospace run gets an explicit monospace font
    /// (keeping the bold weight when present) instead of relying on
    /// `NSFontManager.convert`, which may return the base font unchanged.
    private static func font(base: NSFont, traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        if traits.contains(.monoSpace) {
            let weight: NSFont.Weight = traits.contains(.bold) ? .bold : .regular
            var result = NSFont.monospacedSystemFont(ofSize: base.pointSize, weight: weight)
            if traits.contains(.italic) {
                result = NSFontManager.shared.convert(result, toHaveTrait: .italicFontMask)
            }
            return result
        }
        var result = base
        if traits.contains(.bold) {
            result = NSFontManager.shared.convert(result, toHaveTrait: .boldFontMask)
        }
        if traits.contains(.italic) {
            result = NSFontManager.shared.convert(result, toHaveTrait: .italicFontMask)
        }
        return result
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var onSelectionChange: ((String?) -> Void)?
        var onContentHeightChange: ((CGFloat) -> Void)?
        var lastText: String?
        var lastIsMarkdown = false
        var lastFont: NSFont?
        private var lastReportedContentHeight: CGFloat?

        /// Reports the selected text (or `nil` for an empty selection) so the
        /// dictionary links can follow the in-panel selection (SPEC §3.2).
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            guard range.length > 0 else {
                onSelectionChange?(nil)
                return
            }
            let selected = (textView.string as NSString).substring(with: range)
            onSelectionChange?(selected.isEmpty ? nil : selected)
        }

        func reportContentHeight() {
            guard let textView,
                  let container = textView.textContainer,
                  let layoutManager = textView.layoutManager
            else { return }
            layoutManager.ensureLayout(for: container)
            let usedHeight = layoutManager.usedRect(for: container).height
            let height = ceil(max(textView.font?.lineHeight ?? 0, usedHeight))
            guard lastReportedContentHeight.map({ abs($0 - height) > 0.5 }) ?? true else { return }
            lastReportedContentHeight = height
            let onContentHeightChange = onContentHeightChange
            DispatchQueue.main.async {
                onContentHeightChange?(height)
            }
        }
    }
}
