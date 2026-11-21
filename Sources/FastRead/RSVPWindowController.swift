import AppKit
import Combine
import Defaults
import SwiftUI

/// A separate window for Fast Read (RSVP) — the reading view is a window
/// of its own, not a tab of the translate panel (Manh 2026-11-17; the
/// panel is ~400px wide, far too narrow for 50–110px reading text, and a
/// tab risks an accidental swipe out of the reading view mid-read).
///
/// Default size is ~70% of the screen width × ~55% of the screen height
/// (min 880×550, per the RSVP research); the frame autosave name makes
/// macOS remember the size/position after a resize.
///
/// The controller is the window's delegate (weak reference, no cycle) so
/// closing the window with the red button also stops playback.
@MainActor
final class RSVPWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var viewModel: RSVPViewModel?
    /// Trackpad swipe monitor (Manh 2026-11-18): horizontal swipe
    /// steps one slide (like ←/→), vertical swipe changes the font
    /// size. Created with the window, stopped when it closes.
    private var trackpadMonitor: RSVPTrackpadMonitor?
    private var trackpadCancellable: AnyCancellable?
    /// The shared TTS coordinator (Manh 2026-11-21): set by AppDelegate
    /// so the Window Read speaker button can read the text aloud. The
    /// window reads it from the environment, so it is injected when the
    /// content is created.
    var ttsCoordinator: TTSCoordinator?

    /// Open the reading window with `text`. If the window is already open,
    /// replace its text (and restart from the first slide).
    func show(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let window, let viewModel {
            viewModel.pause()
            viewModel.text = trimmed
            viewModel.currentSlideIndex = 0
            // The read-along speaks through the coordinator (Manh
            // 2026-11-21, CI314 fix) — re-assert it here, so a reused
            // window always has it before play() runs.
            viewModel.ttsCoordinator = ttsCoordinator
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            trackpadMonitor?.start(window: window)
            // Auto-play (Manh 2026-11-20): when the setting is on
            // (default), text sent in starts reading at once — no
            // Space press needed.
            if viewModel.autoPlay {
                viewModel.play()
            }
            return
        }

        let viewModel = RSVPViewModel(
            text: trimmed,
            wpm: Defaults[.rsvpWPM],
            chunkSize: Defaults[.rsvpChunkSize],
            fontSize: Double(Defaults[.rsvpFontSize]),
            contextSizeRatio: Defaults[.rsvpContextSizeRatio],
            colorScheme: Defaults[.rsvpColorScheme],
            contextDisplayStyle: Defaults[.rsvpContextDisplayStyle],
            autoPlay: Defaults[.rsvpAutoPlay],
            // Reading style + line highlight (Manh 2026-11-21): the
            // reader's persisted picks, so a reopened window keeps the
            // style it was left in.
            readingStyle: Defaults[.rsvpReadingStyle],
            highlightCurrentLine: Defaults[.rsvpHighlightCurrentLine]
        )
        self.viewModel = viewModel
        // The read-along speaks through the coordinator (Manh 2026-11-21,
        // CI314 fix) — set it before play() runs, so auto-play starts in
        // the right mode at once (the view re-asserts it on appear too).
        viewModel.ttsCoordinator = ttsCoordinator

        let contentView = RSVPView(
            viewModel: viewModel,
            onToggleMaximize: { [weak self] in self?.window?.zoom(nil) }
        ) { [weak self] in
            self?.close()
        }
        // The speaker button reads the coordinator from the
        // environment (Manh 2026-11-21) — without this the Window
        // Read has no TTS and the button stays hidden.
        .environment(\.ttsCoordinator, ttsCoordinator)
        let hostingView = NSHostingView(rootView: contentView)

        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = max(880, screenFrame.width * 0.7)
        let height = max(550, screenFrame.height * 0.55)
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
        window.title = "TransPeek — Fast Read RSVP"
        window.contentView = hostingView
        window.minSize = NSSize(width: 880, height: 550)
        window.setFrameAutosaveName("TransPeekRSVPWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window

        // Trackpad swipes over this window: horizontal steps a slide
        // (like ←/→), vertical changes the font size by 8pt per swipe
        // (Manh 2026-11-18, round 7: 4x the old 2pt — the old step felt
        // too slow), clamped to 40...450.
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
        monitor.start(window: window)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Auto-play (Manh 2026-11-20): when the setting is on
        // (default), text sent in starts reading at once — no Space
        // press needed.
        if viewModel.autoPlay {
            viewModel.play()
        }
    }

    /// Close the window (and stop playback).
    func close() {
        viewModel?.pause()
        trackpadMonitor?.stop()
        window?.close()
        window = nil
        viewModel = nil
    }

    /// Called when the window closes (Manh 2026-11-20, 05:33) — set by
    /// AppDelegate so a pending break reminder can show once the read
    /// ends. Fires from `windowWillClose`, which runs for both the red
    /// button and a programmatic `close()`, exactly once each.
    var onClose: (() -> Void)?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - NSWindowDelegate

    /// The red close button: stop playback so the timer does not keep
    /// advancing slides in a closed window. The window itself is kept
    /// (isReleasedWhenClosed = false) so the next `show` reopens it.
    func windowWillClose(_ notification: Notification) {
        viewModel?.pause()
        trackpadMonitor?.stop()
        onClose?()
    }
}
