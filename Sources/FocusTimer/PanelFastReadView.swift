import AppKit
import Combine
import Defaults
import SwiftUI

/// Panel right (Fast Read tab) — in-panel reading + focus demo (Manh
/// 2026-11-20, focus timer + panel decor).
///
/// Two states:
/// - Idle: the "Fast Read Lite" placeholder, the focus demo
///   ("reading" — the "a" in yellow, half-bars above and below), a
///   "Read in panel" button for the text in the translate tab, and the
///   "Run FastRead in:" radio buttons (Manh 2026-11-20, 05:27;
///   radio since 07:02).
/// - Reading: `CompactReadingView` below — the panel's OWN lite reading
///   view (Manh 2026-11-20, 05:36: the Window Fast Read file
///   `RSVPView.swift` stays untouched). It shares ONLY the reading
///   logic (`RSVPEngine` + `RSVPViewModel`) with the window; the layout
///   (adaptive chrome, positions) lives here. The panel auto-pins when
///   a read starts in it, so an outside click never dismisses the panel
///   mid-read; the pin button itself lives in the shared dots row
///   (Manh 2026-11-20, 07:08), on all 3 tabs.
///   A reminder countdown banner shows after a reminder read finishes.
///   The Rest window uses the same `CompactReadingView`.
struct PanelFastReadView: View {
    @ObservedObject var store: FocusTimerStore
    /// Text available to read (the panel's current source text).
    var sourceText: String
    /// Called when a panel read starts (the host pins the panel).
    var onStartReading: (() -> Void)?
    /// Called by the Maximize button in the reading chrome (the host
    /// toggles the panel between its default and maximum size).
    var onToggleMaximize: (() -> Void)?

    @Environment(\.popupPanel) private var panel
    /// Vertical trackpad swipe → font size (Manh 2026-11-20, 04:44).
    /// Vertical only: a horizontal swipe still switches panels (the
    /// panel's own swipe monitor owns it).
    @StateObject private var swipeMonitor = PanelReadTrackpadMonitor()
    /// Where Fast Read runs (Manh 2026-11-20, 05:27): the "Run
    /// FastRead in:" radio buttons in the demo below. `@Default`
    /// re-renders the view when it changes.
    @Default(.fastReadRunLocation) private var runLocation

    var body: some View {
        Group {
            if let viewModel = store.panelReadingViewModel {
                readingState(viewModel: viewModel)
            } else {
                demoState
            }
        }
    }

    // MARK: - Reading

