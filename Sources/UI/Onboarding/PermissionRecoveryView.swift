import SwiftUI

/// Simplified view shown when permissions are lost after an app update.
/// Displays permission status cards and auto-closes once all are re-granted.
struct PermissionRecoveryView: View {
    let permissionManager: PermissionManager
    let onAllGranted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Permissions Need Re-Authorization")
                .font(.title2.bold())

            Text("After updating, macOS may revoke previously granted permissions. Please re-authorize below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                PermissionCardView(
                    icon: "hand.raised",
                    title: "Accessibility",
                    description: "Required for reading selected text",
                    isGranted: permissionManager.isAccessibilityGranted,
                    onOpenSettings: { permissionManager.openAccessibilitySettings() }
                )

                PermissionCardView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required for OCR screenshot translation",
                    isGranted: permissionManager.isScreenRecordingGranted,
                    onOpenSettings: { permissionManager.openScreenRecordingSettings() }
                )
            }
            .padding(.horizontal, 24)

            // A grant made while TransPeek is running only takes effect
            // after a relaunch, so do not close as if it were already
            // usable — offer a one-click relaunch instead.
            if permissionManager.allPermissionsGranted && permissionManager.needsRelaunch {
                VStack(spacing: 8) {
                    Text("Permissions granted — relaunch so macOS applies them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Relaunch TransPeek") {
                        AppRelaunch.relaunch()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24)
            }

            Text("Status updates automatically after granting. If a status stays unchanged after granting and relaunching, remove TransPeek from that list in System Settings and add it again — this build is unsigned, so macOS can keep an old entry that no longer matches the current build.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .onChange(of: permissionManager.allPermissionsGranted) {
            // Close once everything is granted and usable. When a grant
            // appeared while running, it only takes effect after a
            // relaunch — stay open and show the relaunch button instead.
            if permissionManager.allPermissionsGranted && !permissionManager.needsRelaunch {
                onAllGranted()
            }
        }
    }
}
