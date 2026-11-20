import UserNotifications

/// System notification for a break reminder that fired while the user
/// was reading (Manh 2026-11-20, 05:33): the reminder must NOT steal
/// the read — instead macOS shows this notification (plus the in-panel
/// banner) with two actions: "Take a break" (show the reminder now)
/// and "Snooze 5 min" (remind again in 5 minutes).
///
/// Owned by AppDelegate (it holds it strongly — `UNUserNotificationCenter`
/// keeps its delegate weak). The store never touches UserNotifications
/// directly: it calls `onNotifyReminder`, and AppDelegate forwards to
/// `notify(kind:)`.
///
/// NOT `@MainActor`: `UNUserNotificationCenterDelegate` is a non-Sendable
/// protocol, and a MainActor-isolated type conforming to it is an error
/// in the Swift 6 language mode. This class is `@unchecked Sendable`
/// instead — the only mutable state is `onTakeBreakNow` / `onSnooze`
/// (set once by AppDelegate at launch, before any notification can
/// fire) and `categoriesRegistered` (touched only from `notify`, which
/// the store always calls on the MainActor). The delegate methods hop
/// to the MainActor before touching the store.
final class ReminderNotifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    /// Notification category for the reminder (its two actions).
    static let categoryID = "transpeek.focusReminder"
    /// "Take a break" — show the pending reminder now.
    static let takeBreakActionID = "transpeek.focusReminder.takeBreakNow"
    /// "Snooze 5 min" — remind again in 5 minutes.
    static let snoozeActionID = "transpeek.focusReminder.snooze5Min"
    /// One pending reminder at a time: a re-fire replaces the old
    /// notification instead of piling up in Notification Center.
    static let requestID = "transpeek.focusReminder.pending"

    /// Called when the user taps "Take a break" (set by AppDelegate).
    var onTakeBreakNow: (() -> Void)?
    /// Called when the user taps "Snooze 5 min" (set by AppDelegate).
    var onSnooze: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var categoriesRegistered = false

    /// Post the reminder notification (Manh 2026-11-20, 05:33). Asks
    /// for permission first if undecided; silently does nothing if
    /// denied — the in-panel banner + card dot still work, so a denied
    /// permission never loses the reminder.
    func notify(kind: FocusReminderKind) {
        registerCategoriesIfNeeded()
        center.getNotificationSettings { settings in
            // Read the status here (this closure is nonisolated) —
            // `settings` itself is non-Sendable and must not cross
            // into the MainActor Task below (Swift 6). The status
            // enum is Sendable, so it can.
            let status = settings.authorizationStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .notDetermined:
                    let granted = (try? await self.center.requestAuthorization(options: [.alert, .sound])) ?? false
                    guard granted else { return }
                    self.post(kind: kind)
                case .authorized, .provisional:
                    self.post(kind: kind)
                default:
                    break
                }
            }
        }
    }

    private func registerCategoriesIfNeeded() {
        guard !categoriesRegistered else { return }
        categoriesRegistered = true
        let takeBreak = UNNotificationAction(
            identifier: Self.takeBreakActionID,
            title: "Take a break",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 5 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [takeBreak, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func post(kind: FocusReminderKind) {
        let content = UNMutableNotificationContent()
        content.title = kind.notificationTitle
        content.body = kind.message
        content.categoryIdentifier = Self.categoryID
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.requestID,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the notification even when the app is frontmost (macOS
    /// otherwise suppresses it) — the user is reading, so the app IS
    /// frontmost when this matters most.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // The system may call this on any thread; the store lives on
        // the MainActor, so hop there before touching it.
        let action = response.actionIdentifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch action {
            case Self.takeBreakActionID:
                self.onTakeBreakNow?()
            case Self.snoozeActionID:
                self.onSnooze?()
            default:
                break
            }
        }
        completionHandler()
    }
}
