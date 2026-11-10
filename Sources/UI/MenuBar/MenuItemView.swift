import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    let appDelegate: AppDelegate

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// CI build number (`CFBundleVersion`; CI sets it to the GitHub run
    /// number). Shown in the header so the current build can be checked at
    /// a glance without opening Settings. Hidden for local builds, where the
    /// build number is the default "1" (same rule as About's "Build CI #").
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var headerTitle: String {
        buildNumber == "1"
            ? "TransPeek \(appVersion)"
            : "TransPeek \(appVersion) (\(buildNumber))"
    }

    /// Section headline: a plain Text (not a Button), dimmed so it reads as a
    /// greyed-out section header and is not clickable. No Divider between a
    /// headline and its first item.
    private func sectionHeadline(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
    }

    var body: some View {
        Text(headerTitle)
            .font(.headline)

        Divider()

        sectionHeadline("Text Capture from Screen")

        Button {
            appDelegate.performSmartTranslation()
        } label: {
            Label("Smart Translation", systemImage: "wand.and.stars")
        }
        .globalKeyboardShortcut(.smartTranslation)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            appDelegate.cancelSmartTranslation()
            coordinator.prepareInputMode()
            panelController.showAtScreenCenter()
        } label: {
            Label("Manual Translation", systemImage: "keyboard")
        }
        .globalKeyboardShortcut(.inputTranslation)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            appDelegate.cancelSmartTranslation()
            Task {
                let outcome = await coordinator.ocrAndTranslate()
                if outcome.shouldPresent {
                    panelController.showAtCursor()
                }
            }
        } label: {
            Label("Screenshot OCR", systemImage: "text.viewfinder")
        }
        .globalKeyboardShortcut(.ocrScreenshot)

        Button {
            appDelegate.performSilentOCR()
        } label: {
            Label("Clipboard OCR", systemImage: "doc.text.viewfinder")
        }
        .globalKeyboardShortcut(.silentOCR)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task { @MainActor in
                await appDelegate.cancelSmartTranslationAndWait()
                let outcome = await coordinator.translateSelection()
                if outcome.shouldPresent {
                    panelController.showAtCursor()
                }
            }
        } label: {
            Label("Selection Translation", systemImage: "text.cursor")
        }
        .globalKeyboardShortcut(.translateSelection)

        Button {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task { @MainActor in
                await appDelegate.cancelSmartTranslationAndWait()
                await coordinator.translateClipboard()
                panelController.showAtCursor()
            }
        } label: {
            Label("Clipboard Translation", systemImage: "doc.on.clipboard")
        }
        .globalKeyboardShortcut(.clipboardTranslation)

        Button {
            appDelegate.performScreenshotCopy()
        } label: {
            Label("Screenshot Copy", systemImage: "photo")
        }
        .globalKeyboardShortcut(.screenshotCopy)

        Divider()

        sectionHeadline("Barcodes / QR Codes")

        Button {
            appDelegate.performScanBarcodes()
        } label: {
            Label("Scan Barcodes/QR Codes", systemImage: "barcode.viewfinder")
        }
        .globalKeyboardShortcut(.scanBarcodes)

        Divider()

        Button {
            appDelegate.onboardingController.showWindow()
        } label: {
            Label("Permissions Guide...", systemImage: "questionmark.circle")
        }

        Button {
            appDelegate.updaterController.checkForUpdates()
        } label: {
            Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(!appDelegate.updaterController.canCheckForUpdates)

        Button {
            appDelegate.settingsController.showWindow()
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit TransPeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
