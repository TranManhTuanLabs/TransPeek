import AppKit
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
    /// Reading speed in words per minute (default 500, range 50–2000,
    /// step 50 — Manh 2026-11-18, round 7).
    @Published var wpm: Int {
        didSet {
            Defaults[.rsvpWPM] = wpm
            rebuildEngine(keepingWordAt: currentWordIndex)
        }
    }
    /// Words shown per slide (1–6, default 1).
    @Published var chunkSize: Int {
        didSet { rebuildEngine(keepingWordAt: currentWordIndex) }
    }
    /// Font size of the focus word (40–450, default 80 — Manh
    /// 2026-11-18, round 7: was 40–110, default 64).
    @Published var fontSize: Double {
        didSet { Defaults[.rsvpFontSize] = Int(fontSize) }
    }
    /// Context (around) text size as a fraction of the focus font size
    /// (Manh 2026-11-18, round 7): the top bar's "Context size" picker
    /// sets this as a percent. Default 0.40 (smaller than the old fixed
    /// 0.50), range 0.25–1.00.
    @Published var contextSizeRatio: Double {
        didSet { Defaults[.rsvpContextSizeRatio] = contextSizeRatio }
    }
    /// Window color scheme (Black on White / White on Black), picked in
    /// the window's Settings button; persisted, so the reader picks it
    /// once (Manh 2026-11-17, spec §14.3).
    @Published var colorScheme: RSVPColorScheme {
        didSet { Defaults[.rsvpColorScheme] = colorScheme }
    }
    /// When the context around the focus word shows (Manh 2026-11-18,
    /// SwiftRead's `contextDisplayStyle`): Always / Only show when
    /// paused / Never. Picked in the window's Settings button;
    /// persisted, so the reader picks it once.
    @Published var contextDisplayStyle: RSVPContextDisplayStyle {
        didSet { Defaults[.rsvpContextDisplayStyle] = contextDisplayStyle }
    }
    /// Whether text starts reading automatically when it is sent in
    /// (Manh 2026-11-20): when ON (default), every time text arrives
    /// from the select-text icon the window starts reading at once —
    /// no Space press needed. Toggled in the window's Settings
    /// popover; persisted, so the reader picks it once.
    @Published var autoPlay: Bool {
        didSet { Defaults[.rsvpAutoPlay] = autoPlay }
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
        fontSize: Double = 80,
        contextSizeRatio: Double = 0.40,
        colorScheme: RSVPColorScheme = .light,
        contextDisplayStyle: RSVPContextDisplayStyle = .onPause,
        autoPlay: Bool = true
    ) {
        self.text = text
        self.wpm = wpm
        self.chunkSize = chunkSize
        self.fontSize = fontSize
        self.contextSizeRatio = contextSizeRatio
        self.colorScheme = colorScheme
        self.contextDisplayStyle = contextDisplayStyle
        self.autoPlay = autoPlay
        self.engine = RSVPEngine(text: text, wpm: wpm, chunkSize: chunkSize)
    }

    /// Reset the reading settings to their defaults (Manh 2026-11-18,
    /// round 7 — the Settings popover's "Reset to default" button):
    /// speed 500, focus font 80, context size 40%, context display
    /// "Only show when paused", auto-play ON (Manh 2026-11-20).
    /// Color scheme is a theme preference, so it is NOT reset here.
    func resetToDefaults() {
        wpm = RSVPEngine.defaultWPM
        fontSize = 80
        contextSizeRatio = 0.40
        contextDisplayStyle = .onPause
        autoPlay = true
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

    /// Words around the current slide (the book-page context). Shown
    /// when paused, and while playing when the context style is Always.
    var pauseContext: (before: [String], current: [String], after: [String])? {
        engine.context(for: currentSlideIndex)
    }

    /// Total reading time at the current settings, compact minutes
    /// ("0min", "1min", "2mins") — the short display label. The full
    /// "Estimated reading time" is the tooltip (Manh 2026-11-18: the
    /// long label wrapped and broke the top-bar layout, so the display
    /// is short and the long phrase is the hint).
    var totalTimeText: String {
        let minutes = Int(engine.totalSeconds) / 60
        return minutes <= 1 ? "\(minutes)min" : "\(minutes)mins"
    }

    /// Elapsed time of the finished read, in natural words ("2 seconds",
    /// "1 minute", "2 minutes, 30 seconds") — for the share text.
    private var elapsedNaturalText: String {
        guard let elapsed = elapsedSeconds else { return "" }
        let total = Int(elapsed)
        if total < 60 { return "\(total) seconds" }
        let minutes = total / 60
        let seconds = total % 60
        if seconds == 0 { return minutes == 1 ? "1 minute" : "\(minutes) minutes" }
        return "\(minutes) minutes, \(seconds) seconds"
    }

    /// "Congratulations! You just read X words in Y minutes, Z seconds!"
    /// — shown above the progress bar once a full read finishes
    /// (spec §14.5). "Congratulations!" (Manh 2026-11-18, picked over
    /// "Cool!" — warmer, fits sharing, and matches SwiftRead).
    var completionText: String? {
        guard isFinished, let elapsed = elapsedSeconds else { return nil }
        let total = Int(elapsed)
        return "Congratulations! You just read \(engine.words.count) words in \(total / 60) minutes, \(total % 60) seconds!"
    }

    /// Share text (option A, Manh 2026-11-18): the real stats of the
    /// finished read, so the share is personal. Built with the feedback
    /// batch (trackpad + SwiftRead paused view + share row).
    var shareText: String {
        guard isFinished, elapsedSeconds != nil else { return "" }
        return "I just read \(engine.words.count) words in \(elapsedNaturalText) with TransPeek Fast Read — read 2–3x faster and improve your learning experience!"
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

    /// Restart reading from the beginning (Manh 2026-11-19, round 10):
    /// jump to slide 0, reset the timer, and start playing — a new
    /// reading session, like pressing Play on the last slide. Wired to
    /// the Restart button left of Rewind in the control row.
    func restart() {
        guard slideCount > 0 else { return }
        pause()
        currentSlideIndex = 0
        accumulatedSeconds = 0
        isFinished = false
        play()
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

    /// App version + build, same source as the panel footer
    /// (PopupView) and About: CFBundleShortVersionString +
    /// CFBundleVersion (the CI run number). Shown in the top bar,
    /// top-right, left of Settings (Manh 2026-11-19).
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private var versionText: String {
        buildNumber == "1" ? "Version \(appVersion)" : "Version \(appVersion) (\(buildNumber))"
    }

    /// Speed (WPM) picker options (Manh 2026-11-18, round 7: 50–2000
    /// in steps of 50 — was 17 uneven values [100, 150, 200, 250, 275,
    /// ...]). Uniform steps are easier to remember, and 50 covers the
    /// slowest readers; the default is 500.
    private static let wpmOptions = Array(stride(from: 50, through: 2000, by: 50))
    /// Focus font-size picker options (Manh 2026-11-18, round 7:
    /// 40–450 — was 40–110). Steps grow past 110 so the menu stays
    /// short; includes the default 80.
    private static let fontSizeOptions = [
        40, 48, 56, 64, 72, 80, 88, 96, 104, 110,
        120, 140, 160, 200, 250, 300, 350, 400, 450,
    ]
    /// Context (around) text size options, as a percent of the focus
    /// font size (Manh 2026-11-18, round 7 — the top bar's "Context
    /// size" picker). Default 40% (smaller than the old fixed 50%),
    /// min 25% (SwiftRead-small), max 100% (same as the focus).
    private static let contextSizeOptions = [25, 30, 35, 40, 50, 60, 75, 100]
    /// The picker option nearest to a value. The keyboard ↑/↓ moves
    /// speed by 50 and the trackpad moves text size by 8pt, so the
    /// value is not always one of the options — the picker shows the
    /// nearest one instead of going blank.
    private static func nearestWPMOption(to wpm: Int) -> Int {
        wpmOptions.min(by: { abs($0 - wpm) < abs($1 - wpm) })
            ?? RSVPEngine.defaultWPM
    }
    private static func nearestFontOption(to size: Double) -> Int {
        fontSizeOptions.min(by: { abs(Double($0) - size) < abs(Double($1) - size) })
            ?? 80
    }
    private static func nearestContextOption(to ratio: Double) -> Int {
        let percent = Int((ratio * 100).rounded())
        return contextSizeOptions.min(by: { abs($0 - percent) < abs($1 - percent) }) ?? 40
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 6)

            // Focus mode (§14.1) + "Show context around focus word"
            // setting (Manh 2026-11-18, SwiftRead's contextDisplayStyle):
            // Always = book page even while playing; Only show when
            // paused = focus line while playing, book page when paused;
            // Never = focus line only, even when paused.
            switch viewModel.contextDisplayStyle {
            case .always:
                bookPage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .never:
                readingArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .onPause:
                if viewModel.isPlaying {
                    readingArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookPage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Completion line + share row, above the progress bar
            // (§14.5 + Manh 2026-11-18: the share icons show at the
            // same time as the completion message).
            if let completion = viewModel.completionText {
                Text(completion)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 4)
                shareRow
                    .padding(.bottom, 8)
            }

            // Progress bar (click to seek).
            progressRow
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            // Bottom controls (§14.4) + shortcut hints at the right end
            // of the same row (Manh 2026-11-18, temporary — the hints
            // used to sit on their own row at the bottom-right).
            controlRow
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 880, minHeight: 550)
        .background(pageBackground)
        // Match the control colors to the chosen theme (Manh 2026-11-18):
        // without this, the bordered buttons (Rewind / Fast-forward /
        // Settings / "?" / Maximize) and the pickers render with the
        // system's light-mode colors — dark icons on the black "White
        // on Black" page, invisible. Setting the color scheme makes
        // them render light-on-dark instead.
        .preferredColorScheme(viewModel.colorScheme == .dark ? .dark : .light)
        .focusable()
        .focused($isFocused)
        // Hide the blue focus ring (Manh 2026-11-18): the focusable root
        // view drew a blue border framing the whole window, most visible
        // at full width. The view stays focusable — Space / arrows / Esc
        // still work — just without the ring.
        .focusEffectDisabled()
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
                viewModel.wpm = min(RSVPEngine.maxWPM, viewModel.wpm + RSVPEngine.wpmStep)
                return .handled
            case .downArrow:
                viewModel.wpm = max(50, viewModel.wpm - RSVPEngine.wpmStep)
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

    /// Left: WPM picker + Focus size picker + Context size picker +
    /// word picker. Center: what RSVP stands for, TRULY centered on
    /// the window (Manh 2026-11-18 — it used to sit between two Spacers,
    /// so the wide left cluster pushed it right of center). Right:
    /// Settings (Color Scheme) + "?" (hotkeys). "Reading time" used to
    /// be here at the left — it moved to the bottom-left corner (Manh
    /// 2026-11-18). The subtitle is overlaid on the full width so its
    /// center is the window's center; the side clusters sit in an
    /// HStack underneath. At the default window size there is room for
    /// all three; at the 880pt minimum the subtitle may sit close to
    /// the pickers.
    /// Compact (Manh 2026-11-18 — the top bar was too tall): tight
    /// vertical padding and 1pt label-to-picker spacing.
    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Speed: \(viewModel.wpm) WPM")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Picker("", selection: Binding(
                        get: { Self.nearestWPMOption(to: viewModel.wpm) },
                        set: { viewModel.wpm = $0 }
                    )) {
                        ForEach(Self.wpmOptions, id: \.self) { w in
                            Text("\(w)").tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)
                }
                .help("↑ / ↓ changes speed by 50 WPM")

                VStack(alignment: .leading, spacing: 1) {
                    Text("Focus size: \(Int(viewModel.fontSize))")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Picker("", selection: Binding(
                        get: { Self.nearestFontOption(to: viewModel.fontSize) },
                        set: { viewModel.fontSize = Double($0) }
                    )) {
                        ForEach(Self.fontSizeOptions, id: \.self) { s in
                            Text("\(s)").tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 70)
                }

                // Context (around) text size, as a percent of the focus
                // size (Manh 2026-11-18, round 7 — "Context size", right
                // next to "Focus size" in the top bar, not buried in
                // Settings). Default 40%, min 25%, max 100%.
                VStack(alignment: .leading, spacing: 1) {
                    Text("Context size: \(Int((viewModel.contextSizeRatio * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(readingSecondary)
                    Picker("", selection: Binding(
                        get: { Self.nearestContextOption(to: viewModel.contextSizeRatio) },
                        set: { viewModel.contextSizeRatio = Double($0) / 100 }
                    )) {
                        ForEach(Self.contextSizeOptions, id: \.self) { p in
                            Text("\(p)%").tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 70)
                }
                .help("Context text size, as a percent of the focus size")

                VStack(alignment: .leading, spacing: 1) {
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

            HStack(spacing: 8) {
                // Version, top-right, left of Settings (Manh
                // 2026-11-19): same "Version X (build)" text as the
                // panel footer, so Manh can tell which build this
                // window is from without opening About.
                Text(versionText)
                    .font(.caption)
                    .foregroundStyle(readingSecondary)
                    .lineLimit(1)

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
        .overlay(alignment: .center) {
            // Subtitle (Manh 2026-11-19, round 10): bigger for beauty —
            // 15pt semibold instead of the 12pt caption, so it reads as
            // the window's title, not a footnote. Still fits at the 880pt
            // minimum (the text is ~200pt wide, centered between the
            // picker cluster and the right buttons). No "— RSVP" suffix
            // (Manh 2026-11-19): the suffix made it long and ugly; the
            // window title already says "TransPeek — Fast Read RSVP".
            Text("Rapid Serial Visual Presentation")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(readingSecondary)
                .lineLimit(1)
        }
    }

    /// Color Scheme picker (White on Black / Black on White) + when
    /// the context around the focus word shows (spec §14.3 + Manh
    /// 2026-11-18, SwiftRead's `contextDisplayStyle`) + auto-play
    /// (Manh 2026-11-20) + Reset to
    /// default (Manh 2026-11-18, round 7).
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
            Text("Show context around focus word")
                .font(.headline)
                .padding(.top, 4)
            Picker("Show context around focus word", selection: $viewModel.contextDisplayStyle) {
                ForEach(RSVPContextDisplayStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            // Auto-play (Manh 2026-11-20): when ON (default), text
            // starts reading as soon as it is sent in from the
            // select-text icon — no Space press needed. When OFF,
            // the window opens paused, as before.
            Toggle("Run text automatically", isOn: $viewModel.autoPlay)
                .padding(.top, 4)
                .help("When on, text starts reading as soon as it is sent in")
            // Reset the reading settings to their defaults (Manh
            // 2026-11-18, round 7): speed 500, focus font 80, context
            // size 40%, context display "Only show when paused",
            // auto-play ON. The
            // color scheme is a theme preference, so it is NOT reset.
            Button("Reset to default") {
                viewModel.resetToDefaults()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
            .help("Reset speed, focus size, context size, context display and auto-play to their defaults")
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
            hotkeyRow("↑ / ↓", "Speed ±50 WPM")
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

    /// One line of reading text with the ORP pivot character in orange,
    /// pinned at 35% of the width. The text before the pivot is
    /// right-aligned into the left part, the text after it left-aligned
    /// into the right part, so the pivot never moves. Shared by the
    /// playing view and the paused book page's focus line (same size,
    /// same position — SwiftRead-style, Manh 2026-11-18).
    private func orpLine(slide: RSVPEngine.Slide, fontSize: Double) -> some View {
        GeometryReader { geo in
            let pivotX = geo.size.width * 0.35
            let font = Font.system(size: fontSize, weight: .medium)
            let joined = slide.joinedText
            let pivotOffset = slide.pivotOffset
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

    /// The current chunk with the ORP pivot character in orange, pinned
    /// at 35% of the window width.
    private var readingArea: some View {
        Group {
            if let slide {
                orpLine(slide: slide, fontSize: viewModel.fontSize)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Book page (paused)

    /// The full ±150-word context as a book page, shown while paused,
    /// SwiftRead-style (Manh 2026-11-18, from the SwiftRead source):
    /// the focus line keeps its size and its own row, centered — the
    /// words before it show above, the words after it below. The
    /// context lines scale with the focus size (the top bar's "Context
    /// size" percent, default 40% — Manh 2026-11-18, round 7; was a
    /// fixed half), so they stay readable instead of staying tiny at
    /// body size when the focus grows (Manh 2026-11-18: size follows
    /// SwiftRead). Stepping ←/→ (or swiping trackpad ←/→) while paused
    /// moves the focus line to the new slide and the context re-renders
    /// around it.
    ///
    /// The block text is SELECTABLE (Manh 2026-11-18, round 7): the
    /// reader can select a word in the context to translate it on the
    /// spot (the float icon appears on the selection), instead of only
    /// reading it. The focus line itself is not selectable — it is a
    /// single chunk rendered with a custom ORP layout.
    ///
    /// The focus line is PINNED at the vertical center (Manh
    /// 2026-11-18 — SwiftRead never lets it drift): the before/after
    /// texts each fill one half of the reading area and are anchored
    /// to the focus line (before = bottom-aligned, after =
    /// top-aligned), with overflow clipped — NOT scrolled. So as the
    /// read progresses, only the number of visible context lines
    /// changes; the focus line never moves. (Before this fix the page
    /// was a ScrollView, so as the before-text grew the focus line
    /// drifted down off-center.)
    private var bookPage: some View {
        VStack(spacing: 0) {
            if let context = viewModel.pauseContext {
                let beforeText = context.before.joined(separator: " ")
                let afterText = context.after.joined(separator: " ")
                // Words before the current chunk: top half, anchored to
                // the bottom so the words nearest the focus line sit
                // just above it; earlier words clip off the top when
                // they don't fit (no scroll).
                Group {
                    if !beforeText.isEmpty {
                        Text(beforeText)
                            .font(.system(size: viewModel.fontSize * viewModel.contextSizeRatio))
                            .foregroundStyle(readingSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxHeight: .infinity)
                .clipped()
                // No scroll (Manh 2026-11-21): a selectable Text is
                // backed by a scrollable text view, so without this
                // the context text scrolls and defeats the clip above.
                .scrollDisabled(true)
                // The focus line: fixed height, always at the vertical
                // center (the two halves above/below share the rest).
                if let slide {
                    orpLine(slide: slide, fontSize: viewModel.fontSize)
                        .frame(height: viewModel.fontSize * 1.3)
                }
                // Words after the current chunk: bottom half, anchored
                // to the top so the words nearest the focus line sit
                // just below it; later words clip off the bottom when
                // they don't fit (no scroll).
                Group {
                    if !afterText.isEmpty {
                        Text(afterText)
                            .font(.system(size: viewModel.fontSize * viewModel.contextSizeRatio))
                            .foregroundStyle(readingSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxHeight: .infinity)
                .clipped()
                // No scroll (Manh 2026-11-21): same as the before-text
                // above — the selectable Text would otherwise scroll
                // here, right above the Play/Pause controls.
                .scrollDisabled(true)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Share

    /// One button per platform, shown with the completion line (Manh
    /// 2026-11-18). Now the shared ShareRowView
    /// (Sources/UI/ShareRowView.swift), with the reading color scheme
    /// so the adaptive icons follow White on Black / Black on White.
    /// Each opens its share URL in the browser (Mail opens the mail
    /// app). The link shared is the TransPeek repo; the text is
    /// option A (the real stats of the finished read).
    private var shareRow: some View {
        ShareRowView(
            text: viewModel.shareText,
            textColor: readingForeground,
            pageColor: pageBackground,
            secondaryColor: readingSecondary
        )
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

    /// Four buttons centered at the bottom, with "Reading time" at the
    /// left end and the shortcut hints at the right end of the same row
    /// (§14.4 + Manh 2026-11-18, temporary — the hints used to sit on
    /// their own row at the bottom-right, and "Reading time" used to
    /// sit in the top bar). The buttons stay truly centered (their own
    /// HStack, centered on the full width) and the two side texts
    /// overlay at the leading / trailing edges, so they don't push the
    /// buttons off-center. At the 880pt minimum width the side texts
    /// (~110pt left, ~360pt right) and the centered buttons (~200pt)
    /// just fit; at the default size there is room to spare.
    private var controlRow: some View {
        ZStack {
            HStack(spacing: 20) {
                // Restart (Manh 2026-11-19, round 10): read from the
                // beginning — jump to slide 0, reset the timer, and
                // start playing. First button in the row, left of
                // Rewind, like the Windows Window Read. The row is
                // still ~260pt wide, so it fits at the 880pt minimum
                // with the side texts.
                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help("Restart (read from the beginning)")

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
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // "Reading time" at the bottom-left (Manh 2026-11-18).
            Text("Reading time: \(viewModel.totalTimeText)")
                .font(.caption)
                .foregroundStyle(readingSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .help("Estimated reading time")
                .frame(maxWidth: .infinity, alignment: .leading)

            // Hint at the right end of the controls row (Manh 2026-11-18,
            // temporary): the keyboard shortcuts + the trackpad swipe for
            // font size. "Esc close" was here before — replaced by the
            // swipe hint (Manh 2026-11-18 20:04) because the swipe is
            // the gesture a reader wouldn't discover on their own; Esc
            // still closes the window, it just isn't listed here.
            Text("Space play/pause • ←/→ step • ↑/↓ speed • Swipe ↑/↓ font size")
                .font(.caption)
                .foregroundStyle(readingSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
