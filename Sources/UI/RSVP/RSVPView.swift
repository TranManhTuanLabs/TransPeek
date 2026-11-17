import SwiftUI

/// View model driving the RSVP reading window. Owns the engine, the
/// current slide, and the playback task; the view only renders state.
@MainActor
final class RSVPViewModel: ObservableObject {
    /// Source text being read.
    @Published var text: String {
        didSet { rebuildEngine(keepingWordAt: currentWordIndex) }
    }
    /// Reading speed in words per minute (default 275, max 2000).
    @Published var wpm: Int {
        didSet { rebuildEngine(keepingWordAt: currentWordIndex) }
    }
    /// Words shown per slide (1–6, default 1).
    @Published var chunkSize: Int {
        didSet { rebuildEngine(keepingWordAt: currentWordIndex) }
    }
    /// Font size of the reading word (40–110, default 64).
    @Published var fontSize: Double
    /// Index of the slide currently on screen.
    @Published var currentSlideIndex: Int = 0
    /// True while slides advance automatically.
    @Published var isPlaying: Bool = false

    private(set) var engine: RSVPEngine
    private var playbackTask: Task<Void, Never>?

    init(text: String, wpm: Int = RSVPEngine.defaultWPM, chunkSize: Int = 1, fontSize: Double = 64) {
        self.text = text
        self.wpm = wpm
        self.chunkSize = chunkSize
        self.fontSize = fontSize
        self.engine = RSVPEngine(text: text, wpm: wpm, chunkSize: chunkSize)
    }

    var slideCount: Int { engine.slides.count }

    /// Word index (in the full text) of the current slide's first word.
    var currentWordIndex: Int {
        guard engine.slides.indices.contains(currentSlideIndex) else { return 0 }
        return engine.slides[currentSlideIndex].startWordIndex
    }

    var currentSlide: RSVPEngine.Slide? {
        guard engine.slides.indices.contains(currentSlideIndex) else { return nil }
    }

    /// Fraction read, for the progress bar.
    var progress: Double {
        guard slideCount > 1 else { return 0 }
        return Double(currentSlideIndex) / Double(slideCount - 1)
    }

    /// Words around the current slide, shown when paused.
    var pauseContext: (before: [String], current: [String], after: [String])? {
        engine.context(for: currentSlideIndex)
    }

    /// Total reading time at the current settings.
    var totalTimeText: String {
        let seconds = Int(engine.totalSeconds)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    // MARK: - Playback

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard slideCount > 0 else { return }
        // Restart from the beginning when the last slide is on screen.
        if currentSlideIndex >= slideCount - 1 {
            currentSlideIndex = 0
        }
        isPlaying = true
        startPlaybackTask()
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    func stepForward() {
        pause()
        if currentSlideIndex < slideCount - 1 {
            currentSlideIndex += 1
        }
    }

    func stepBack() {
        pause()
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
        }
    }

    /// Jump to the slide at `fraction` of the text (progress bar seek).
    func seek(to fraction: Double) {
        let wasPlaying = isPlaying
        pause()
        let clamped = max(0, min(1, fraction))
        currentSlideIndex = Int((Double(slideCount - 1) * clamped).rounded())
        if wasPlaying { play() }
    }

    /// Move one slide forward/backward by sentence (Shift+←/→): the next /
    /// previous slide whose last word ends a sentence.
    func stepSentence(forward: Bool) {
        pause()
        let step = forward ? 1 : -1
        var index = currentSlideIndex + step
        while engine.slides.indices.contains(index) {
            let slide = engine.slides[index]
            if let lastWord = slide.words.last,
               let last = lastWord.last, last == "." || last == "!" || last == "?" {
                currentSlideIndex = index
                return
            }
            index += step
        }
        // No sentence end found: go to the start/end.
        currentSlideIndex = forward ? slideCount - 1 : 0
    }

    private func startPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let isPlaying = await MainActor.run { self.isPlaying }
                guard isPlaying else { break }
                let (delayMs, isLast) = await MainActor.run { () -> (Double, Bool) in
                    guard self.engine.slides.indices.contains(self.currentSlideIndex) else {
                        return (0, true)
                    }
                    return (
                        self.engine.slides[self.currentSlideIndex].delayMs,
                        self.currentSlideIndex >= self.engine.slides.count - 1
                    )
                }
                if isLast {
                    await MainActor.run { self.isPlaying = false }
                    break
                }
                try? await Task.sleep(nanoseconds: UInt64(delayMs * 1_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    if self.currentSlideIndex < self.engine.slides.count - 1 {
                        self.currentSlideIndex += 1
                    } else {
                        self.isPlaying = false
                    }
                }
            }
        }
    }

    /// Rebuild the engine after a setting change, keeping the reading
    /// position at the same word (so a WPM/chunk change mid-read does not
    /// jump the reader back to the start).
    private func rebuildEngine(keepingWordAt wordIndex: Int) {
        let wasPlaying = isPlaying
        pause()
        engine = RSVPEngine(text: text, wpm: wpm, chunkSize: chunkSize)
        // Find the slide containing this word.
        currentSlideIndex = engine.slides.lastIndex(where: { $0.startWordIndex <= wordIndex }) ?? 0
        if wasPlaying { play() }
    }
}

