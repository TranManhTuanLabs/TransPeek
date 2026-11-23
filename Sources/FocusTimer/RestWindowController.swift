import AppKit
import Combine
import Defaults
import SwiftUI

/// A separate window for a focus / rest-eyes reminder (Manh 2026-11-20,
/// focus timer + panel decor). It opens when a work or eye-rest interval
/// ends and the "Run reminder in:" setting is "New Fast Read Window".
///
/// It RSVP-reads the reminder text with the SAME engine and view model
/// as the Fast Read window, rendered by the panel's own lite view
/// (`CompactReadingView` in `PanelFastReadView.swift` — the window file
/// `RSVPView.swift` stays untouched, Manh 2026-11-20, 05:36), then shows
/// the rest countdown and closes itself when the countdown ends. It
/// never touches an open Fast Read window: this is its own window with
/// its own view model.
@MainActor
final class RestWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var viewModel: RSVPViewModel?
    /// The shared TTS coordinator (Manh 2026-11-23): set by AppDelegate
    /// via FocusTimerStore, so the Rest window's speaker button can read
    /// the reminder aloud — same shared speaker state as Full + Lite
    /// (one key, `transpeek_rsvpTTSEnabled`, remembered across reads).
    var ttsCoordinator: TTSCoordinator?
    /// Trackpad swipe monitor (Manh 2026-11-23): horizontal swipe steps
    /// a slide (like ←/→), vertical swipe changes the font size — the
    /// same as the Fast Read window, which the Rest window was missing.
    /// Created with the window, stopped when it closes.
    private var trackpadMonitor: RSVPTrackpadMonitor?
    private var trackpadCancellable: AnyCancellable?
    /// Keeps the trackpad monitor's Style 2 flag in sync with the view
    /// model's reading style (Manh 2026-11-21, same as the Fast Read
    /// window): the style can change while the window is open, so the
    /// monitor must follow it.
    private var styleCancellable: AnyCancellable?

    /// Open the Rest window with `text`. Any previous Rest window is
    /// closed first (a reminder replaces the previous one); the read
    /// starts playing at once — a reminder must read itself.
    func show(text: String, countdownSeconds: Int, title: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        close()

        let viewModel = RSVPViewModel(
            text: trimmed,
            wpm: Defaults[.rsvpWPM],
            chunkSize: Defaults[.rsvpChunkSize],
            fontSize: Double(Defaults[.rsvpFontSize]),
            contextSizeRatio: Defaults[.rsvpContextSizeRatio],
            colorScheme: Defaults[.rsvpColorScheme],
            contextDisplayStyle: Defaults[.rsvpContextDisplayStyle],
            autoPlay: true,
            // Reading style + line highlight (Manh 2026-11-21): the
            // reader's persisted picks. The speaker state comes from
            // the shared key (`transpeek_rsvpTTSEnabled`), so the Rest
            // window's speaker follows the same on/off as Full + Lite
            // (Manh 2026-11-23, shared + remembered).
            readingStyle: Defaults[.rsvpReadingStyle],
            highlightCurrentLine: Defaults[.rsvpHighlightCurrentLine]
        )
        self.viewModel = viewModel

        let contentView = RestWindowView(
            viewModel: viewModel,
            title: title,
            countdownSeconds: countdownSeconds,
            onToggleMaximize: { [weak self] in self?.window?.zoom(nil) }
        ) { [weak self] in
            self?.close()
        }
        // The speaker button reads the coordinator from the
        // environment (Manh 2026-11-23) — without this the Rest window
        // has no TTS and the button stays hidden, as before.
        .environment(\.ttsCoordinator, ttsCoordinator)
        let hostingView = NSHostingView(rootView: contentView)

        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 560
        let height: CGFloat = 400
        let frame = NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TransPeek — Rest"
        window.contentView = hostingView
        window.minSize = NSSize(width: 480, height: 320)
        window.setFrameAutosaveName("TransPeekRestWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window

        // Trackpad swipes over this window (Manh 2026-11-23): same as
        // the Fast Read window — vertical swipe changes the font size
        // by 16pt per swipe, clamped to 40...450. The Rest window had
        // no monitor at all, so a swipe did nothing here.
        // Rest window — horizontal swipe is OPEN (Manh 2026-11-23,
        // "có mở nhé"): the Rest window renders the Lite view
        // (`CompactReadingView`) but it has NO tabs, so a horizontal
        // swipe turning the page cannot clash with tab switching.
        // The PANEL Lite stays locked (there a horizontal swipe
        // switches tabs) — only this window opens it. The step actions
        // below turn the page, exactly like the Fast Read window.
        let monitor = RSVPTrackpadMonitor()
        self.trackpadMonitor = monitor
        trackpadCancellable = monitor.actionPublisher.sink { [weak self] action in
            guard let self, let viewModel = self.viewModel else { return }
            switch action {
            case .stepForward: viewModel.stepForward()
            case .stepBack: viewModel.stepBack()
            case .fontBigger: viewModel.fontSize = min(450, viewModel.fontSize + 16)
            case .fontSmaller: viewModel.fontSize = max(40, viewModel.fontSize - 16)
            }
        }
        // Style 2 slow page-flip swipe (Manh 2026-11-21, same as the
        // Fast Read window): the monitor only throttles the horizontal
        // swipe when the reader is in Style 2 — Style 1 keeps the fast
        // one-step-per-event. The style can change while the window is
        // open, so follow it.
        monitor.isStyle2 = viewModel.readingStyle == .style2
        styleCancellable = viewModel.$readingStyle.sink { [weak monitor] style in
            monitor?.isStyle2 = style == .style2
        }
        monitor.start(window: window)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewModel.play()
    }

    /// Close the window (and stop playback).
    func close() {
        viewModel?.pause()
        trackpadMonitor?.stop()
        window?.close()
        window = nil
        viewModel = nil
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        viewModel?.pause()
        trackpadMonitor?.stop()
    }
}