    private func readingState(viewModel: RSVPViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fast Read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            CompactReadingView(
                viewModel: viewModel,
                onToggleMaximize: onToggleMaximize,
                onCloseReading: { store.stopPanelReading() }
            )
            .onChange(of: viewModel.isFinished) { _, finished in
                if finished { store.startPanelReminderCountdown() }
            }

            // Rest countdown after a reminder read finishes (Manh
            // 2026-11-20): the panel returns to the demo at zero.
            if let remaining = store.panelReminderCountdown {
                HStack(spacing: 8) {
                    Text("Rest — \(FocusTimerStore.mmss(remaining))")
                        .font(.callout)
                        .monospacedDigit()
                    Spacer()
                    Button("Done") {
                        store.stopPanelReading()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("End the rest early")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: PopupResultLayoutPreferenceKey.self,
                        value: PopupResultLayout(viewportHeight: geometry.size.height)
                    )
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: PopupResultLayoutPreferenceKey.self,
                        value: PopupResultLayout(contentHeight: geometry.size.height)
                    )
            }
        }
        .onAppear {
            if let panel { swipeMonitor.start(panel: panel) }
        }
        .onDisappear {
            swipeMonitor.stop()
        }
        .onReceive(swipeMonitor.actionPublisher) { action in
            guard let viewModel = store.panelReadingViewModel else { return }
            switch action {
            case .fontBigger:
                viewModel.fontSize = min(450, viewModel.fontSize + 16)
            case .fontSmaller:
                viewModel.fontSize = max(40, viewModel.fontSize - 16)
            }
        }
    }

    // MARK: - Demo (idle)

    /// Placeholder + focus demo + "Read in panel" + "Run FastRead in:"
    /// picker (Manh 2026-11-20). The header is "Fast Read Lite" (Manh
    /// 2026-11-20, 11:35 — the in-panel reading works, so "coming soon"
    /// is no longer true; "Lite" names the in-panel version, distinct
    /// from the full Window Read). The subtitle no longer claims the
    /// window is unshipped (it shipped in 0.1.4): it points at the demo
    /// and the button below.
    private var demoState: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "book.pages")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Fast Read Lite")
                    .font(.headline)
                Text("Try the focus preview below, or read the current text in this panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                FocusDemoView()
                    .padding(.top, 12)

                Button {
                    store.startPanelReading(text: sourceText)
                    onStartReading?()
                } label: {
                    Label("Read in panel", systemImage: "book.pages")
                }
                .buttonStyle(.bordered)
                .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Read the text in the translate tab, right here in the panel")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                runLocationSection
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 24)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: PopupResultLayoutPreferenceKey.self,
                            value: PopupResultLayout(contentHeight: geometry.size.height)
                        )
                }
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: PopupResultLayoutPreferenceKey.self,
                        value: PopupResultLayout(viewportHeight: geometry.size.height)
                    )
            }
        }
    }

    // MARK: - Run location

    /// "Run FastRead in:" (Manh 2026-11-20, 05:27; radio buttons since
    /// 07:02) — where Fast Read runs, for EVERY launch (panel button,
    /// float icon, menubar, shortcut). "New Fast Read Window" opens the
    /// separate Window Read (default, the current behavior — marked
    /// "(Recommended)"); "Right Panel" reads here, in panel right, no
    /// separate window. Separate from the reminder's "Run reminder in:"
    /// — the two features must not share a setting. The "Read in panel"
    /// button above always reads here, whatever this says — it is the
    /// explicit panel action, not a launch.
    private var runLocationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Run FastRead in:")
                .font(.callout)
                .bold()
            Picker("", selection: $runLocation) {
                ForEach(FastReadRunLocation.allCases, id: \.self) { location in
                    Text(location.displayName + (location == .newWindow ? " (Recommended)" : "")).tag(location)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .background { InteractiveMarker() }
            Text("Applies to the Fast Read button, the float icon, and the keyboard shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compact reading view

/// The compact RSVP reading view for panel right and the Rest window
/// (Manh 2026-11-20, 05:36 — the Window Fast Read file `RSVPView.swift`
/// stays untouched, so the panel's lite layout lives here, in its own
/// file). Shares ONLY the reading logic with the window (`RSVPEngine` +
/// `RSVPViewModel` — chunking, timing, ORP, current slide, settings);
/// the layout is the panel's own: the focus font is NOT capped (Manh
/// 2026-11-20, 07:02 — the user swipes up/down freely and fits the
/// size to the frame), and the chrome adapts to the available size:
/// - While PLAYING: only the focus line (+ context when the style is
///   Always) and the shortcut hint — no buttons, no descriptions.
/// - While PAUSED at the panel's default size: the book page, then
///   compact chrome — the same four pickers as the top bar (Speed /
///   Focus size / Context size / Words at once) + Settings + "?" at
///   the top-right (Manh 2026-11-20, 07:54 — the small frame still
///   has room), a small progress bar above bottom-center X / Restart /
///   Rewind / Play / Forward / Maximize buttons.
/// - While PAUSED at (near-)maximum panel size (content width ≥ 540,
///   i.e. panel width ≈ 580+ of the 600 max): the full window chrome —
///   pickers top bar, progress, the 6-button control row (X first,
///   then Restart / Rewind / Play / Forward / Maximize) with Reading
///   time + hint, completion + share.
/// The focus line uses the shared `ORPLineView` (same layout as the
/// window's inline ORP line and the panel-right demo), so the three can
/// never drift apart. Every button/picker carries an `InteractiveMarker`
/// (panel clicks are window drags without it, Manh 2026-11-17, build
/// #207) — harmless in the Rest window, where the marker is just a
/// background view. Esc is ignored here (the host handles it: the
/// panel's dismiss monitor closes the reading first, then dismisses
/// the panel — two-stage Esc, Manh 2026-11-20, 07:02; the Rest window
/// closes itself). The X button does the same as the first Esc (it
/// calls `onCloseReading`, only set by the panel).
struct CompactReadingView: View {
    @ObservedObject var viewModel: RSVPViewModel
    /// Called by the Maximize button (the host toggles the panel size
    /// or zooms the Rest window).
    var onToggleMaximize: (() -> Void)?
    /// Called by the X button (Manh 2026-11-20, 07:02): closes the
    /// reading and returns to panel right. Only the panel sets it (the
    /// Rest window has no X button — it closes itself on Esc / Done).
    var onCloseReading: (() -> Void)? = nil

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
        GeometryReader { geo in
            let isFullSize = geo.size.width >= 540
            VStack(spacing: 0) {
                if viewModel.isPlaying {
                    readingAreaForCurrentState
                    panelHint
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                } else {
                    // Paused (Manh 2026-11-20, 09:16; hint row above
                    // the progress, Manh 2026-11-20, 09:41): top-to-
                    // bottom is [top bar: pickers + Settings + ?] →
                    // [reading area] → [hint row: shortcut keys] →
                    // [progressRow: "X / total" + bar] → [control
                    // row]. The picker top bar moved above the reading
                    // area; the progress stays BELOW it (Manh's "180"
                    // was the build number CI280, not the page number
                    // — moving the progress to the top was cancelled).
                    if isFullSize {
                        panelTopBar
                        readingAreaForCurrentState
                        if let completion = viewModel.completionText {
                            Text(completion)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                            shareRow
                                .padding(.bottom, 8)
                        }
                        panelHint
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        progressRow
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        controlRow
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    } else {
                        compactTopBar
                        readingAreaForCurrentState
                        panelHint
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        compactBottomChrome
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pageBackground)
            .preferredColorScheme(viewModel.colorScheme == .dark ? .dark : .light)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onAppear {
                isFocused = true
            }
            .onKeyPress(action: handleKeyPress)
        }
    }

    /// Focus line or book page for the current state (Manh 2026-11-18,
    /// SwiftRead's `contextDisplayStyle`): Always = book page even
    /// while playing; Only show when paused = focus line while playing,
    /// book page when paused; Never = focus line only, even when paused.
    @ViewBuilder
    private var readingAreaForCurrentState: some View {
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
    }

    /// Keyboard shortcut hint (Manh 2026-11-18): the keyboard shortcuts
    /// + the trackpad swipe for font size. Shown under the focus line
    /// while playing (the only control affordance while playing — the
    /// buttons stay hidden until pause) and, when paused, as its own
    /// row directly above the progress bar (Manh 2026-11-20, 09:41).
    private var panelHint: some View {
        Text("Space play/pause • ←/→ step • ↑/↓ speed • Swipe ↑/↓ font size")
            .font(.caption)
            .foregroundStyle(readingSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Compact top bar (Manh 2026-11-20, 04:44; pickers on the top
    /// row even at the small size, Manh 2026-11-20, 07:54 — the small
    /// frame still has room; moved ABOVE the reading area, Manh
    /// 2026-11-20, 09:16): the same four pickers as the top bar
    /// (Speed / Focus size / Context size / Words at once) +
    /// Settings + "?" at the top-right. The Settings popover is the
    /// same one as the window (color scheme, context display,
    /// auto-play, reset) — same options, compact. The row uses tight
    /// spacing (6pt) so the four pickers + gear + "?" fit the default
    /// 420pt panel width. The HStack is bottom-aligned (Manh
    /// 2026-11-20, 09:06) so the gear + "?" sit at the same height
    /// as the picker menus, not centered against the taller label +
    /// menu stacks.
    private var compactTopBar: some View {
        HStack(alignment: .bottom, spacing: 6) {
                wpmPicker
                focusSizePicker
                contextSizePicker
                chunkPicker

                Spacer()

                Button { showingSettings.toggle() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reading settings")
                .background { InteractiveMarker() }
                .panelHoverHighlight()
                .popover(isPresented: $showingSettings) {
                    settingsPopover
                }

                Button { showingHotkeys.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Hotkeys")
                .background { InteractiveMarker() }
                .panelHoverHighlight()
                .popover(isPresented: $showingHotkeys) {
                    hotkeysPopover
                }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// Compact bottom chrome: the small progress bar ("X / total" +
    /// bar) + bottom-center X / Restart / Rewind / Play / Forward /
    /// Maximize buttons, shown BELOW the reading area (split out of
    /// the old compactPausedChrome, Manh 2026-11-20, 09:16 — the top
    /// bar moved above the reading area; the progress stays below it).
    private var compactBottomChrome: some View {
        VStack(spacing: 6) {
            progressRow
                .padding(.horizontal, 12)

            HStack(spacing: 16) {
                // Close reading (Manh 2026-11-20, 07:02): X closes
                // the read and returns to panel right (same as the
                // first Esc). Only the panel shows it (the Rest window
                // has no X — it closes itself on Esc / Done).
                if let onCloseReading {
                    Button {
                        onCloseReading()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .help("Close reading (Esc)")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()
                }

                // Restart (Manh 2026-11-20, 07:02): shown even at the
                // small size — there is still enough room. Same as the
                // full-size control row: read from the beginning.
                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help("Restart (read from the beginning)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.stepBack()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.bordered)
                .help("Rewind (←)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .help("Play / Pause (Space)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.stepForward()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .help("Fast-forward (→)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    onToggleMaximize?()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .help("Toggle size")
                .background { InteractiveMarker() }
                .panelHoverHighlight()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 10)
        }
    }

    /// Top bar at (near-)maximum size (Manh 2026-11-20): the same four
    /// pickers as the window's top bar (Speed / Focus size / Context
    /// size / Words at once) + Settings + "?", but no version text (the
    /// panel footer already shows it) and no centered subtitle (the
    /// panel's own top bar already names the app) — the window's full
    /// top bar is ~100pt too wide for the 600pt panel. The HStack is
    /// bottom-aligned (Manh 2026-11-20, 09:06) so the gear + "?" sit
    /// at the same height as the picker menus, not centered against
    /// the taller label + menu stacks. Shown ABOVE the reading area
    /// (Manh 2026-11-20, 09:16); the progress bar stays BELOW the
    /// reading area, the control row stays at the bottom.
    private var panelTopBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            wpmPicker
            focusSizePicker
            contextSizePicker
            chunkPicker

            Spacer()

            Button { showingSettings.toggle() } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Settings")
            .background { InteractiveMarker() }
            .panelHoverHighlight()
            .popover(isPresented: $showingSettings) {
                settingsPopover
            }

            Button { showingHotkeys.toggle() } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .help("Hotkeys")
            .background { InteractiveMarker() }
            .panelHoverHighlight()
            .popover(isPresented: $showingHotkeys) {
                hotkeysPopover
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// Keyboard handling. Same keys as the window: Space play/pause,
    /// ←/→ step (Shift = sentence), ↑/↓ speed ±50. Esc is IGNORED —
    /// the host owns it: the panel's dismiss monitor closes the reading
    /// first (two-stage Esc, Manh 2026-11-20, 07:02) and only dismisses
    /// the panel on the next Esc; the Rest window closes itself. This
    /// view must not swallow the key.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
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
            return .ignored
        default:
            return .ignored
        }
    }

    // MARK: - Pickers (full-size top bar)

    /// Speed (WPM) picker options (Manh 2026-11-18, round 7: 50–2000
    /// in steps of 50). Uniform steps are easier to remember, and 50
    /// covers the slowest readers; the default is 500.
    private static let wpmOptions = Array(stride(from: 50, through: 2000, by: 50))
    /// Focus font-size picker options (Manh 2026-11-18, round 7:
    /// 40–450). Steps grow past 110 so the menu stays short; includes
    /// the default 80.
    private static let fontSizeOptions = [
        40, 48, 56, 64, 72, 80, 88, 96, 104, 110,
        120, 140, 160, 200, 250, 300, 350, 400, 450,
    ]
    /// Context (around) text size options, as a percent of the focus
    /// font size (Manh 2026-11-18, round 7). Default 40%, min 25%,
    /// max 100%.
    private static let contextSizeOptions = [25, 30, 35, 40, 50, 60, 75, 100]
    /// The picker option nearest to a value. The keyboard ↑/↓ moves
    /// speed by 50 and the trackpad moves text size by 16pt, so the
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

    private var wpmPicker: some View {
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
        .background { InteractiveMarker() }
    }

    private var focusSizePicker: some View {
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
        .background { InteractiveMarker() }
    }

    /// Context (around) text size, as a percent of the focus size
    /// (Manh 2026-11-18, round 7 — "Context size", right next to
    /// "Focus size" in the top bar, not buried in Settings). Default
    /// 40%, min 25%, max 100%.
    private var contextSizePicker: some View {
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
        .background { InteractiveMarker() }
    }

    private var chunkPicker: some View {
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
        .background { InteractiveMarker() }
    }

    // MARK: - Settings + hotkeys popovers

    /// Color Scheme picker (White on Black / Black on White) + when
    /// the context around the focus word shows + auto-play (Manh
    /// 2026-11-20) + Reset to default (Manh 2026-11-18, round 7).
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
            // auto-play ON. The color scheme is a theme preference, so
            // it is NOT reset.
            Button("Reset to default") {
                viewModel.resetToDefaults()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
            .help("Reset speed, focus size, context size, context display and auto-play to their defaults")
            .panelHoverHighlight()
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
            hotkeyRow("Esc", "Close")
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
    /// pinned at 35% of the width — the shared `ORPLineView`, the same
    /// layout as the window's focus line and the panel-right demo, so
    /// the three can never drift apart.
    private func orpLine(slide: RSVPEngine.Slide, fontSize: Double) -> some View {
        let joined = slide.joinedText
        let pivotOffset = slide.pivotOffset
        let before = String(joined.prefix(pivotOffset))
        let pivotChar = pivotOffset < joined.count
            ? String(joined[joined.index(joined.startIndex, offsetBy: pivotOffset)])
            : ""
        let after = pivotOffset + 1 < joined.count
            ? String(joined[joined.index(joined.startIndex, offsetBy: pivotOffset + 1)...])
            : ""
        return ORPLineView(
            before: before,
            pivot: pivotChar,
            after: after,
            fontSize: fontSize,
            foreground: readingForeground
        )
    }

    /// The current chunk with the ORP pivot character in orange, pinned
    /// at 35% of the panel width.
    private var readingArea: some View {
        Group {
            if let slide {
                orpLine(slide: slide, fontSize: viewModel.fontSize)
            } else {
                Color.clear
            }
        }
    }

    /// The full ±150-word context as a book page, shown while paused,
    /// SwiftRead-style (Manh 2026-11-18): the focus line keeps its size
    /// and its own row, centered — the words before it show above, the
    /// words after it below. The context lines scale with the focus
    /// size (the top bar's "Context size" percent, default 40%), so
    /// they stay readable instead of staying tiny at body size when
    /// the focus grows. Stepping ←/→ while paused moves the focus line
    /// to the new slide and the context re-renders around it.
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
    /// changes; the focus line never moves.
    ///
    /// Panel padding is 12pt (not the window's 32pt): the panel is
    /// narrow, and the chrome around it already pads 12pt.
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
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Share

    /// One button per platform, shown with the completion line (Manh
    /// 2026-11-18). The shared ShareRowView, with the reading color
    /// scheme so the adaptive icons follow White on Black / Black on
    /// White. The link shared is the TransPeek repo; the text is the
    /// real stats of the finished read.
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
            .background { InteractiveMarker() }
        }
    }

    // MARK: - Controls

    /// Five buttons centered at the bottom, with "Reading time" at the
    /// left end (Manh 2026-11-18). The buttons stay truly centered
    /// (their own HStack, centered on the full width) and the
    /// "Reading time" text overlays at the leading edge, so it doesn't
    /// push the buttons off-center. The shortcut hint used to sit at
    /// the right end of this row — it moved to its own row above the
    /// progress bar (Manh 2026-11-20, 09:41).
    private var controlRow: some View {
        ZStack {
            HStack(spacing: 20) {
                // Close reading (Manh 2026-11-20, 07:02): X first,
                // immediately left of Restart — same as the first Esc.
                // Only the panel shows it (the Rest window has no X).
                if let onCloseReading {
                    Button {
                        onCloseReading()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .help("Close reading (Esc)")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()
                }

                // Restart (Manh 2026-11-19, round 10): read from the
                // beginning — jump to slide 0, reset the timer, and
                // start playing. First button in the row, left of
                // Rewind.
                Button {
                    viewModel.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help("Restart (read from the beginning)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.stepBack()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.bordered)
                .help("Rewind (←)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .help("Play / Pause (Space)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    viewModel.stepForward()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .help("Fast-forward (→)")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                Button {
                    onToggleMaximize?()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .help("Toggle size")
                .background { InteractiveMarker() }
                .panelHoverHighlight()
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

        }
    }
}
/// Focus-font demo for panel right (Manh 2026-11-20): the word
/// "reading" rendered like the real thing — the letter "a" in yellow,
/// with half-bars above and below pointing into the middle of the "a"
/// (like Windows shows). Static decor, not a live read: it uses the
/// same `ORPLineView` as the Fast Read window, so the preview can
/// never drift from the real focus line.
private struct FocusDemoView: View {
    var body: some View {
        GeometryReader { geo in
            // The ORP pivot ("a") starts at 35% of the width; its
            // center sits ~11pt further right at the 40pt demo size,
            // so the bars center there, not at the pivot edge.
            let barCenterX = geo.size.width * 0.35 + 11
            VStack(spacing: 4) {
                demoBar(centerX: barCenterX)
                ORPLineView(before: "re", pivot: "a", after: "ding", fontSize: 40, pivotColor: .yellow)
                    .frame(height: 52)
                demoBar(centerX: barCenterX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 110)
    }

    private func demoBar(centerX: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: max(centerX - 12, 0))
            Rectangle()
                .fill(Color.secondary)
                .frame(width: 24, height: 2)
            Spacer()
        }
    }
}

/// Vertical trackpad swipe over the panel-right reading view (Manh
/// 2026-11-20, 04:44): fingers up = bigger text, fingers down =
/// smaller, 16pt per 50pt of movement (the same step as the Fast Read
/// window, Manh 2026-11-19, 0.1.5).
///
/// VERTICAL ONLY — a horizontal swipe must keep switching panels (the
/// panel's `TrackpadSwipeMonitor` owns it), so this monitor passes
/// horizontal-dominant gestures through untouched, whatever order the
/// two monitors run in. Same event rules as the window's
/// `RSVPTrackpadMonitor`: only gesture-phased trackpad events count,
/// momentum coasting never triggers.
final class PanelReadTrackpadMonitor: ObservableObject {
    enum Action {
        case fontBigger
        case fontSmaller
    }

    /// Emitted once per 50pt of vertical movement.
    let actionPublisher = PassthroughSubject<Action, Never>()

    /// Accumulated vertical delta for the current gesture (points).
    private var accumulatedY: CGFloat = 0
    /// The local monitor token (nil when not installed).
    private var monitor: Any?

    /// The panel the swipe must happen over (weak — the panel owns the
    /// view that owns this monitor). Events over any other window pass
    /// through.
    private weak var panel: NSPanel?

    /// Install the local monitor. Safe to call repeatedly (no-op if
    /// already installed).
    func start(panel: NSPanel) {
        self.panel = panel
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event: event) ?? event
        }
    }

    /// Remove the local monitor. Safe to call repeatedly.
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        panel = nil
        accumulatedY = 0
    }

    deinit {
        stop()
    }

    /// Handle one scroll-wheel event. Returns nil to consume it (a
    /// vertical swipe over the panel that we claimed), or the event
    /// itself to pass it through untouched.
    private func handle(event: NSEvent) -> NSEvent? {
        // Scope: only events over the visible popup panel.
        guard let panel, panel.isVisible, event.window == panel else { return event }
        // Only gesture-phased trackpad events count. A mouse wheel has
        // empty phase; momentum coasting has a momentumPhase — neither
        // ever triggers an action.
        guard event.phase != [] else { return event }
        guard event.momentumPhase == [] else { return event }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        switch event.phase {
        case .began:
            accumulatedY = 0
        case .changed:
            // Only a vertical-dominant swipe counts; a horizontal one
            // passes through so the panel tab switch still works.
            guard abs(deltaY) > abs(deltaX) * 1.5 else { return event }
            // Vertical: accumulate; every 50pt changes the font by
            // 16pt, and a long swipe keeps stepping (the remainder
            // carries over to the next event). Fingers up (negative
            // deltaY) = bigger; fingers down (positive deltaY) =
            // smaller. A vertical swipe only changes the text size —
            // it never scrolls anything.
            accumulatedY += deltaY
            if abs(accumulatedY) >= 50 {
                let bigger = accumulatedY < 0
                accumulatedY -= 50 * (bigger ? -1 : 1)
                actionPublisher.send(bigger ? .fontBigger : .fontSmaller)
            }
            return nil
        case .ended, .cancelled:
            accumulatedY = 0
        default:
            break
        }
        return event
    }
}
