import Foundation
import Testing
@testable import TransPeek

@MainActor
@Suite struct HoverTextDetectorTests {
    // A plain paragraph in a text element is accepted.
    @Test func acceptsPlainBlockText() {
        #expect(HoverBlockText.shouldAccept(text: "Hello world, this is a paragraph.", role: "AXStaticText"))
    }

    // Buttons and links never summon the icon, whatever their text says.
    @Test func rejectsInteractiveRoles() {
        #expect(!HoverBlockText.shouldAccept(text: "Click me to continue", role: "AXButton"))
        #expect(!HoverBlockText.shouldAccept(text: "Read more", role: "AXLink"))
        #expect(!HoverBlockText.shouldAccept(text: "Subscribe", role: "AXCheckBox"))
    }

    // Window chrome never summons the icon, whatever its title says.
    @Test func rejectsChromeRoles() {
        #expect(!HoverBlockText.shouldAccept(text: "Safari — Wikipedia", role: "AXWindow"))
        #expect(!HoverBlockText.shouldAccept(text: "TransPeek", role: "AXApplication"))
    }

    // Too short to be a block (stray 1–3 letter UI labels).
    @Test func rejectsTooShortText() {
        #expect(!HoverBlockText.shouldAccept(text: "Hi", role: "AXStaticText"))
        #expect(!HoverBlockText.shouldAccept(text: "OK", role: "AXStaticText"))
    }

    // Too long to be a block (a whole document handed back by a container).
    @Test func rejectsTooLongText() {
        #expect(!HoverBlockText.shouldAccept(text: String(repeating: "word ", count: 600), role: "AXStaticText"))
    }

    // Punctuation only is not a block.
    @Test func rejectsPunctuationOnly() {
        #expect(!HoverBlockText.shouldAccept(text: "....", role: "AXStaticText"))
        #expect(!HoverBlockText.shouldAccept(text: "---", role: "AXStaticText"))
    }

    // CJK text has no spaces between words — the minimum is a character
    // count, not a word count, so it is accepted.
    @Test func acceptsCJKTextWithoutSpaces() {
        #expect(HoverBlockText.shouldAccept(text: "你好世界这是一个段落", role: "AXStaticText"))
    }

    // Same block: same frame + same text start. Different text or a
    // moved frame is a different block.
    @Test func sameBlockDetectionMatchesFrameAndText() {
        let frame = CGRect(x: 10, y: 20, width: 300, height: 40)
        #expect(HoverBlockText.isSameBlock(text: "Hello world", frame: frame, otherText: "Hello world, more text", otherFrame: frame))
        #expect(!HoverBlockText.isSameBlock(text: "Hello world", frame: frame, otherText: "Different text here", otherFrame: frame))
        #expect(!HoverBlockText.isSameBlock(text: "Hello world", frame: frame, otherText: "Hello world", otherFrame: frame.offsetBy(dx: 0, dy: 50)))
    }
}
