import AppKit

// "AXTrustedCheckOptionPrompt" — same value as kAXTrustedCheckOptionPrompt,
// but using a string literal avoids the concurrency warning on the Unmanaged global var.
nonisolated(unsafe) private let axTrustedPromptKey = "AXTrustedCheckOptionPrompt" as CFString

/// Manages Accessibility and Screen Recording permission states with polling.
@MainActor
@Observable
final class PermissionManager: PermissionChecking {
    private(set) var isAccessibilityGranted = false
    private(set) var isScreenRecordingGranted = false
    private var pollTimer: Timer?
    /// Kept for the app's lifetime; the manager is created once at launch
    /// and never deallocated, so this observer needs no removal.
    private var activationObserver: NSObjectProtocol?

    var allPermissionsGranted: Bool {
        isAccessibilityGranted && isScreenRecordingGranted
    }

    init() {
        isAccessibilityGranted = AXIsProcessTrusted()
        isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
        // Re-check when the app comes to the foreground: the user may have
        // granted a permission in System Settings while TransPeek was in the
        // background, after polling already stopped. Without this, a grant
        // made outside the app is never picked up until relaunch.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// Re-read both permissions right now, and restart polling if either
    /// is still missing (e.g. revoked after an update, or granted while
    /// the app was inactive).
    func refresh() {
        let accessibility = AXIsProcessTrusted()
        let screenRecording = CGPreflightScreenCaptureAccess()
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
    func openScreenRecordingSettings() {
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
