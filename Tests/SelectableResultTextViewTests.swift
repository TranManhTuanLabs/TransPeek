import AppKit
import Testing
@testable import TransPeek

@Suite @MainActor struct SelectableResultTextViewTests {
    private var baseFont: NSFont {
        .systemFont(ofSize: 14)
    }

    @Test func plainTextKeepsContentAndFont() {
        let attributed = SelectableResultTextView.attributedString(
            from: "Hello world",
            baseFont: baseFont
        )
        // Plain text has no Markdown syntax; the parser returns it unchanged.
        #expect(attributed?.string == "Hello world")
        let font = attributed?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 14)
    }

    @Test func boldMarkdownKeepsBoldTrait() {
        guard let attributed = SelectableResultTextView.attributedString(
            from: "Hello **world**",
            baseFont: baseFont
        ) else {
            Issue.record("Markdown parsing returned nil")
            return
        }
        #expect(attributed.string == "Hello world")
        let range = (attributed.string as NSString).range(of: "world")
        let font = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        let plainRange = (attributed.string as NSString).range(of: "Hello")
        let plainFont = attributed.attribute(.font, at: plainRange.location, effectiveRange: nil) as? NSFont
        #expect(plainFont?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }

    @Test func codeSpanKeepsMonospaceTrait() {
        guard let attributed = SelectableResultTextView.attributedString(
            from: "Run `git status` now",
            baseFont: baseFont
        ) else {
            Issue.record("Markdown parsing returned nil")
            return
        }
        #expect(attributed.string == "Run git status now")
        let range = (attributed.string as NSString).range(of: "git status")
        let font = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
    }
}
