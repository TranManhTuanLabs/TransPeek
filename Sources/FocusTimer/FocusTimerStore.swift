import Defaults
import SwiftUI

/// What kind of focus reminder fired (Manh 2026-11-20, focus timer +
/// panel decor).
enum FocusReminderKind {
    /// A Pomodoro work interval ended (carries the work minutes, so the
    /// message names the real duration, not a hardcoded 25).
    case workBreak(minutes: Int)
    /// A 20-20-20 eye-rest interval ended.
    case eyeRest

    /// The text the reminder RSVP-reads.
    var message: String {
        switch self {
        case .workBreak(let minutes):
            return "You have read, worked, and sat for \(minutes) minutes continuously. Rest your eyes and brain. Stand up and walk around. Be more physically active."
        case .eyeRest:
            return "Rest your eyes. Look at something 20 feet away for 20 seconds."
        }
    }

    /// Title of the Rest window / reminder countdown.
    var title: String {
        switch self {
        case .workBreak: return "Take a break"
        case .eyeRest: return "Rest your eyes"
        }
    }
}

/// A request to show text reading in panel right (Manh 2026-11-20).
/// Set by the timer when a reminder fires with destination Right Panel;
/// `PopupView` observes it, switches to the Fast Read tab, and starts
/// the read. `countdownSeconds` is the rest countdown shown after the
/// read finishes (`nil` = a plain read, no countdown).
struct PanelRightRequest: Equatable {
    let text: String
    let countdownSeconds: Int?
}

/// Pomodoro phase (STANDARD logic, Manh 2026-11-20, 04:08): Work /
/// Rest, long break after 4 focus cycles.
enum FocusPomodoroPhase {
    case idle
    case focus
    case rest
    case longBreak

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .rest: return "Rest"
        case .longBreak: return "Long break"
        }
    }
}

/// Owns the focus timer + rest-eyes timer and routes their reminders
/// (Manh 2026-11-20, focus timer + panel decor). One store for the app
/// (created by `AppDelegate`, passed to the panel controller): the
/// panel-left card, the panel-right reading view, and the Rest window
/// all read the same state, so a reminder fired while the panel is
/// hidden still finds its way to the right place.
///
/// Timers tick once a second from a single `Task` (no `Timer`
/// publisher — the task stops itself when nothing runs, so there is
/// no runloop timer left behind). The Pomodoro and the 20-20-20 eye
/// timer run independently: either can fire while the other runs.
@MainActor
final class FocusTimerStore: ObservableObject {
    /// 20-20-20 rule (fixed — the rule is the point, no picker):
    /// every 20 min, rest the eyes for 20 s.
    static let eyeRestIntervalSeconds = 20 * 60
    static let eyeRestCountdownSeconds = 20

    /// Called when a reminder must be shown in panel right and the
    /// panel may be hidden (set by `AppDelegate`): brings the panel
    /// forward; `PopupView` switches to the Fast Read tab from the
    /// pending `panelRightRequest`.
    var onShowPanel: (() -> Void)?

    // MARK: - Pomodoro

    @Published var pomodoroPhase: FocusPomodoroPhase = .idle
    @Published var pomodoroRunning = false
    @Published var pomodoroRemainingSeconds = Defaults[.focusWorkMinutes] * 60
    /// Focus intervals finished in the current round (resets after a
    /// long break).
    @Published var completedFocusCycles = 0

    // MARK: - Rest eyes (20-20-20)

    @Published var eyeRestRunning = false
    @Published var eyeRestRemainingSeconds = eyeRestIntervalSeconds

    // MARK: - Panel-right reading

    /// Pending request to read in panel right (consumed by `PopupView`).
    @Published var panelRightRequest: PanelRightRequest?
    /// View model of the read currently running in panel right (`nil`
    /// = the panel shows the demo instead). Lives here — not in
    /// `PopupView` — because the panel view tree is rebuilt on every
    /// show, and a reminder fired while the panel is hidden must still
    /// have a view model waiting when the panel opens.
    @Published var panelReadingViewModel: RSVPViewModel?
    /// Rest countdown (seconds) shown in panel right after a reminder
    /// read finishes (`nil` = no countdown running).
    @Published var panelReminderCountdown: Int?
    /// Rest seconds for the current panel read (`nil` = plain read).
    private var panelReadingCountdownSeconds: Int?

    private let restWindowController = RestWindowController()
    private var tickerTask: Task<Void, Never>?
    private var tickerToken = 0
    private var panelCountdownTask: Task<Void, Never>?

    // MARK: - Pomodoro controls

    /// Start a focus interval, or pause / resume the current one.
    func togglePomodoro() {
        if pomodoroPhase == .idle {
            pomodoroPhase = .focus
            pomodoroRemainingSeconds = Defaults[.focusWorkMinutes] * 60
            pomodoroRunning = true
        } else {
            pomodoroRunning.toggle()
        }
        if pomodoroRunning { ensureTicker() }
    }

    /// Back to idle — a fresh start, so the cycle count resets too.
    func resetPomodoro() {
        pomodoroRunning = false
        pomodoroPhase = .idle
        completedFocusCycles = 0
        pomodoroRemainingSeconds = Defaults[.focusWorkMinutes] * 60
    }

