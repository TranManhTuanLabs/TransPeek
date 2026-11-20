import Defaults
import SwiftUI

/// Focus & Rest card for panel left (Manh 2026-11-20, focus timer +
/// panel decor): Pomodoro (standard logic) + rest eyes (20-20-20) +
/// where the reminder shows. It sits UNDER the Keyboard Shortcuts
/// card, ABOVE the Share row — in its own file, so it is easy to
/// delete later if the timer moves out of panel left.
///
/// The card is display + controls only: the timers live in
/// `FocusTimerStore` (one store for the app), so a reminder fired
/// while the panel is hidden still works.
///
/// Collapsible like the two cards above it (header toggles, state in
/// `focusTimerCollapsed`). Every button / picker carries an
/// `InteractiveMarker` — without it the panel treats a click as a
/// window drag (Manh 2026-11-17, build #207).
struct FocusTimerCard: View {
    @ObservedObject var store: FocusTimerStore
    /// Whether the card is collapsed (header only). Owned by PopupView,
    /// persisted to Defaults.
    @Binding var isCollapsed: Bool

    /// Work / rest minutes (Manh 2026-11-20): pickers, so the user can
    /// change them. `@Default` re-renders the card when they change.
    @Default(.focusWorkMinutes) private var workMinutes
    @Default(.focusRestMinutes) private var restMinutes
    /// Where a reminder shows (Manh 2026-11-20, 04:44): the "Run
    /// reminder in:" picker. Applies ONLY to the reminder — Fast Read
    /// has its OWN separate setting ("Run FastRead in:", panel right,
    /// Manh 2026-11-20, 05:27).
    @Default(.focusReminderDestination) private var reminderDestination
    /// Continuous Pomodoro (Manh 2026-11-20, 07:12; default ON,
    /// Manh 2026-11-20, 07:25): when ON, the next session starts
    /// automatically after each rest / long break. Default ON.
    @Default(.focusRepeatAutomatically) private var repeatAutomatically
    /// Auto start focus (Manh 2026-11-20, 09:47; default OFF): when
    /// ON, the focus timer starts on its own at app launch — no need
    /// to open the panel and press Start.
    @Default(.focusAutoStart) private var autoStartFocus

    /// Work-minute picker options (Manh 2026-11-20): the standard
    /// Pomodoro choices, default 25.
    private static let workMinuteOptions = [5, 10, 15, 20, 25, 30, 45, 60]
    /// Rest-minute picker options, default 5.
    private static let restMinuteOptions = [5, 10, 15]

