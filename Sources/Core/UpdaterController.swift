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

    /// Check for updates, but stay silent when there is no new version.
    /// Sparkle's user-initiated check shows an "up to date" alert, while
    /// the background check only shows UI when an update is actually found.
    /// (One trade-off: a background check does not re-offer an update the
    /// user previously chose to skip.)
    func checkForUpdates() {
        sparkleController.updater.checkForUpdatesInBackground()
    }
}