/// The Rest window's content: the reminder read (compact RSVP view),
/// then the rest countdown. When the read finishes, the reading view
/// is replaced by the countdown — big timer, what to do, and a Done
/// button to close early. At zero the window closes itself.
private struct RestWindowView: View {
    @ObservedObject var viewModel: RSVPViewModel
    let title: String
    let countdownSeconds: Int
    var onToggleMaximize: (() -> Void)?
    var onClose: (() -> Void)?

    /// Seconds left in the rest countdown (`nil` = still reading).
    @State private var countdown: Int?

    private var pageBackground: Color {
        viewModel.colorScheme == .dark ? .black : .white
    }
    private var readingForeground: Color {
        viewModel.colorScheme == .dark ? .white : .black
    }
    private var readingSecondary: Color {
        viewModel.colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }

    var body: some View {
        Group {
            if let remaining = countdown {
                // Rest countdown (Manh 2026-11-20): shown after the
                // reminder finishes reading; the window closes itself
                // when it ends.
                VStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(readingSecondary)
                    Text(title)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(readingForeground)
                    Text(FocusTimerStore.mmss(remaining))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(readingForeground)
                    Text("The window closes when the timer ends.")
                        .font(.callout)
                        .foregroundStyle(readingSecondary)
                    Button("Done") {
                        onClose?()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                    // Enter triggers Done (Manh 2026-11-23, lẻ gộp): the
                    // cafe countdown screen already accepted Enter only
                    // because its Done button happened to be focused — a
                    // default-action shortcut makes Enter work here
                    // regardless of focus, the same as the cafe screen.
                    .keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(pageBackground)
            } else {
                CompactReadingView(
                    viewModel: viewModel,
                    onToggleMaximize: onToggleMaximize
                )
            }
        }
        .preferredColorScheme(viewModel.colorScheme == .dark ? .dark : .light)
        // The compact reading view ignores Esc (so it never swallows
        // the popup panel's dismiss key); this window has no panel, so
        // Esc closes it — the ignored key press propagates up here.
        .onKeyPress(.escape) {
            onClose?()
            return .handled
        }
        .task(id: viewModel.isFinished) {
            guard viewModel.isFinished else {
                countdown = nil
                return
            }
            countdown = countdownSeconds
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let current = countdown else { break }
                if current <= 1 {
                    onClose?()
                    break
                }
                countdown = current - 1
            }
        }
    }
}