    private var pomodoroButtonLabel: String {
        if store.pomodoroPhase == .idle { return "Start focus" }
        return store.pomodoroRunning ? "Pause" : "Resume"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — the WHOLE top bar of the card is the toggle
            // (same pattern as FlowIntroCard, Manh 2026-11-18): tapping
            // anywhere on it expands/collapses the card.
            Button {
                isCollapsed.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Text("Focus & Rest")
                        .font(.headline)
                    // Orange dot (Manh 2026-11-20, 05:33): a break
                    // reminder fired while reading and is waiting — it
                    // shows when the read stops; the banner above the
                    // tabs (and the system notification) carries the
                    // "Take a break" / "Snooze 5 min" actions.
                    if store.pendingReminder != nil {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .help("A break reminder is waiting")
                    }
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, isCollapsed ? 10 : 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Show focus timer" : "Hide focus timer")
            .background { InteractiveMarker() }

            if !isCollapsed {
                pomodoroSection
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                restEyesSection
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                reminderSection
                    .padding(.bottom, 10)
            }
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Pomodoro

    /// Pomodoro — STANDARD logic (Manh 2026-11-20, 04:08): Work 25 /
    /// Rest 5 by default, long break 15 after 4 focus cycles.
    /// Continuous mode ("Repeat automatically", Manh 2026-11-20,
    /// 07:12; default ON, Manh 2026-11-20, 07:25): when ON, the next
    /// session starts on its own after each break; OFF waits for a
    /// manual start.
    private var pomodoroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "heart")
                    .foregroundStyle(.secondary)
                Text("Focus")
                    .font(.callout)
                    .bold()
                Spacer()
                Text(store.pomodoroPhase.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)

            // Countdown — big, monospaced, so it reads as a timer.
            // Centered (Manh 2026-11-20, 17:11): the timer is the
            // card's centerpiece, so it sits in the middle, not at
            // the left edge with the pickers below it.
            Text(FocusTimerStore.mmss(store.pomodoroRemainingSeconds))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            // Work / Rest pickers. The label names the default (Manh
            // 2026-11-20, 03:44 — any setting with a default shows it
            // in its name, so the user knows what to set it back to);
            // the value comes from the key's default, not hardcoded.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Work (default: \(Defaults.Keys.focusWorkMinutes.defaultValue) min):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $workMinutes) {
                        ForEach(Self.workMinuteOptions, id: \.self) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)
                }
                .background { InteractiveMarker() }
                // Changing the work length while idle re-arms the next
                // interval at once, so the timer shows the new length
                // before Start. Mid-interval it only affects the next
                // one — the running interval keeps its started length.
                .onChange(of: workMinutes) { _, newValue in
                    if store.pomodoroPhase == .idle {
                        store.pomodoroRemainingSeconds = newValue * 60
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Rest (default: \(Defaults.Keys.focusRestMinutes.defaultValue) min):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $restMinutes) {
                        ForEach(Self.restMinuteOptions, id: \.self) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)
                }
                .background { InteractiveMarker() }
            }
            .padding(.horizontal, 12)

            // Cycle dots — one per focus interval in the round; a long
            // break follows the 4th. Centered (Manh 2026-11-20, 17:11),
            // dots on their own line with the "Long break … after 4
            // cycles" note on the line below — so the row reads as a
            // centered stack instead of a left-aligned run-on line.
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < store.completedFocusCycles ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text("Long break \(Defaults.Keys.focusLongBreakMinutes.defaultValue) min after 4 cycles")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Start / Reset — centered (Manh 2026-11-20, 17:11): the
            // main action row sits under the centered timer and dots.
            HStack(spacing: 8) {
                Button(pomodoroButtonLabel) {
                    store.togglePomodoro()
                }
                .buttonStyle(.borderedProminent)
                .help("Start, pause, or resume the focus timer")
                .background { InteractiveMarker() }

                Button("Reset") {
                    store.resetPomodoro()
                }
                .buttonStyle(.bordered)
                .help("Back to idle — clears the timer and the cycle count")
                .background { InteractiveMarker() }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)

            // "Repeat automatically" (Manh 2026-11-20, 07:12;
            // default ON, Manh 2026-11-20, 07:25): continuous
            // Pomodoro — when ON, the next session starts on its own
            // after each rest / long break, looping until the user
            // turns it off or stops it. OFF: each session ends and
            // waits for a manual start.
            // Explicit `.switch` style (Manh 2026-11-20, build 292):
            // the plain Toggle rendered as a checkbox (✓ tick) in the
            // app, so the sliding-switch look is forced here instead
            // of trusting the default style.
            Toggle("Repeat automatically", isOn: $repeatAutomatically)
                .toggleStyle(.switch)
                .help("When on, the next session starts automatically after each break — Work → Rest → Work …, until you turn it off or stop it")
                .background { InteractiveMarker() }
                .padding(.horizontal, 12)

            // "Auto start focus" (Manh 2026-11-20, 09:47; default
            // OFF — the label names the default, Manh 2026-11-20,
            // 03:44): when ON, the focus timer starts on its own
            // every time the app launches, as if the user pressed
            // Start — no need to open the panel and press Start.
            // OFF waits for a manual start, as before.
            // Same explicit `.switch` style as "Repeat automatically"
            // above (Manh 2026-11-20, build 292): the plain Toggle
            // rendered as a checkbox (✓ tick), so the switch look is
            // forced here too.
            Toggle("Auto start focus (default: \(Defaults.Keys.focusAutoStart.defaultValue ? "On" : "Off"))", isOn: $autoStartFocus)
                .toggleStyle(.switch)
                .help("When on, the focus timer starts automatically every time the app launches — no need to open the panel and press Start")
                .background { InteractiveMarker() }
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Rest eyes (20-20-20)

    /// Rest eyes — the 20-20-20 rule (Manh 2026-11-20): every 20 min,
    /// rest the eyes for 20 s. Fixed intervals (the rule is the point,
    /// no picker); its own Start / Stop, independent of Pomodoro.
    private var restEyesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.secondary)
                Text("Rest eyes (20-20-20)")
                    .font(.callout)
                    .bold()
                Spacer()
                Text(store.eyeRestRunning
                     ? "Next in \(FocusTimerStore.mmss(store.eyeRestRemainingSeconds))"
                     : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)

            Text("Every 20 min, rest your eyes for 20 s — look at something 20 feet away.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            // "Start eye reminders" — centered (Manh 2026-11-20,
            // 17:11), like the Focus action row above it.
            Button(store.eyeRestRunning ? "Stop eye reminders" : "Start eye reminders") {
                store.toggleEyeRest()
            }
            .buttonStyle(.bordered)
            .help("Remind me every 20 minutes to rest my eyes for 20 seconds")
            .background { InteractiveMarker() }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Reminder destination

    /// "Run reminder in:" (Manh 2026-11-20, 04:44) — where a focus /
    /// rest-eyes reminder shows. Applies ONLY to the reminder: "New
    /// Fast Read Window" opens a separate Rest window; "Right Panel"
    /// shows the reminder inside panel right, no separate window.
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Run reminder in:")
                    .font(.callout)
                    .bold()
                Picker("", selection: $reminderDestination) {
                    ForEach(FocusReminderDestination.allCases, id: \.self) { destination in
                        Text(destination.displayName).tag(destination)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .background { InteractiveMarker() }
            }
            .padding(.horizontal, 12)

            Text("Applies only to focus / rest-eyes reminders — not to Fast Read itself.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }
    }
}

