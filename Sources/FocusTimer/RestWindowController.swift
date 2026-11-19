import AppKit
import Defaults
import SwiftUI

/// A separate window for a focus / rest-eyes reminder (Manh 2026-11-20,
/// focus timer + panel decor). It opens when a work or eye-rest interval
/// ends and the "Run reminder in:" setting is "New Fast Read Window".
///
/// It RSVP-reads the reminder text with the SAME engine, view model and
/// view as the Fast Read window (`RSVPView` in `.panel` presentation —
/// no copied reading code), then shows the rest countdown and closes
/// itself when the countdown ends. It never touches an open Fast Read
/// window: this is its own window with its own view model.
@MainActor
final class RestWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var viewModel: RSVPViewModel?

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
            autoPlay: true
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

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewModel.play()
    }

    /// Close the window (and stop playback).
    func close() {
        viewModel?.pause()
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(pageBackground)
            } else {
                RSVPView(
                    viewModel: viewModel,
                    presentation: .panel,
                    onToggleMaximize: onToggleMaximize,
                    onClose: onClose
                )
            }
        }
        .preferredColorScheme(viewModel.colorScheme == .dark ? .dark : .light)
        // The panel presentation ignores Esc (so it never swallows the
        // popup panel's dismiss key); this window has no panel, so Esc
        // closes it — the ignored key press propagates up here.
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
