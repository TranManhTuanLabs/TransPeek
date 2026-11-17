import AppKit
import Defaults
import KeyboardShortcuts

/// Handles app lifecycle, permission checks, and global shortcut registration.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // registry must be available before applicationDidFinishLaunching because
    // SwiftUI evaluates TransPeekApp.body (which reads registry) during app init.
    lazy var registry = TranslationProviderRegistry.builtIn()
    lazy var ttsRegistry = TTSProviderRegistry.builtIn()
    lazy var ttsCoordinator = TTSCoordinator(registry: ttsRegistry)
    var coordinator: TranslationCoordinator!
    var panelController: PopupPanelController!
    var permissionManager: PermissionManager!
    var onboardingController: OnboardingWindowController!
    var selectionMonitor: SelectionMonitor!
    var triggerIconController: TriggerIconController!
    lazy var copyToastController = CopyToastController()
    lazy var updaterController = UpdaterController()
    /// Fast Read (RSVP) window controller (Manh 2026-11-17).
    lazy var rsvpWindowController = RSVPWindowController()
    var settingsController: SettingsWindowController!
    private var smartTranslationTask: Task<Void, Never>?
    private var smartTranslationTaskID: UUID?

    func applicationDidFinishLaunching(_: Notification) {
        applyLanguageOverride()

        // Migrate old settings to new namespaced keys (one-time)
        migrateDefaults()

        permissionManager = PermissionManager()
        coordinator = TranslationCoordinator(permissionManager: permissionManager, registry: registry)
        settingsController = SettingsWindowController(
            registry: registry,
            ttsRegistry: ttsRegistry,
            ttsCoordinator: ttsCoordinator,
            updaterController: updaterController
        )
        panelController = PopupPanelController(
            coordinator: coordinator,
            ttsCoordinator: ttsCoordinator,
            settingsController: settingsController
        )
        panelController.onOCRCopyOnlySuccess = { [weak self] in
            self?.copyToastController.show(message: String(localized: "Copied"))
        }
        // The "?" shortcuts panel (PopupView) runs actions through this:
        // its Run buttons call performShortcut, the same dispatch the
        // physical hotkeys use, so a click and a keypress do the same thing.
        panelController.onRunShortcut = { [weak self] name in
            self?.performShortcut(name)
        }
        // The panel's "Fast Read" button opens the RSVP reading window
        // with the text being translated (Manh 2026-11-17).
        panelController.onFastRead = { [weak self] text in
            self?.performFastRead(text: text)
        }
        onboardingController = OnboardingWindowController(permissionManager: permissionManager, registry: registry)
        selectionMonitor = SelectionMonitor()
        triggerIconController = TriggerIconController()
        // Apply dock visibility — always set explicitly because macOS may cache
        // .regular from a previous session, ignoring LSUIElement on relaunch.
        NSApp.setActivationPolicy(Defaults[.showInDock] ? .regular : .accessory)

        setupShortcuts()
        setupSelectionMonitor()

        // Show onboarding on first launch; returning users start silently as a menu bar app.
        if !Defaults[.hasCompletedOnboarding] {
            // Delay to let SwiftUI finish scene setup; async alone is insufficient.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.onboardingController.showWindow()
            }
        } else if !permissionManager.allPermissionsGranted {
            // Permissions lost after update — show a simplified recovery prompt.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.onboardingController.showPermissionRecovery()
            }
        }
        if !permissionManager.allPermissionsGranted {
            permissionManager.startPolling()
        }
    }

    // MARK: - URL Scheme Handler

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "transpeek", url.host == "translate" else { continue }
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let text = components.queryItems?.first(where: { $0.name == "text" })?.value,
                  !text.isEmpty
            else { continue }

            cancelSmartTranslation()
            coordinator.translate(text)
            if case .idle = coordinator.phase { continue }
            panelController.showAtCursor()
        }
    }

    // MARK: - Language Override

    private func applyLanguageOverride() {
        let language = Defaults[.appLanguage]
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    // MARK: - Migration

    private func migrateDefaults() {
        migrateV1ProviderSettings()
        migrateV2KeychainToDefaults()
        migrateV3RemovedProviders()
        migrateV5TargetToVietnamese()
        migrateV6TargetChineseToVietnamese()
    }

    /// V5: The old default target was Chinese (zh-Hans); the app is for Vietnamese
    /// users learning English, so Vietnamese (vi) is now the default and first
    /// favorite (Manh 2026-11-16). Users whose saved target is still the old
    /// Chinese default get it reset to Vietnamese once, and Vietnamese is moved
    /// to the front of the saved favorites so the picker lists it first.
    /// A user who explicitly picked Chinese keeps it in the list, just not first.
    private func migrateV5TargetToVietnamese() {
        let migrationKey = "hasMigratedTargetToVietnamese"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if Defaults[.targetLanguage] == "zh-Hans" {
            Defaults[.targetLanguage] = "vi"
        }
        var favorites = Defaults[.favoriteTargetLanguages]
        if let viIndex = favorites.firstIndex(of: "vi"), viIndex != 0 {
            favorites.remove(at: viIndex)
            favorites.insert("vi", at: 0)
            Defaults[.favoriteTargetLanguages] = favorites
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// V6: V5 only reset an exact "zh-Hans" value, so a saved "zh-Hant"
    /// (or a Chinese value picked after V5 ran) stayed Chinese — Manh
    /// still saw Chinese as the target on 2026-11-16. Reset ANY saved
    /// Chinese target (zh-Hans or zh-Hant) to Vietnamese once.
    private func migrateV6TargetChineseToVietnamese() {
        let migrationKey = "hasMigratedTargetChineseToVietnameseV6"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if Defaults[.targetLanguage].hasPrefix("zh") {
            Defaults[.targetLanguage] = "vi"
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// V1: Migrate old flat keys to namespaced provider keys.
    private func migrateV1ProviderSettings() {
        let migrationKey = "hasCompletedProviderMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // Migrate OpenAI settings to namespaced keys
        let oldBaseURL = Defaults.Key<String>("openAIBaseURL", default: "https://api.openai.com/v1")
        let oldModel = Defaults.Key<String>("openAIModel", default: "gpt-4o-mini")
        let oldPrompt = Defaults.Key<String>(
            "systemPromptTemplate",
            default: "Translate the following text to {targetLang}. Only output the translation, nothing else."
        )

        let newBaseURL = Defaults.Key<String>("provider_openai_baseURL", default: "https://api.openai.com/v1")
        let newModel = Defaults.Key<String>("provider_openai_model", default: "gpt-4o-mini")
        let newPrompt = Defaults.Key<String>(
            "provider_openai_systemPrompt",
            default: "Translate the following text to {targetLang}. Only output the translation, nothing else."
        )
        let newApiKey = Defaults.Key<String>("provider_openai_apiKey", default: "")

        // Only migrate if old keys have non-default values
        if UserDefaults.standard.object(forKey: "openAIBaseURL") != nil {
            Defaults[newBaseURL] = Defaults[oldBaseURL]
        }
        if UserDefaults.standard.object(forKey: "openAIModel") != nil {
            Defaults[newModel] = Defaults[oldModel]
        }
        if UserDefaults.standard.object(forKey: "systemPromptTemplate") != nil {
            Defaults[newPrompt] = Defaults[oldPrompt]
        }

        // Migrate Keychain API key directly to Defaults
        if let oldApiKey = KeychainHelper.load(key: "openai_api_key"), !oldApiKey.isEmpty {
            Defaults[newApiKey] = oldApiKey
        }

        // Migrate preferredService to enabledProviders
        if let preferred = UserDefaults.standard.string(forKey: "preferredService") {
            var enabled: Set<String> = []
            if preferred == "apple" {
                enabled = ["apple"]
            } else {
                enabled = ["openai"]
            }
            Defaults[.enabledProviders] = enabled
        }

        // Clean up old keys
        for oldKey in ["openAIBaseURL", "openAIModel", "systemPromptTemplate", "preferredService"] {
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
        KeychainHelper.delete(key: "openai_api_key")

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// V2: Migrate API keys from Keychain to Defaults for users who already completed V1 migration.
    private func migrateV2KeychainToDefaults() {
        let migrationKey = "hasCompletedKeychainToDefaultsMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let keychainKey = "provider.openai.apiKey"
        let defaultsKey = Defaults.Key<String>("provider_openai_apiKey", default: "")

        if let apiKey = KeychainHelper.load(key: keychainKey), !apiKey.isEmpty {
            Defaults[defaultsKey] = apiKey
            KeychainHelper.delete(key: keychainKey)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// V3: Remove provider IDs that no longer exist; fall back to default if none remain.
    private func migrateV3RemovedProviders() {
        let removedIDs: Set<String> = ["groq", "github-models"]
        var enabled = Defaults[.enabledProviders]
        let needsMigration = !enabled.isDisjoint(with: removedIDs)
        if needsMigration {
            enabled.subtract(removedIDs)
            if enabled.isEmpty {
                enabled = ["google"]
            }
            Defaults[.enabledProviders] = enabled
        }

        // Clean up orphaned Defaults keys for removed providers
        let suffixes = ["baseURL", "model", "systemPrompt", "apiKey"]
        for id in removedIDs {
            for suffix in suffixes {
                UserDefaults.standard.removeObject(forKey: "provider_\(id)_\(suffix)")
            }
        }
    }

    // MARK: - Shortcuts

    func performSmartTranslation() {
        let previousTask = smartTranslationTask
        previousTask?.cancel()

        let taskID = UUID()
        smartTranslationTaskID = taskID
        smartTranslationTask = Task { @MainActor [weak self] in
            // ClipboardGrabber restores the pasteboard during cancellation cleanup, so the next
            // invocation must not capture its snapshot until that cleanup has fully completed.
            if let previousTask {
                await previousTask.value
            }

            guard let self else { return }
            defer {
                if self.smartTranslationTaskID == taskID {
                    self.smartTranslationTask = nil
                    self.smartTranslationTaskID = nil
                }
            }

            guard !Task.isCancelled else { return }
            let result = await self.coordinator.translateSmart()
            guard !Task.isCancelled else { return }
            switch result {
            case .selection, .clipboard:
                self.panelController.showAtCursor()
            case .manualInput:
                self.panelController.showAtScreenCenter()
            case .cancelled:
                break
            }
        }
    }

    func cancelSmartTranslation() {
        smartTranslationTask?.cancel()
    }

    /// OCR to Clipboard: copy recognized text to the clipboard; confirm with a small toast.
    func performSilentOCR() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            guard !Task.isCancelled else { return }
            switch await self.coordinator.ocrToClipboard() {
            case .copied:
                self.copyToastController.show(message: String(localized: "Copied"))
            case .failed:
                self.panelController.showAtCursor()
            case .cancelled:
                break
            }
        }
    }

    /// OCR to Clipboard - Translated: OCR a screen region, translate it, and
    /// copy the translation to the clipboard; confirm with a small toast.
    /// No panel unless it fails.
    func performSilentOCRTranslated() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            guard !Task.isCancelled else { return }
            switch await self.coordinator.ocrToClipboardTranslated() {
            case .copied:
                self.copyToastController.show(message: String(localized: "Copied"))
            case .failed:
                self.panelController.showAtCursor()
            case .cancelled:
                break
            }
        }
    }

    /// Screenshot Copy: capture a screen region and copy the image to the clipboard; confirm with a small toast.
    func performScreenshotCopy() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            guard !Task.isCancelled else { return }
            switch await self.coordinator.screenshotCopy() {
            case .copied:
                self.copyToastController.show(message: String(localized: "Copied"))
            case .failed:
                self.panelController.showAtCursor()
            case .cancelled:
                break
            }
        }
    }

    /// Scan Barcodes/QR Codes: capture a screen region and detect codes. URLs open
    /// in the default browser; anything else is copied to the clipboard and toasted.
    func performScanBarcodes() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            guard !Task.isCancelled else { return }
            switch await self.coordinator.scanBarcodes() {
            case .opened:
                break
            case let .copied(payload):
                self.copyToastController.show(message: Self.barcodeToastPreview(payload))
            case .notFound:
                self.copyToastController.show(message: String(localized: "No barcode found"))
            case .failed:
                self.panelController.showAtCursor()
            case .cancelled:
                break
            }
        }
    }

    /// Short preview for the barcode toast: long payloads (e.g. vCards) are
    /// truncated so the toast stays short.
    private static func barcodeToastPreview(_ payload: String) -> String {
        let maxLength = 80
        guard payload.count > maxLength else { return payload }
        return String(payload.prefix(maxLength)) + "…"
    }

    /// Translate Selection: translate the currently selected text; show the
    /// panel at the cursor when there is something to show.
    func performTranslateSelection() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            let outcome = await self.coordinator.translateSelection()
            if outcome.shouldPresent {
                self.panelController.showAtCursor()
            }
        }
    }

    /// Fast Read (RSVP, Manh 2026-11-17): open the reading window with the
    /// selected text, falling back to the clipboard. When `text` is given
    /// (the panel's "Fast Read" button passes the text being translated)
    /// it is used directly, without re-grabbing the selection. Used by the
    /// global shortcut, the menubar item, and the panel button.
    func performFastRead(text: String? = nil) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            let sourceText: String?
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sourceText = text
            } else if let selected = await TextSelectionManager.grabSelectedText(),
                      !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sourceText = selected
            } else {
                sourceText = NSPasteboard.general.string(forType: .string)
            }
            guard let sourceText,
                  !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.rsvpWindowController.show(text: sourceText)
        }
    }

    /// OCR Screen Translate: OCR a screen region and translate it; show the
    /// panel at the cursor when there is something to show.
    func performOCRScreenTranslate() {
        cancelSmartTranslation()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.coordinator.ocrAndTranslate()
            if outcome.shouldPresent {
                self.panelController.showAtCursor()
            }
        }
    }

    /// Manual Translation: open the panel in input mode at the screen center.
    func performInputTranslation() {
        cancelSmartTranslation()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.coordinator.prepareInputMode()
            self.panelController.showAtScreenCenter()
        }
    }

    /// Translate Clipboard: translate the clipboard text; show the panel at
    /// the cursor.
    func performClipboardTranslation() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.cancelSmartTranslationAndWait()
            await self.coordinator.translateClipboard()
            self.panelController.showAtCursor()
        }
    }

    /// Run a shortcut by name — the single dispatch the "?" shortcuts panel
    /// (PopupView) calls from its Run buttons (Manh 2026-11-17). It runs
    /// exactly the same code as the physical hotkey, so the Run button and
    /// the keyboard shortcut can never drift apart: each case below is the
    /// same perform* method the hotkey registration calls.
    func performShortcut(_ name: KeyboardShortcuts.Name) {
        switch name {
        case .smartTranslation:
            performSmartTranslation()
        case .inputTranslation:
            performInputTranslation()
        case .ocrScreenshot:
            performOCRScreenTranslate()
        case .silentOCR:
            performSilentOCR()
        case .silentOCRTranslated:
            performSilentOCRTranslated()
        case .translateSelection:
            performTranslateSelection()
        case .clipboardTranslation:
            performClipboardTranslation()
        case .fastRead:
            performFastRead()
        case .screenshotCopy:
            performScreenshotCopy()
        case .scanBarcodes:
            performScanBarcodes()
        default:
            break
        }
    }

    @discardableResult
    func cancelSmartTranslationAndWait() async -> Bool {
        await SmartTranslationTaskCleanup.cancelAndWait(smartTranslationTask)
    }

    private func setupShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .smartTranslation) { [weak self] in
            self?.performSmartTranslation()
        }

        KeyboardShortcuts.onKeyUp(for: .translateSelection) { [weak self] in
            self?.performTranslateSelection()
        }

        KeyboardShortcuts.onKeyUp(for: .ocrScreenshot) { [weak self] in
            self?.performOCRScreenTranslate()
        }

        KeyboardShortcuts.onKeyUp(for: .silentOCR) { [weak self] in
            self?.performSilentOCR()
        }

        KeyboardShortcuts.onKeyUp(for: .screenshotCopy) { [weak self] in
            self?.performScreenshotCopy()
        }

        KeyboardShortcuts.onKeyUp(for: .scanBarcodes) { [weak self] in
            self?.performScanBarcodes()
        }

        KeyboardShortcuts.onKeyUp(for: .inputTranslation) { [weak self] in
            self?.performInputTranslation()
        }

        KeyboardShortcuts.onKeyUp(for: .clipboardTranslation) { [weak self] in
            self?.performClipboardTranslation()
        }

        KeyboardShortcuts.onKeyUp(for: .fastRead) { [weak self] in
            self?.performFastRead()
        }
    }

    // MARK: - Selection Monitor

    private func setupSelectionMonitor() {
        selectionMonitor.shouldSkipClipboardAccess = { [weak self] in
            self?.smartTranslationTask != nil
        }

        selectionMonitor.onTextSelected = { [weak self] text, point in
            guard let self, !self.panelController.isVisible else { return }
            self.triggerIconController.show(text: text, near: point)
        }

        selectionMonitor.onMouseDown = { [weak self] _ in
            guard let self, self.triggerIconController.isVisible else { return }
            self.triggerIconController.dismissSilently()
        }

        triggerIconController.onTranslateRequested = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                await self.cancelSmartTranslationAndWait()
                await self.coordinator.translateTriggeredSelection(text)
                if case .idle = self.coordinator.phase { return }
                self.panelController.showAtCursor()
            }
        }

        // Click-to-speak (TransPeek Phase 1): no panel, no translation.
        // No detection has run at icon time, so detect the text's language
        // now; "auto"/empty configured source falls back to English.
        triggerIconController.onSpeakRequested = { [weak self] text in
            guard let self else { return }
            self.ttsCoordinator.speak(text, language: Self.speakLanguage(for: text))
        }

        triggerIconController.onStopSpeakRequested = { [weak self] in
            guard let self else { return }
            self.ttsCoordinator.stop()
            self.triggerIconController.setSpeaking(false)
        }

        // Fast Read (RSVP, Manh 2026-11-17): open the reading window with
        // the selected text; no panel, no translation.
        triggerIconController.onReadRequested = { [weak self] text in
            guard let self else { return }
            self.rsvpWindowController.show(text: text)
        }

        triggerIconController.onOpenSettingsRequested = { [weak self] in
            guard let self else { return }
            self.settingsController.showWindow()
        }

        // Natural end of playback (finished or failed) clears the icon state.
        // Cancellation via stop() already clears it through onStopSpeakRequested.
        ttsCoordinator.onPlaybackEnded = { [weak self] in
            self?.triggerIconController.speakingDidStop()
        }

        triggerIconController.onDismissed = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
        }

        panelController.onDismiss = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
            if self?.triggerIconController.isVisible == true {
                self?.triggerIconController.dismiss()
            }
        }

        selectionMonitor.start()
    }

    /// Language for click-to-speak: detect the text itself first, then the
    /// configured source language when it names a real language. "auto" (or an
    /// empty value) cannot be spoken — AppleTTSProvider would resolve it to no
    /// voice and fall back to the system default — so default to English.
    private static func speakLanguage(for text: String) -> String {
        if let detected = LanguageDetector.detect(text), !detected.isEmpty {
            return detected
        }
        let configured = Defaults[.sourceLanguage]
        if !configured.isEmpty, configured != "auto" {
            return configured
        }
        return "en"
    }
}
