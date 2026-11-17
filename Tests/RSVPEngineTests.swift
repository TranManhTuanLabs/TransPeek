import XCTest
@testable import TransPeek

/// Unit tests for the RSVP engine (SwiftRead legacy timing model).
final class RSVPEngineTests: XCTestCase {
    func testEmptyTextHasNoSlides() {
        let engine = RSVPEngine(text: "   \n  ")
        XCTAssertTrue(engine.words.isEmpty)
        XCTAssertTrue(engine.slides.isEmpty)
        XCTAssertEqual(engine.totalSeconds, 0, accuracy: 0.001)
    }

    func testTokenizesOnWhitespace() {
        let engine = RSVPEngine(text: "one  two\nthree\tfour")
        XCTAssertEqual(engine.words, ["one", "two", "three", "four"])
    }

    func testDefaultChunkIsOneWord() {
        let engine = RSVPEngine(text: "one two three")
        XCTAssertEqual(engine.slides.count, 3)
        XCTAssertEqual(engine.slides[0].words, ["one"])
        XCTAssertEqual(engine.slides[1].words, ["two"])
        XCTAssertEqual(engine.slides[2].words, ["three"])
    }

    func testChunkSizeGroupsWords() {
        let engine = RSVPEngine(text: "one two three four five", chunkSize: 2)
        XCTAssertEqual(engine.slides.count, 3)
        XCTAssertEqual(engine.slides[0].words, ["one", "two"])
        XCTAssertEqual(engine.slides[1].words, ["three", "four"])
        XCTAssertEqual(engine.slides[2].words, ["five"])
    }

    func testChunkSizeClampedToRange() {
        let engine = RSVPEngine(text: "one two three", chunkSize: 99)
        XCTAssertEqual(engine.chunkSize, RSVPEngine.chunkRange.upperBound)
        let small = RSVPEngine(text: "one two three", chunkSize: 0)
        XCTAssertEqual(small.chunkSize, RSVPEngine.chunkRange.lowerBound)
    }

    func testBaseDelayIsSixtyThousandOverWPM() {
        // 1 plain word at 275 WPM: 60000/275 = 218.18ms, minus 30ms overhead.
        let engine = RSVPEngine(text: "hello", wpm: 275)
        XCTAssertEqual(engine.slides[0].delayMs, 60000.0 / 275.0 - 30.0, accuracy: 0.01)
    }

    func testSentenceEndAddsMicroPause() {
        // "Hello." at 275 WPM: multiplier 1 + 1.1 = 2.1.
        let engine = RSVPEngine(text: "Hello.", wpm: 275)
        XCTAssertEqual(engine.slides[0].delayMs, (60000.0 / 275.0) * 2.1 - 30.0, accuracy: 0.01)
    }

    func testCommaAddsMicroPause() {
        // "Hello," at 275 WPM: multiplier 1 + 0.9 = 1.9.
        let engine = RSVPEngine(text: "Hello,", wpm: 275)
        XCTAssertEqual(engine.slides[0].delayMs, (60000.0 / 275.0) * 1.9 - 30.0, accuracy: 0.01)
    }

    func testNumberAddsMicroPause() {
        // "2026" contains a digit: multiplier 1 + 0.5 = 1.5.
        let engine = RSVPEngine(text: "2026", wpm: 275)
        XCTAssertEqual(engine.slides[0].delayMs, (60000.0 / 275.0) * 1.5 - 30.0, accuracy: 0.01)
    }

    func testLongWordAddsMicroPause() {
        // 9 chars > 8 × chunkSize (8) at chunkSize 1: multiplier 1 + 0.5.
        let engine = RSVPEngine(text: "antidisestablishmentarianism", wpm: 275)
        XCTAssertEqual(engine.slides[0].delayMs, (60000.0 / 275.0) * 1.5 - 30.0, accuracy: 0.01)
    }

    func testMicroPausesOffWhenChunkTimesWPMAtOrBelow100() {
        // chunk 1 × WPM 100 = 100 → pauses off: "Hello." gets the base delay.
        let engine = RSVPEngine(text: "Hello.", wpm: 100)
        XCTAssertEqual(engine.slides[0].delayMs, 60000.0 / 100.0 - 30.0, accuracy: 0.01)
    }

    func testPivotIsMiddleCharacter() {
        // "Hello" (5 chars) → pivot 2; "Hi" (2) → 1; "a" (1) → 0.
        let engine = RSVPEngine(text: "Hello Hi a")
        XCTAssertEqual(engine.slides[0].pivotCharIndex, 2)
        XCTAssertEqual(engine.slides[1].pivotCharIndex, 1)
        XCTAssertEqual(engine.slides[2].pivotCharIndex, 0)
    }

    func testPivotOffsetInJoinedText() {
        // Chunk ["hello", "world"]: pivot word is "world" (index 1),
        // pivot char 2 ("r"); offset = 5 ("hello") + 1 (space) + 2 = 8.
        let engine = RSVPEngine(text: "hello world", chunkSize: 2)
        XCTAssertEqual(engine.slides[0].joinedText, "hello world")
        XCTAssertEqual(engine.slides[0].pivotWordIndex, 1)
        XCTAssertEqual(engine.slides[0].pivotOffset, 8)
    }

    func testNewParagraphAddsMicroPause() {
        // Second paragraph's first word: multiplier 1 + 1.1 = 2.1.
        let engine = RSVPEngine(text: "First para.\n\nSecond para.", wpm: 275)
        // Slides: "First", "para.", "Second", "para."
        XCTAssertEqual(engine.slides.count, 4)
        XCTAssertEqual(
            engine.slides[2].delayMs,
            (60000.0 / 275.0) * 2.1 - 30.0,
            accuracy: 0.01
        )
    }

    func testEffectiveWPMIsWPMTimeChunkSize() {
        let engine = RSVPEngine(text: "one two", wpm: 275, chunkSize: 2)
        XCTAssertEqual(engine.effectiveWPM, 550)
    }

    func testContextIs150WordsEachSide() {
        let words = (1...400).map { "w\($0)" }.joined(separator: " ")
        let engine = RSVPEngine(text: words)
        // Slide 200 (word index 200): 150 before, 150 after.
        guard let context = engine.context(for: 200) else {
            XCTFail("expected context for slide 200")
            return
        }
        XCTAssertEqual(context.before.count, 150)
        XCTAssertEqual(context.current, ["w201"])
        XCTAssertEqual(context.after.count, 150)
        XCTAssertEqual(context.before.first, "w51")
        XCTAssertEqual(context.after.last, "w351")
    }

    func testContextClampsAtEdges() {
        let words = (1...10).map { "w\($0)" }.joined(separator: " ")
        let engine = RSVPEngine(text: words)
        guard let context = engine.context(for: 0) else {
            XCTFail("expected context for slide 0")
            return
        }
        XCTAssertTrue(context.before.isEmpty)
        XCTAssertEqual(context.current, ["w1"])
        XCTAssertEqual(context.after.count, 9)
    }

    func testTotalSecondsSumsSlideDelays() {
        let engine = RSVPEngine(text: "one two", wpm: 60000)
        // Each plain word at 60000 WPM: 1ms base, minus 30ms overhead,
        // floored at the 50ms minimum → 50ms each → 0.1s total.
        XCTAssertEqual(engine.totalSeconds, 0.1, accuracy: 0.001)
    }
}
