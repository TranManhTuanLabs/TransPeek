import Testing
@testable import TransPeek

/// `needsRelaunch` tracks a grant that appears while the app is running.
/// Screen Recording and Accessibility only take effect at launch, so a
/// grant detected mid-run is visible to the checks but unusable until the
/// app is relaunched — the UI offers a one-click relaunch for exactly
/// this case instead of closing as if the permission were already usable.
@Suite(.serialized)
@MainActor
struct PermissionManagerTests {
    @Test func grantsAtLaunchDoNotNeedRelaunch() {
        let manager = PermissionManager(
            checkAccessibility: { true },
            checkScreenRecording: { true }
        )
        defer { manager.stopPolling() }
        #expect(manager.isAccessibilityGranted)
        #expect(manager.isScreenRecordingGranted)
        #expect(manager.allPermissionsGranted)
        #expect(!manager.needsRelaunch)
    }

    @Test func deniedAtLaunchDoesNotNeedRelaunch() {
        let manager = PermissionManager(
            checkAccessibility: { false },
            checkScreenRecording: { false }
        )
        defer { manager.stopPolling() }
        #expect(!manager.isAccessibilityGranted)
        #expect(!manager.isScreenRecordingGranted)
        #expect(!manager.needsRelaunch)
    }

    @Test func grantWhileRunningSetsNeedsRelaunch() {
        var accessibility = false
        var screenRecording = false
        let manager = PermissionManager(
            checkAccessibility: { accessibility },
            checkScreenRecording: { screenRecording }
        )
        defer { manager.stopPolling() }
        #expect(!manager.needsRelaunch)

        accessibility = true
        manager.refresh()
        #expect(manager.isAccessibilityGranted)
        #expect(manager.needsRelaunch)

        screenRecording = true
        manager.refresh()
        #expect(manager.allPermissionsGranted)
        #expect(manager.needsRelaunch)
    }

    @Test func revokeClearsNeedsRelaunch() {
        var accessibility = false
        let manager = PermissionManager(
            checkAccessibility: { accessibility },
            checkScreenRecording: { false }
        )
        defer { manager.stopPolling() }

        accessibility = true
        manager.refresh()
        #expect(manager.needsRelaunch)

        accessibility = false
        manager.refresh()
        #expect(!manager.isAccessibilityGranted)
        #expect(!manager.needsRelaunch)
    }

    @Test func refreshWithNoChangeKeepsNeedsRelaunchFalse() {
        let manager = PermissionManager(
            checkAccessibility: { false },
            checkScreenRecording: { false }
        )
        defer { manager.stopPolling() }
        manager.refresh()
        manager.refresh()
        #expect(!manager.needsRelaunch)
    }
}