    // MARK: - Rest-eyes controls

    /// Start / stop the 20-20-20 reminders (independent of Pomodoro).
    func toggleEyeRest() {
        eyeRestRunning.toggle()
        if eyeRestRunning {
            if eyeRestRemainingSeconds <= 0 {
                eyeRestRemainingSeconds = Self.eyeRestIntervalSeconds
            }
            ensureTicker()
        }
    }

    // MARK: - Timer engine

    private func ensureTicker() {
        guard tickerTask == nil else { return }
        tickerToken += 1
        let token = tickerToken
        tickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.tick()
                if !self.pomodoroRunning && !self.eyeRestRunning { break }
            }
            // Only clear our own slot: a newer ticker may have started
            // while this one was exiting (see ensureTicker's guard).
            if self.tickerToken == token {
                self.tickerTask = nil
            }
        }
    }

    private func tick() {
        if pomodoroRunning {
            if pomodoroRemainingSeconds > 0 {
                pomodoroRemainingSeconds -= 1
            }
            if pomodoroRemainingSeconds == 0 {
                pomodoroIntervalEnded()
            }
        }
        if eyeRestRunning {
            if eyeRestRemainingSeconds > 0 {
                eyeRestRemainingSeconds -= 1
            }
            if eyeRestRemainingSeconds == 0 {
                eyeRestRemainingSeconds = Self.eyeRestIntervalSeconds
                fireReminder(.eyeRest, countdownSeconds: Self.eyeRestCountdownSeconds)
            }
        }
    }

    private func pomodoroIntervalEnded() {
        switch pomodoroPhase {
        case .focus:
            completedFocusCycles += 1
            let isLongBreak = completedFocusCycles % 4 == 0
            let restMinutes = isLongBreak
                ? Defaults[.focusLongBreakMinutes]
                : Defaults[.focusRestMinutes]
            fireReminder(
                .workBreak(minutes: Defaults[.focusWorkMinutes]),
                countdownSeconds: restMinutes * 60
            )
            // The rest counts down on its own; the user pauses it from
            // the card if needed.
            pomodoroPhase = isLongBreak ? .longBreak : .rest
            pomodoroRemainingSeconds = restMinutes * 60
        case .rest:
            pomodoroPhase = .idle
            pomodoroRunning = false
            pomodoroRemainingSeconds = Defaults[.focusWorkMinutes] * 60
        case .longBreak:
            pomodoroPhase = .idle
            pomodoroRunning = false
            completedFocusCycles = 0
            pomodoroRemainingSeconds = Defaults[.focusWorkMinutes] * 60
        case .idle:
            break
        }
    }

    /// Route a reminder to its destination (Manh 2026-11-20, 04:44):
    /// the "Run reminder in:" setting applies ONLY to the reminder —
    /// Fast Read has its OWN separate setting ("Run FastRead in:",
    /// Manh 2026-11-20, 05:27), so this never touches Fast Read.
    private func fireReminder(_ kind: FocusReminderKind, countdownSeconds: Int) {
        switch Defaults[.focusReminderDestination] {
        case .newWindow:
            restWindowController.show(
                text: kind.message,
                countdownSeconds: countdownSeconds,
                title: kind.title
            )
        case .rightPanel:
            panelRightRequest = PanelRightRequest(
                text: kind.message,
                countdownSeconds: countdownSeconds
            )
            onShowPanel?()
        }
    }

    // MARK: - Panel-right reading

    /// Start reading `text` in panel right (called by `PopupView`
    /// when it consumes a `panelRightRequest`, and by the panel-right
    /// "Read in panel" button). Starts playing at once — a reminder
    /// must read itself, and a manual panel read is started by an
    /// explicit tap, so there is nothing to wait for. When the read
    /// finishes, the panel shows `countdownSeconds` (if any) and then
    /// returns to the demo.
    func startPanelReading(text: String, countdownSeconds: Int? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stopPanelReading()
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
        panelReadingCountdownSeconds = countdownSeconds
        panelReadingViewModel = viewModel
        viewModel.play()
    }

    /// Stop a panel read (panel dismissed, read finished its countdown,
    /// or a new read replaces it).
    func stopPanelReading() {
        panelCountdownTask?.cancel()
        panelCountdownTask = nil
        panelReminderCountdown = nil
        panelReadingCountdownSeconds = nil
        panelRightRequest = nil
        panelReadingViewModel?.pause()
        panelReadingViewModel = nil
    }

    /// Start the rest countdown after a reminder read finishes
    /// (called by the panel-right view when it sees `isFinished`).
    /// At zero the panel returns to the demo.
    func startPanelReminderCountdown() {
        guard panelReminderCountdown == nil,
              let seconds = panelReadingCountdownSeconds, seconds > 0
        else { return }
        panelReminderCountdown = seconds
        panelCountdownTask?.cancel()
        panelCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let current = self.panelReminderCountdown else { break }
                if current <= 1 {
                    self.stopPanelReading()
                    break
                }
                self.panelReminderCountdown = current - 1
            }
        }
    }

    // MARK: - Formatting

    /// "24:59" for a countdown, "5:00" for five minutes.
    static func mmss(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
    }
}
