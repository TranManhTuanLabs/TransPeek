import Defaults
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
    /// Window color scheme (Black on White / White on Black), picked in
    /// the window's Settings button; persisted, so the reader picks it
    /// once (Manh 2026-11-17, spec §14.3).
    @Published var colorScheme: RSVPColorScheme {
        didSet { Defaults[.rsvpColorScheme] = colorScheme }
    }
    /// Index of the slide currently on screen.
    @Published var currentSlideIndex: Int = 0
    /// True while slides advance automatically.
    @Published var isPlaying: Bool = false
    /// True once a full read finished (playback reached the last slide).
    @Published var isFinished: Bool = false
    /// Actual reading time of the finished read (playing time only,
    /// pauses excluded), in seconds.
    @Published var elapsedSeconds: TimeInterval?

    private(set) var engine: RSVPEngine
    private var playbackTask: Task<Void, Never>?
    /// When the current playing stretch started (for elapsed time).
    private var playStartDate: Date?
    /// Playing time accumulated over earlier stretches of this read.
    private var accumulatedSeconds: TimeInterval = 0

    init(
        text: String,
        wpm: Int = RSVPEngine.defaultWPM,
        chunkSize: Int = 1,
        fontSize: Double = 64,
        colorScheme: RSVPColorScheme = .light
    ) {
        self.text = text
        self.wpm = wpm
        self.chunkSize = chunkSize
        self.fontSize = fontSize
        self.colorScheme = colorScheme
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
        return engine.slides[currentSlideIndex]
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

    /// "Cool! You just read X words in Y minutes, Z seconds!" — shown
    /// above the progress bar once a full read finishes (spec §14.5).
    var completionText: String? {
        guard isFinished, let elapsed = elapsedSeconds else { return nil }
        let total = Int(elapsed)
        return "Cool! You just read \(engine.words.count) words in \(total / 60) minutes, \(total % 60) seconds!"
    }

    // MARK: - Playback

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard slideCount > 0 else { return }
        // Restart from the beginning when the last slide is on screen;
        // a restart is a new reading session, so the timer resets too.
        if currentSlideIndex >= slideCount - 1 {
            currentSlideIndex = 0
            accumulatedSeconds = 0
        }
        isFinished = false
        isPlaying = true
        playStartDate = Date()
        startPlaybackTask()
    }

    func pause() {
        // Bank the time played so far; the clock resumes on play().
        if let start = playStartDate {
            accumulatedSeconds += Date().timeIntervalSince(start)
            playStartDate = nil
        }
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    func stepForward() {
        pause()
        isFinished = false
        if currentSlideIndex < slideCount - 1 {
            currentSlideIndex += 1
        }
    }

    func stepBack() {
        pause()
        isFinished = false
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
        }
    }

    /// Jump to the slide at `fraction` of the text (progress bar seek).
    func seek(to fraction: Double) {
        let wasPlaying = isPlaying
        pause()
        isFinished = false
        let clamped = max(0, min(1, fraction))
        currentSlideIndex = Int((Double(slideCount - 1) * clamped).rounded())
        if wasPlaying { play() }
    }

    /// Move one slide forward/backward by sentence (Shift+←/→): the next /
    /// previous slide whose last word ends a sentence.
    func stepSentence(forward: Bool) {
        pause()
        isFinished = false
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
                    // Finished: stop the clock and show the completion line.
                    await MainActor.run {
                        self.elapsedSeconds = self.accumulatedSeconds
                            + (self.playStartDate.map { Date().timeIntervalSince($0) } ?? 0)
                        self.playStartDate = nil
                        self.isFinished = true
                        self.isPlaying = false
                    }
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

/// The RSVP reading window (spec §14, Manh 2026-11-17 — SwiftRead-style
/// home reading window): a top bar (estimated time + WPM/font sliders +
/// word picker on the left, "Rapid Serial Visual Presentation" centered,
/// Settings + "?" on the right), a focus-mode reading area (only the
/// focused line while playing, the full block text as a book page while
/// paused), the completion line above the progress bar, and four buttons
/// centered at the bottom. The ORP pivot character is highlighted orange
/// and always sits at the same horizontal position (35% of the window
/// width), so the eye never has to move.
struct RSVPView: View {
    @ObservedObject var viewModel: RSVPViewModel
    /// Called by the "Toggle maximize window" button (the controller
    /// zooms the NSWindow). Not fullscreen: the window already has the
    /// red/yellow/green traffic lights for that (Manh 2026-11-17).
    var onToggleMaximize: (() -> Void)?
    /// Called when the user closes the window (Esc / close button).
    var onClose: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var showingSettings = false
    @State private var showingHotkeys = false

    private var slide: RSVPEngine.Slide? { viewModel.currentSlide }

    /// Reading text / page colors for the chosen scheme (an explicit
    /// override, so the colors are fixed, not system-adaptive).
    private var readingForeground: Color {
        viewModel.colorScheme == .dark ? .white : .black
    }
    private var readingSecondary: Color {
        viewModel.colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    private var pageBackground: Color {
        viewModel.colorScheme == .dark ? .black : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Focus mode (§14.1): while playing, only the focused line;
            // while paused, the full block text as a book page, the line
            // being read big and prominent.
            if viewModel.isPlaying {
                readingArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                bookPage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Completion line, above the progress bar (§14.5).
            if let completion = viewModel.completionText {
                Text(completion)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            // Progress bar (click to seek).
            progressRow
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            // Bottom-center controls (§14.4).
            controlRow
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 880, minHeight: 550)
        .background(pageBackground)
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress { press in
            switch press.key {
            case .space:
                viewModel.togglePlayPause()
                return .handled
            case .leftArrow:
                if press.modifiers.contains(.shift) {
                    viewModel.stepSentence(forward: false)
                } else {
                    viewModel.stepBack()
                }
                return .handled
            case .rightArrow:
                if press.modifiers.contains(.shift) {
                    viewModel.stepSentence(forward: true)
                } else {
                    viewModel.stepForward()
                }
                return .handled
            case .upArrow:
                viewModel.wpm = min(RSVPEngine.maxWPM, viewModel.wpm + 10)
                return .handled
            case .downArrow:
                viewModel.wpm = max(50, viewModel.wpm - 10)
                return .handled
            case .escape:
                onClose?()
                return .handled
            default:
                return .ignored
            }
        }
    }

    // MARK: - Top bar

    /// Left: estimated reading time + WPM slider + font slider + word
    /// picker. Center: what RSVP stands for. Right: Settings (Color
    /// Scheme) + "?" (hotkeys).
    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Estimated reading time: \(viewModel.totalTimeText)")
                    .font(.caption)
                    .foregroundStyle(readingSecondary)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed: \(viewModel.wpm) WPM")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.wpm) },
                            set: { viewModel.wpm = Int($0) }
                        ),
                        in: 100...Double(RSVPEngine.maxWPM),
                        step: 25
                    )
                    .frame(width: 120)
                }
                .help("↑ / ↓ changes speed by 10 WPM")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Text size: \(Int(viewModel.fontSize))")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Slider(value: $viewModel.fontSize, in: 40...110, step: 2)
                        .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Words at once")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Picker("", selection: $viewModel.chunkSize) {
                        ForEach(RSVPEngine.chunkRange, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 60)
                }
            }

            Spacer()

            Text("Rapid Serial Visual Presentation")
                .font(.caption)
                .foregroundStyle(readingSecondary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 8) {
                Button { showingSettings.toggle() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Settings")
                .popover(isPresented: $showingSettings) {
                    settingsPopover
                }

                Button { showingHotkeys.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .help("Hotkeys")
                .popover(isPresented: $showingHotkeys) {
                    hotkeysPopover
                }
            }
        }
    }

    /// Color Scheme picker (White on Black / Black on White); other
    /// customizations come later (spec §14.3).
    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Scheme")
                .font(.headline)
            Picker("Color Scheme", selection: $viewModel.colorScheme) {
                ForEach(RSVPColorScheme.allCases, id: \.self) { scheme in
                    Text(scheme.displayName).tag(scheme)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("More customizations coming later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 260)
    }

    /// Hotkey list (same keys as the keyboard shortcuts).
    private var hotkeysPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hotkeys")
                .font(.headline)
            hotkeyRow("Space", "Play / Pause")
            hotkeyRow("← / →", "Step one word")
            hotkeyRow("Shift + ← / →", "Step one sentence")
            hotkeyRow("↑ / ↓", "Speed ±10 WPM")
            hotkeyRow("Esc", "Close window")
        }
        .padding(12)
        .frame(width: 240)
    }

    private func hotkeyRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(key)
                .font(.callout)
                .bold()
            Spacer()
            Text(action)
                .font(.callout)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(readingForeground)
                    .frame(width: pivotX, alignment: .trailing)
                Text(pivotChar)
                    .font(font)
                    .foregroundStyle(.orange)
                Text(after)
                    .font(font)
                    .foregroundStyle(readingForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Book page (paused)

    /// The full ±150-word context as a book page, shown while paused:
    /// the surrounding words at body size, the line being read big and
    /// prominent so the eye finds it at once.
    private var bookPage: some View {
        ScrollView {
            Group {
                if let context = viewModel.pauseContext {
                    let beforeText = context.before.joined(separator: " ")
                    let currentText = context.current.joined(separator: " ")
                    let afterText = context.after.joined(separator: " ")
                    let currentFont = Font.system(
                        size: max(28, viewModel.fontSize * 0.5),
                        weight: .bold
                    )
                    Text("\(beforeText) ")
                        .font(.body)
                        .foregroundStyle(readingSecondary)
                    + Text(currentText)
                        .font(currentFont)
                        .foregroundStyle(readingForeground)
                    + Text(" \(afterText)")
                        .font(.body)
                        .foregroundStyle(readingSecondary)
                } else {
                    Text("")
                        .font(.body)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
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
        }
    }

    // MARK: - Controls

    /// Four buttons centered at the bottom: Rewind, Play/Pause,
    /// Fast-forward, Toggle maximize window (§14.4).
    private var controlRow: some View {
        HStack(spacing: 20) {
            Spacer()

            Button {
                viewModel.stepBack()
            } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.bordered)
            .help("Rewind (←)")

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
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.bordered)
            .help("Fast-forward (→)")

            Button {
                onToggleMaximize?()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
            .help("Toggle maximize window")

            Spacer()
        }
    }
}
