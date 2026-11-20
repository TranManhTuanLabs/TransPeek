import SwiftUI

/// Banner for a break reminder that fired while the user was reading
/// (Manh 2026-11-20, 05:33): the reminder waits instead of stealing
/// the read. Shown in the panel (above the tab content, on every tab)
/// while `store.pendingReminder` is set, with the same two actions as
/// the system notification: "Take a break" and "Snooze 5 min".
///
/// Its own view (observing the store) so the panel itself never
/// re-renders on the timer's one-second ticks — only this small banner
/// does. Every button carries an `InteractiveMarker` (panel clicks are
/// window drags without it, Manh 2026-11-17, build #207).
struct PendingReminderBanner: View {
    @ObservedObject var store: FocusTimerStore

    var body: some View {
        if let pending = store.pendingReminder {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pending.kind.notificationTitle)
                        .font(.callout)
                        .bold()
                    Text("Your reading stays as it is.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Take a break") {
                    store.takePendingBreakNow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Show the break reminder now")
                .background { InteractiveMarker() }
                Button("Snooze 5 min") {
                    store.snoozePendingReminder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Remind me again in 5 minutes")
                .background { InteractiveMarker() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }
}
