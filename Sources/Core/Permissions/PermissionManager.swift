import AppKit

// "AXTrustedCheckOptionPrompt" — same value as kAXTrustedCheckOptionPrompt,
// but using a string literal avoids the concurrency warning on the Unmanaged global var.
nonisolated(unsafe) private let axTrustedPromptKey = "AXTrustedCheckOptionPrompt" as CFString

/// Manages Accessibility and Screen Recording permission states with polling.
///
/// One mechanism only, like upstream MoePeek: a 1.5 s poll that starts
/// whenever a permission is missing and stops once all are granted. An
/// earlier version also re-checked on `didBecomeActive`, but that was a
/// second mechanism doing the same job — removed to match upstream.
/// (Tradeoff, same as upstream: if a permission is revoked after all
/// were granted, polling has already stopped, so the revocation is only
/// noticed after a relaunch.)
///
/// Two macOS realities shape this class, and both are why a grant made
/// outside the app is not enough on its own:
/// - Screen Recording (and Accessibility) only take effect when the app
///   launches. A grant made while TransPeek is running is visible to the
///   permission checks, but the features do not work until relaunch.
///   `needsRelaunch` tracks exactly that: a permission that flipped from
///   denied to granted while this process was running.
/// - This build is unsigned, so macOS has no stable code-signing identity
///   to attach a grant to. A grant made for a previous build can stay
///   switched on in System Settings while binding to the old binary, so
///   the new build still reads as denied. The signed upstream releases
///   do not have this problem; until TransPeek is signed, a stale entry
///   has to be removed and re-added by hand (see the recovery view).
@MainActor
@Observable
final class PermissionManager: PermissionChecking {
    private(set) var isAccessibilityGranted = false
    private(set) var isScreenRecordingGranted = false
    /// True once a permission flips from denied to granted while this
    /// process is running. The grant only takes effect after a relaunch.
    /// False at launch (any grant is already in effect) and after a
    /// permission is revoked again.
    private(set) var needsRelaunch = false
    private var pollTimer: Timer?
    /// Permission checks, injectable so tests can flip them. Default to
    /// the real system calls.
    private let checkAccessibility: () -> Bool
    private let checkScreenRecording: () -> Bool

    var allPermissionsGranted: Bool {
        isAccessibilityGranted && isScreenRecordingGranted
    }

    init(
        checkAccessibility: @escaping () -> Bool = AXIsProcessTrusted,
        checkScreenRecording: @escaping () -> Bool = CGPreflightScreenCaptureAccess
    ) {
        self.checkAccessibility = checkAccessibility
        self.checkScreenRecording = checkScreenRecording
        isAccessibilityGranted = checkAccessibility()
        isScreenRecordingGranted = checkScreenRecording()
    }

    /// Re-read both permissions right now, and restart polling if either
    /// is still missing (e.g. revoked after an update, or granted while
    /// the app was inactive).
    func refresh() {
        let accessibility = checkAccessibility()
        let screenRecording = checkScreenRecording()
        // A grant that appears while this process is running only takes
        // effect after a relaunch; remember that so the UI can offer one
        // instead of closing as if the permission were already usable.
        // A revocation clears it again — relaunching cannot restore a
        // permission that is no longer granted.
        if (!isAccessibilityGranted && accessibility)
            || (!isScreenRecordingGranted && screenRecording) {
            needsRelaunch = true
        } else if (isAccessibilityGranted && !accessibility)
            || (isScreenRecordingGranted && !screenRecording) {
            needsRelaunch = false
        }
        if accessibility != isAccessibilityGranted {
            isAccessibilityGranted = accessibility
        }
        if screenRecording != isScreenRecordingGranted {
            isScreenRecordingGranted = screenRecording
        }
        if !allPermissionsGranted {
            startPolling()
        }
    }

    /// Prompt the system accessibility permission dialog.
    func requestAccessibility() {
        let options = [axTrustedPromptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    /// Prompt the system screen recording permission dialog.
    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        startPolling()
    }

    /// Open System Settings > Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    /// Open System Settings > Screen Recording.
    ///
    /// The request comes FIRST, while TransPeek is still frontmost:
    /// `CGRequestScreenCaptureAccess()` is what registers this build in
    /// the Screen Recording list. A read-only check never registers it,
    /// and a request fired after Settings opens (app backgrounded) does
    /// not register the TCC row either — so opening Settings first would
    /// leave the user staring at a list the app is not in. The request
    /// is idempotent: if already granted or denied it just returns, and
    /// Settings (opened right after) then shows the app in the list to
    /// toggle by hand.
    func openScreenRecordingSettings() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    /// Start polling permissions every 1.5 seconds.
    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                if self.allPermissionsGranted {
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

@MainActor
protocol PermissionChecking: AnyObject {
    var isAccessibilityGranted: Bool { get }
    var isScreenRecordingGranted: Bool { get }
}
