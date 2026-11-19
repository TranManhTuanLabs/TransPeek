import AppKit
import Combine
import Defaults
import SwiftUI

/// Panel right (Fast Read tab) — in-panel reading + focus demo (Manh
/// 2026-11-20, focus timer + panel decor).
///
/// Two states, both reusing the Fast Read window's code (no second
/// reading implementation):
/// - Idle: the "Fast Read — coming soon" placeholder, the focus demo
///   ("reading" — the "a" in yellow, half-bars above and below), a
///   "Read in panel" button for the text in the translate tab, and the
///   "Run FastRead in:" picker (Manh 2026-11-20, 05:27).
/// - Reading: the same `RSVPView` as the Fast Read window, in `.panel`
///   presentation (adaptive chrome by panel size). The pin button sits
///   in the header row — the panel auto-pins when a read starts in it,
///   so an outside click never dismisses the panel mid-read, and the
///   button lets the user toggle it off (Manh 2026-11-20, 04:44).
///   A reminder countdown banner shows after a reminder read finishes.
struct PanelFastReadView: View {
    @ObservedObject var store: FocusTimerStore
    /// Text available to read (the panel's current source text).
    var sourceText: String
    /// Whether the panel is pinned (auto-enabled when a panel read starts).
    var isPinned: Bool
    /// Toggle the panel pin (the host owns `coordinator.isPinned`).
    var onTogglePin: (() -> Void)?
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
    /// FastRead in:" picker in the demo below. `@Default` re-renders
    /// the view when it changes.
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
                Button {
                    onTogglePin?()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin Popup" : "Pin Popup")
                .background { InteractiveMarker() }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            RSVPView(
                viewModel: viewModel,
                presentation: .panel,
                onToggleMaximize: onToggleMaximize,
                onClose: { store.stopPanelReading() }
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
    /// picker (Manh 2026-11-20). The "coming soon" header stays — the
    /// full in-panel experience is still settling — but the subtitle no
    /// longer claims the window is unshipped (it shipped in 0.1.4): it
    /// points at the demo and the button below.
    private var demoState: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "book.pages")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Fast Read — coming soon")
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

    /// "Run FastRead in:" (Manh 2026-11-20, 05:27) — where Fast Read
    /// runs, for EVERY launch (panel button, float icon, menubar,
    /// shortcut). "New Fast Read Window" opens the separate Window Read
    /// (default, the current behavior); "Right Panel" reads here, in
    /// panel right, no separate window. Separate from the reminder's
    /// "Run reminder in:" — the two features must not share a setting.
    /// The "Read in panel" button above always reads here, whatever
    /// this says — it is the explicit panel action, not a launch.
    private var runLocationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Run FastRead in:")
                    .font(.callout)
                    .bold()
                Picker("", selection: $runLocation) {
                    ForEach(FastReadRunLocation.allCases, id: \.self) { location in
                        Text(location.displayName).tag(location)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .background { InteractiveMarker() }
            }
            Text("Applies to the Fast Read button, the float icon, and the keyboard shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
