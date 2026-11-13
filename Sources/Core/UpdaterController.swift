import Combine
import Sparkle

@MainActor
@Observable
final class UpdaterController {
    private let sparkleController: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool = false {
        didSet {
            sparkleController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    init() {
        sparkleController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecksForUpdates = sparkleController.updater.automaticallyChecksForUpdates
        canCheckForUpdates = sparkleController.updater.canCheckForUpdates

        cancellable = sparkleController.updater
            .publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in
                Task { @MainActor in
                    self?.canCheckForUpdates = value
                }
            }
    }

    /// User-initiated check ("Check for Updates..." button / menu item).
    /// Uses Sparkle's user-initiated check, which shows the update prompt
    /// when a newer version is available, and an "up to date" alert when
    /// there is none. The background check (`checkForUpdatesInBackground`)
    /// must NOT be used here: it stays silent when there is no update,
    /// but it also does not re-offer an update the user previously
    /// skipped, and in practice it failed to surface the 0.1.2 update
    /// to a 0.1.1 install (2026-11-13). The "no update" alert on first
    /// launch that the user asked to suppress comes from the AUTOMATIC
    /// check, which Sparkle already runs silently in the background —
    /// not from this manual button.
    func checkForUpdates() {
        sparkleController.updater.checkForUpdates()
    }
}