// MARK: - View

/// The RSVP reading window: one big word (chunk) at a fixed focal point,
/// a progress bar, and a compact control row. The ORP pivot character is
/// highlighted orange and always sits at the same horizontal position
/// (35% of the window width), so the eye never has to move.
struct RSVPView: View {
    @ObservedObject var viewModel: RSVPViewModel
    /// Called when the user closes the window (Esc / close button).
    var onClose: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var slide: RSVPEngine.Slide? { viewModel.currentSlide }

    var body: some View {
        VStack(spacing: 0) {
            // Reading area: the current chunk, ORP-aligned.
            readingArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Context sentence, shown when paused (SwiftRead default:
            // context only on pause).
            if !viewModel.isPlaying, let context = viewModel.pauseContext {
                contextView(context)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }

            // Progress bar (click to seek) + time.
            progressRow
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            // Controls.
            controlRow
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 880, minHeight: 550)
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.stepBack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.stepForward()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.wpm = min(RSVPEngine.maxWPM, viewModel.wpm + 10)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.wpm = max(50, viewModel.wpm - 10)
            return .handled
        }
        .onKeyPress(.escape) {
            onClose?()
            return .handled
        }
    }

    // MARK: - Reading area

    /// The current chunk with the ORP pivot character in orange, pinned
    /// at 35% of the window width. The text before the pivot is
    /// right-aligned into the left part, the text after it left-aligned
    /// into the right part, so the pivot never moves.
    private var readingArea: some View {
        GeometryReader { geo in
            let pivotX = geo.size.width * 0.35
            let font = Font.system(size: viewModel.fontSize, weight: .medium)
            let joined = slide?.joinedText ?? ""
            let pivotOffset = slide?.pivotOffset ?? 0
            let before = String(joined.prefix(pivotOffset))
            let pivotChar = pivotOffset < joined.count
                ? String(joined[joined.index(joined.startIndex, offsetBy: pivotOffset)])
                : ""
            let after = pivotOffset + 1 < joined.count
                ? String(joined[joined.index(joined.startIndex, offsetBy: pivotOffset + 1)...])
                : ""
            HStack(spacing: 0) {
                Text(before)
                    .font(font)
                    .frame(width: pivotX, alignment: .trailing)
                Text(pivotChar)
                    .font(font)
                    .foregroundStyle(.orange)
                Text(after)
                    .font(font)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Context

    /// The sentence around the current slide, with the current chunk in
    /// bold — shown only while paused, so the reader can re-orient.
    private func contextView(_ context: (before: [String], current: [String], after: [String])) -> some View {
        // Show the last few words before + the current chunk + the next few
        // words after (a window of the ±150-word context, trimmed to a
        // readable sentence-length slice).
        let beforeText = context.before.suffix(12).joined(separator: " ")
        let currentText = context.current.joined(separator: " ")
        let afterText = context.after.prefix(12).joined(separator: " ")
        return Text("\(beforeText) ")
            .font(.body)
            .foregroundStyle(.secondary)
        + Text(currentText)
            .font(.body)
            .bold()
        + Text(" \(afterText)")
            .font(.body)
            .foregroundStyle(.secondary)
    }

    // MARK: - Progress

    private var progressRow: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slideCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: width * viewModel.progress, height: 6)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    viewModel.seek(to: location.x / width)
                }
            }
            .frame(height: 6)
            Text(viewModel.totalTimeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.stepBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .help("Previous word (←)")

            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .help("Play / Pause (Space)")

            Button {
                viewModel.stepForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .help("Next word (→)")

            Divider()
                .frame(height: 24)

            // WPM: slider + value (effective WPM = WPM × chunk size).
            VStack(alignment: .leading, spacing: 2) {
                Text("Speed: \(viewModel.wpm) WPM")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.wpm) },
                        set: { viewModel.wpm = Int($0) }
                    ),
                    in: 100...Double(RSVPEngine.maxWPM),
                    step: 25
                )
                .frame(width: 160)
            }
            .help("↑ / ↓ changes speed by 10 WPM")

            VStack(alignment: .leading, spacing: 2) {
                Text("Words at once: \(viewModel.chunkSize)")
                    .font(.caption)
                Stepper("", value: $viewModel.chunkSize, in: RSVPEngine.chunkRange)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Text size: \(Int(viewModel.fontSize))")
                    .font(.caption)
                Slider(value: $viewModel.fontSize, in: 40...110, step: 2)
                    .frame(width: 120)
            }

            Spacer()

            Text("Space play/pause · ←/→ step · ↑/↓ speed · Esc close")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
