import AppKit
import SwiftUI
import Testing
@testable import TransPeek

@Suite(.serialized)
@MainActor
struct PopupPanelLayoutTests {
    @Test(arguments: [200, 350, 500], [12, 13, 16, 20])
    func longTextLayoutSettles(baselineHeight: Int, fontSize: Int) async throws {
        let preferences = LayoutTestPreferences(height: baselineHeight, fontSize: fontSize)
        defer { preferences.restore() }

        let coordinator = makeCoordinator()
        let outcome = await coordinator.ocrAndTranslate()
        #expect(outcome.shouldPresent)
        coordinator.isPinned = true
        let controller = PopupPanelController(coordinator: coordinator)
        defer { controller.dismiss() }
        let probe = ResizeProbe()
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: nil, queue: .main
        ) { notification in
            guard let panel = notification.object as? PopupPanel else { return }
            MainActor.assumeIsolated {
                probe.heights.append(panel.frame.height)
                if Thread.callStackSymbols.contains(where: { $0.contains("dispatchActions") || $0.contains("sendAction") }) {
                    probe.resizedDuringViewUpdate = true
                }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        controller.showAtCursor()
        for _ in 0..<100 where !coordinator.allFinished {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(coordinator.allFinished)
        // Wait for the layout to settle: poll until two consecutive
        // 200ms polls see no new resize (400ms of stability), up to 10s.
        // The layout MUST settle — that is the regression this test guards
        // (an unbounded resize loop never settles). How many resizes it
        // takes to get there is load-dependent (a slow CI runner can
        // legitimately resize many more times than a fast one), so the
        // test does NOT bound the total resize count. An earlier version
        // capped the count at 30 and hid the panel when it was exceeded,
        // which turned one slow layout into two failures (panel hidden
        // AND count over the cap) — the flake in runs #61/#66/#70/#74/#77
        // and #81. Counting resizes is not the property under test;
        // settling is.
        var settledCount = probe.heights.count
        var stablePolls = 0
        for _ in 0..<50 {
            try await Task.sleep(for: .milliseconds(200))
            if probe.heights.count == settledCount {
                stablePolls += 1
                if stablePolls >= 2 { break }
            } else {
                settledCount = probe.heights.count
                stablePolls = 0
            }
        }
        // Diagnostic output goes to stderr: Swift Testing captures print
        // (stdout) into the .xcresult and xcbeautify strips #expect
        // messages from the CI log, so neither is visible when a run
        // goes red. Stderr reaches the console log.
        FileHandle.standardError.write(Data("[PopupPanelLayoutTests] baselineHeight=\(baselineHeight) fontSize=\(fontSize) heights.count=\(probe.heights.count) stablePolls=\(stablePolls) isVisible=\(controller.isVisible) resizedDuringViewUpdate=\(probe.resizedDuringViewUpdate) heights=\(probe.heights)\n".utf8))
        #expect(stablePolls >= 2, "Popup layout did not settle within 10s (resizes: \(probe.heights.count))")
        #expect(controller.isVisible)
        #expect(!probe.resizedDuringViewUpdate, "Automatic resizing reentered AppKit from a SwiftUI update action")
        if baselineHeight == 350 {
            #expect(!probe.heights.isEmpty, "Long results must still grow the popup")
        }
    }

    @Test func streamingResultsRespectManualResize() async throws {
        let preferences = LayoutTestPreferences(height: 350, fontSize: 12)
        defer { preferences.restore() }
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        defer { continuation.finish() }
        let coordinator = makeCoordinator(provider: LayoutTestProvider(stream: stream))
        coordinator.translate("Short source")
        coordinator.isPinned = true
        let controller = PopupPanelController(coordinator: coordinator)
        defer { controller.dismiss() }
        controller.showAtCursor()
        try await Task.sleep(for: .milliseconds(100))
        let visiblePanel = NSApp.windows.compactMap { $0 as? PopupPanel }.first(where: \.isVisible)
        let panel = try #require(visiblePanel)

        panel.isUserResizing = true
        let manualFrame = NSRect(x: panel.frame.minX, y: panel.frame.maxY - 220, width: 450, height: 220)
        panel.setFrame(manualFrame, display: true)
        continuation.yield(longText)
        try await Task.sleep(for: .milliseconds(100))
        #expect(panel.frame == manualFrame)

        panel.manualResizeGeneration = coordinator.translationGeneration
        panel.isUserResizing = false
        continuation.yield(longText + "\n" + longText)
        continuation.finish()
        try await Task.sleep(for: .milliseconds(100))
        #expect(coordinator.allFinished)
        #expect(panel.frame == manualFrame)
    }

    @Test func dismissAndReopenDiscardsPendingResize() async throws {
        let preferences = LayoutTestPreferences(height: 350, fontSize: 12)
        defer { preferences.restore() }
        let coordinator = makeCoordinator()
        let controller = PopupPanelController(coordinator: coordinator)
        defer { controller.dismiss() }
        coordinator.translate(longText)
        coordinator.isPinned = true
        controller.showAtCursor()
        controller.dismiss()

        coordinator.translate("Short result")
        coordinator.isPinned = true
        controller.showAtCursor()
        try await Task.sleep(for: .milliseconds(200))
        let visiblePanel = NSApp.windows.compactMap { $0 as? PopupPanel }.first(where: \.isVisible)
        let panel = try #require(visiblePanel)
        #expect(coordinator.allFinished)
        #expect(panel.frame.height == 350)
        controller.dismiss()
        try await Task.sleep(for: .milliseconds(50))
        #expect(!controller.isVisible)
    }

    private var longText: String {
        Array(repeating: "A network setting can change the routing of application traffic. Some system services use separate connections to maintain expected device functionality.", count: 3).joined(separator: "\n")
    }

    private func makeCoordinator(provider: LayoutTestProvider = LayoutTestProvider()) -> TranslationCoordinator {
        let registry = TranslationProviderRegistry(
            providers: [provider],
            enabledProviderIDs: { [provider.id] },
            providerOrder: { [provider.id] },
            onDemandProviderIDs: { [] }
        )
        let text = longText
        return TranslationCoordinator(
            permissionManager: LayoutTestPermissions(),
            registry: registry,
            captureOCR: { text }
        )
    }
}

@MainActor
private struct LayoutTestPreferences {
    private let previous = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)

    init(height: Int, fontSize: Int) {
        // Override only this process; never persist test dimensions to the user's app settings.
        UserDefaults.standard.setVolatileDomain(previous.merging([
            "popupDefaultWidth": 450,
            "popupDefaultHeight": height,
            "popupInputHeight": 48,
            "popupFontSize": fontSize,
            "popupFontName": "",
            "popupRememberPosition": false,
            "ttsAutoPlaySource": false,
            "ttsAutoPlayTarget": false,
        ]) { _, new in new }, forName: UserDefaults.argumentDomain)
    }

    func restore() {
        UserDefaults.standard.setVolatileDomain(previous, forName: UserDefaults.argumentDomain)
    }
}

@MainActor
private final class LayoutTestPermissions: PermissionChecking {
    let isAccessibilityGranted = true
    let isScreenRecordingGranted = true
}

@MainActor
private final class ResizeProbe {
    var heights: [CGFloat] = []
    var resizedDuringViewUpdate = false
}

private struct LayoutTestProvider: TranslationProvider {
    var stream: AsyncThrowingStream<String, Error>?
    let id = "layout-test"
    let displayName = "Layout Test"
    let iconSystemName = "character.bubble"
    let supportsStreaming = true
    let isAvailable = true
    @MainActor var isConfigured: Bool { true }

    func translateStream(_ text: String, from sourceLang: String?, to targetLang: String) -> AsyncThrowingStream<String, Error> {
        if let stream { return stream }
        return AsyncThrowingStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }

    @MainActor func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
