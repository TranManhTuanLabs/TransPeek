import AppKit
import Defaults
import KeyboardShortcuts
import UserNotifications

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
    /// Hover block detection (Manh 2026-11-21): shows the icon when the
    /// mouse hovers a block of text, without selecting first. A second
    /// trigger path alongside SelectionMonitor — same icon flow.
    var hoverTextDetector: HoverTextDetector!
    /// Step 2 continuous reading (Manh 2026-11-24): the chaining
    /// controller (reads one hovered block after another on the page)
    /// and its reading-indicator overlay (vertical line + sentence /
    /// block / word highlights over the page). Created here, wired to
    /// the speak indicator's Pause/Resume callbacks in setupSelectionMonitor.
    var continuousSpeakController: ContinuousSpeakController!
    var readingIndicatorOverlay: ReadingIndicatorOverlay!
    /// The separate speak indicator (Manh 2026-11-26): the floating ⏸/▶
    /// button that owns pause/resume for the on-page session. It is NOT
    /// the float icon — the icon keeps its own lifecycle and never shows
    /// playback state.
    var speakIndicatorController: SpeakIndicatorController!
    /// Alternative icon (Manh 2026-11-21): a fake float icon for text
    /// selected inside Fast Read. A separate path from the real float
    /// icon — it does not touch that logic; it only delegates hover
    /// (translate) and click (speak, its own TTS) through callbacks.
    var alternativeIconController: AlternativeIconController!
    /// Detects selections inside Fast Read surfaces for the alternative
    /// icon (Manh 2026-11-21): a local mouse-up monitor + an AX read,
    /// because the global SelectionMonitor only sees other apps.
    var readSelectionMonitor: ReadSelectionMonitor!
    lazy var copyToastController = CopyToastController()
    lazy var updaterController = UpdaterController()
    /// Fast Read (RSVP) window controller (Manh 2026-11-17).
    lazy var rsvpWindowController = RSVPWindowController()
    /// Focus timer + rest-eyes store (Manh 2026-11-20, focus timer +
    /// panel decor): one store for the app — the panel-left card, the
    /// panel-right reading view, and the Rest window all read it.
    lazy var focusTimerStore = FocusTimerStore()
    /// System notification for a pending break reminder (Manh
    /// 2026-11-20, 05:33) — held strongly, the notification center
    /// keeps its delegate weak.
    var reminderNotifier: ReminderNotifier!
    var settingsController: SettingsWindowController!
    private var smartTranslationTask: Task<Void, Never>?
    private var smartTranslationTaskID: UUID?

    func applicationDidFinishLaunching(_: Notification) {
        // Hover tooltips (.help) appear after the macOS default ~1 s;
        // 300 ms feels responsive without flashing on every mouse pass
        // (Manh 2026-11-20). `register` only sets a fallback default —
        // a value Manh set by hand for this app is still respected.
        // App-domain only: this writes into TransPeek's own defaults,
        // it does NOT touch the system-wide setting or other apps.
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 300])
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
            settingsController: settingsController,
            focusTimerStore: focusTimerStore
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
        // The panel's "Fast Read" button opens Fast Read with the text
        // being translated (Manh 2026-11-17) — at the location the user
        // picked in "Run FastRead in:" (panel right, Manh 2026-11-20,
        // 05:27). Only the window destination hides the translate panel
        // first (Manh 2026-11-17, spec §14.8) — otherwise the panel
        // would cover the screen while reading. (Reading inside panel
        // 3 does NOT hide the panel.)
        panelController.onFastRead = { [weak self] text in
            guard let self else { return }
            if Defaults[.fastReadRunLocation] == .newWindow {
                self.panelController.hidePanelTemporarily()
                // A panel read and a window read are the same text read
                // two ways — the window replaces the panel one (Manh
                // 2026-11-20). The user is still reading, just in the
                // window, so a pending reminder keeps waiting (Manh
                // 2026-11-20, 05:33).
                self.focusTimerStore.stopPanelReading(showPending: false)
            }
            self.performFastRead(text: text)
        }
        // The panel-right "FastRead Full Window" button (Manh
        // 2026-11-22): an explicit window read — it always opens the
        // Window Read, whatever "Run FastRead in:" says (the sibling of
        // the "FastRead Lite" button, which always reads in the panel).
        // Hide the translate panel first so it does not cover the
        // screen while reading, and stop any panel read (same text
        // read two ways — the window replaces the panel one).
        panelController.onReadInWindow = { [weak self] text in
            guard let self else { return }
            self.panelController.hidePanelTemporarily()
            self.focusTimerStore.stopPanelReading(showPending: false)
            self.rsvpWindowController.show(text: text)
        }
        // A focus / rest-eyes reminder with destination Right Panel
        // (Manh 2026-11-20): the store holds the request; bring the
        // panel forward and the panel switches to the Fast Read tab
        // and starts the read itself. The reminder starts a Read in
        // panel right, so the panel needs keyboard input at once
        // (Space play/pause) — opened through the shared Fast Read
        // opener (`showForFastRead`, Manh 2026-11-22), which always
        // opens keyed. A non-activating open would not route
        // keystrokes to the reader until the user clicked into the
        // panel first.
        focusTimerStore.onShowPanel = { [weak self] in
            self?.panelController.showForFastRead()
        }
        // A break reminder that fired while reading waits (Manh
        // 2026-11-20, 05:33): show it when the Fast Read window closes,
        // and let the store ask whether the window is open.
        rsvpWindowController.onClose = { [weak self] in
            // The alternative icon lives in the Read window — it goes
            // away with it (Manh 2026-11-21).
            self?.alternativeIconController.dismissSilently()
            self?.focusTimerStore.fastReadWindowClosed()
        }
        // The Window Read speaker button (Manh 2026-11-21) reads the
        // shared TTS coordinator — the window injects it into its
        // SwiftUI environment when its content is created.
        rsvpWindowController.ttsCoordinator = ttsCoordinator
        // The Rest window speaker button (Manh 2026-11-23): same shared
        // coordinator, forwarded through the focus timer store — the
        // Rest window owns its own controller inside the store.
        focusTimerStore.ttsCoordinator = ttsCoordinator
        focusTimerStore.isFastReadWindowOpen = { [weak self] in
            self?.rsvpWindowController.isVisible ?? false
        }
        // An on-page listen counts as reading too (Manh 2026-11-27,
        // 17:35): a reminder fired mid-listen used to run at once
        // (the chain was not "reading"), so the conflict notification
        // never appeared. A session is live while playing OR paused —
        // `ContinuousSpeakController.isActive` — and ends when the
        // indicator hides / the session stops. Set here (before the
        // controller exists below) because the closure is only called
        // at fire time, by which point the controller is live.
        focusTimerStore.isSpeakingOnPage = { [weak self] in
            self?.continuousSpeakController.isActive ?? false
        }
        // System notification for a pending reminder (Manh 2026-11-20,
        // 05:33): the notifier owns UserNotifications; the store only
        // asks for a notification, never touches the framework.
        let notifier = ReminderNotifier()
        notifier.onTakeBreakNow = { [weak self] in
            self?.focusTimerStore.takePendingBreakNow()
        }
        notifier.onSnooze = { [weak self] in
            self?.focusTimerStore.snoozePendingReminder()
        }
        reminderNotifier = notifier
        UNUserNotificationCenter.current().delegate = notifier
        focusTimerStore.onNotifyReminder = { [weak self] kind in
            self?.reminderNotifier.notify(kind: kind)
        }
        onboardingController = OnboardingWindowController(permissionManager: permissionManager, registry: registry)
        selectionMonitor = SelectionMonitor()
        triggerIconController = TriggerIconController()
        hoverTextDetector = HoverTextDetector()
        // Step 2 (Manh 2026-11-24): the overlay first, then the chaining
        // controller that drives it — both need the shared TTS
        // coordinator, which already exists by now. The chaining
        // controller drives the SEPARATE speak indicator (Manh
        // 2026-11-26), not the float icon — the icon never shows
        // playback state.
        readingIndicatorOverlay = ReadingIndicatorOverlay()
        speakIndicatorController = SpeakIndicatorController()
        continuousSpeakController = ContinuousSpeakController(
            ttsCoordinator: ttsCoordinator,
            indicator: speakIndicatorController,
            overlay: readingIndicatorOverlay
        )
        // A listen session ending shows a pending reminder (Manh
        // 2026-11-27, 19:38): "Nghe hết unit → reminder chờ tự hiện".
        // The store guards it (only when not reading and no other
        // speak started), so this is just the trigger.
        continuousSpeakController.onSessionEnded = { [weak self] in
            self?.focusTimerStore.listenSessionEnded()
        }
        setupAlternativeIcon()
        // Apply dock visibility — always set explicitly because macOS may cache
        // .regular from a previous session, ignoring LSUIElement on relaunch.
        NSApp.setActivationPolicy(Defaults[.showInDock] ? .regular : .accessory)

        setupShortcuts()
        setupSelectionMonitor()

        // Auto start focus (Manh 2026-11-20, 09:47): if the
        // "Auto start focus" toggle is ON, the focus timer starts on
        // its own at launch, as if the user pressed Start. Called
        // last — the store's reminder callbacks (onShowPanel,
        // onNotifyReminder, isFastReadWindowOpen, isSpeakingOnPage) are
        // all wired above,
        // so a reminder fired by this session routes correctly. The
        // store itself guards against double-starting.
        focusTimerStore.autoStartFocusIfEnabled()

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

    /// Show Fast Read at the user's chosen location (Manh 2026-11-20,
    /// 05:27 — the "Run FastRead in:" picker in panel right).
    /// "FastRead Full Window" opens the separate Window Read (default,
    /// the current behavior); "Right Panel" reads inside panel right —
    /// holds the request and the panel switches to the Fast Read tab,
    /// exactly like a reminder with destination Right Panel (PopupView
    /// consumes the request on appear if the panel was hidden, or on
    /// change if it was already visible). This is the single funnel:
    /// every Fast Read launch (panel button, float icon, menubar,
    /// shortcut) goes through here, so the setting is checked in
    /// exactly one place.
    private func showFastRead(text: String) {
        switch Defaults[.fastReadRunLocation] {
        case .newWindow:
            rsvpWindowController.show(text: text)
        case .rightPanel:
            focusTimerStore.panelRightRequest = PanelRightRequest(
                text: text,
                countdownSeconds: nil,
                // `kind: nil` (Manh 2026-11-20, CI #298 fix): a plain
                // read has no reminder kind — passed explicitly because
                // `PanelRightRequest.kind` has no default (a defaulted
                // `= nil` broke the reminder call site, CI #298).
                kind: nil
            )
            // Open through the shared Fast Read opener (Manh
            // 2026-11-22, `showForFastRead`): the Lite reader needs
            // keyboard input at once (Space play/pause) — a
            // non-activating open would not route keystrokes to it
            // until the user clicked into the panel first.
            panelController.showForFastRead()
        }
    }

    /// Fast Read (RSVP, Manh 2026-11-17): open Fast Read with the
    /// selected text, falling back to the clipboard — at the location
    /// the user picked in "Run FastRead in:" (via showFastRead).
    /// When `text` is given
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
            self.showFastRead(text: sourceText)
        }
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
    /// Capture actions hide the panel first (Manh 2026-11-17): the user is
    /// looking at the panel when they click Run, so it would cover the
    /// screen region to capture — exactly like the Capture OCR button's
    /// performPanelOCR does (hide, capture, show again with the result).
    /// Non-capture actions keep the panel visible to show the result.
    func performShortcut(_ name: KeyboardShortcuts.Name) {
        switch name {
        case .ocrScreenshot, .silentOCR, .silentOCRTranslated, .screenshotCopy, .scanBarcodes:
            panelController.hidePanelTemporarily()
        default:
            break
        }
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
        case .screenshotCopy:
            performScreenshotCopy()
        case .scanBarcodes:
            performScanBarcodes()
        case .fastRead:
            performFastRead()
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

        KeyboardShortcuts.onKeyUp(for: .fastRead) { [weak self] in
            self?.performFastRead()
        }

        KeyboardShortcuts.onKeyUp(for: .inputTranslation) { [weak self] in
            self?.performInputTranslation()
        }

        KeyboardShortcuts.onKeyUp(for: .clipboardTranslation) { [weak self] in
            self?.performClipboardTranslation()
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
            guard let self else { return }
            // A click may start a drag/selection — cancel any pending
            // hover hit-test and stop following, even when no icon is up.
            self.hoverTextDetector.cancelPendingHover()
            self.hoverTextDetector.stopFollowing()
            guard self.triggerIconController.isVisible else { return }
            self.triggerIconController.dismissSilently()
        }

        triggerIconController.onTranslateRequested = { [weak self] text in
            guard let self else { return }
            // The icon is gone and the panel opens — stop following the
            // hovered block (its poll must not outlive the icon).
            self.hoverTextDetector.stopFollowing()
            Task { @MainActor in
                await self.cancelSmartTranslationAndWait()
                await self.coordinator.translateTriggeredSelection(text)
                if case .idle = self.coordinator.phase { return }
                self.panelController.showAtCursor()
            }
        }

        // Click-to-speak (TransPeek Phase 1, speaker law Manh 2026-11-26):
        // no panel, no translation. No detection has run at icon time,
        // so detect the text's language now; "auto"/empty configured
        // source falls back to English.
        // Step 2 chaining (Manh 2026-11-24): when the icon is up for a
        // hovered block, Speak reads that block and chains to the next
        // blocks below it (continuous on-page reading); otherwise
        // (a selection, no hover block) it speaks once. Both go through
        // the chaining controller, so both get play/pause/resume (the
        // controller owns the player).
        // The click only STARTS the session: the separate speak
        // indicator takes this icon's frame (the place the user clicked
        // Speak) and the icon dismisses, so the two never overlap — a
        // new click starts a new session (the old one, with its
        // indicator, is replaced). The icon's own lifecycle is
        // untouched: it is simply gone, and a later hover/select shows
        // a new icon while the session keeps playing.
        triggerIconController.onSpeakRequested = { [weak self] text in
            guard let self else { return }
            // Read the frame BEFORE dismissing (dismiss clears it).
            let indicatorFrame = self.triggerIconController.currentFrame
            self.triggerIconController.dismissSilently()
            // Read the hovered block BEFORE stopFollowing: stopping
            // clears the detector's current block, so reading it after
            // would always miss and every hover speak would fall back
            // to a single speak with no overlay — the highlight vanished
            // when the separate-indicator split added the stop call
            // (Manh 2026-11-27: hover + Speak showed no highlight).
            let hoveredBlock = self.hoverTextDetector.currentBlockForReading
            // The icon is gone — stop following the hovered block (its
            // poll must not outlive the icon). The indicator never
            // follows the text; it stays where it appeared.
            self.hoverTextDetector.stopFollowing()
            if let block = hoveredBlock,
               block.text == text {
                self.continuousSpeakController.start(from: block, indicatorFrame: indicatorFrame)
            } else {
                self.continuousSpeakController.start(text: text, indicatorFrame: indicatorFrame)
            }
        }

        // The separate speak indicator (Manh 2026-11-26): its click
        // pauses/resumes the on-page session (the float icon never
        // toggles). When the indicator hides on its own (auto-hide while
        // paused) the session ends silently — once it is gone there is
        // no way to resume it.
        speakIndicatorController.onPauseRequested = { [weak self] in
            self?.continuousSpeakController.pause()
        }
        speakIndicatorController.onResumeRequested = { [weak self] in
            self?.continuousSpeakController.resume()
        }
        speakIndicatorController.onDismissed = { [weak self] in
            self?.continuousSpeakController.stop()
        }

        // Fast Read (RSVP, Manh 2026-11-17): open Fast Read with the
        // selected text; no panel, no translation. Goes through
        // showFastRead, so the "Run FastRead in:" setting applies here
        // too (Manh 2026-11-20, 05:27).
        triggerIconController.onReadRequested = { [weak self] text in
            guard let self else { return }
            // The Read window opens and the icon hides after its 2.5s
            // confirmation — stop following the hovered block now.
            self.hoverTextDetector.stopFollowing()
            self.showFastRead(text: text)
        }

        triggerIconController.onOpenSettingsRequested = { [weak self] in
            guard let self else { return }
            self.settingsController.showWindow()
        }

        triggerIconController.onDismissed = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
            // Same suppression for the hover path, so the mouse still
            // sitting over the same text does not re-summon the icon,
            // and the follow poll ends with the icon.
            self?.hoverTextDetector.suppressBriefly()
            self?.hoverTextDetector.stopFollowing()
            // The icon and the speak session are independent now (Manh
            // 2026-11-26: the separate indicator owns the session) — an
            // icon hiding never stops a session; only the indicator
            // hiding does (see its onDismissed above).
        }

        panelController.onDismiss = { [weak self] in
            self?.selectionMonitor.suppressBriefly()
            self?.hoverTextDetector.suppressBriefly()
            self?.hoverTextDetector.stopFollowing()
            if self?.triggerIconController.isVisible == true {
                self?.triggerIconController.dismiss()
            }
            // Dismissing the panel also ends a panel read (Manh
            // 2026-11-20): the reading view is gone, so the playback
            // task must not keep advancing slides invisibly.
            self?.focusTimerStore.stopPanelReading()
        }

        selectionMonitor.start()

        setupHoverTextDetector()
    }

    /// Hover block detection wiring (Manh 2026-11-21): a second trigger
    /// path for the float icon, alongside selection. The detector only
    /// finds the block; the icon, panel, Speak and Read flows are the
    /// normal ones — nothing about them changes.
    private func setupHoverTextDetector() {
        // No delivery while the icon or the panel is already up — a
        // hover must never yank another flow's icon.
        hoverTextDetector.shouldDetect = { [weak self] in
            guard let self else { return false }
            return !self.panelController.isVisible && !self.triggerIconController.isVisible
        }

        hoverTextDetector.onBlockHovered = { [weak self] text, point in
            guard let self else { return }
            // Compact icon for hover (Manh 2026-11-21): the hover icon
            // appears on every text block, so it is smaller than the
            // selection icon — less in the way of the mouse.
            self.triggerIconController.show(text: text, near: point, compact: true)
        }

        // The hovered block scrolled away or vanished — dismiss the
        // stale icon. The icon follows its normal lifecycle at all
        // times (Manh 2026-11-26: it never tracks a speak session) —
        // a session playing elsewhere is owned by the separate
        // indicator, so an icon hiding never stops it.
        hoverTextDetector.onHoverStale = { [weak self] in
            guard let self else { return }
            self.triggerIconController.dismissSilently()
        }

        hoverTextDetector.start()
    }

    /// Alternative icon (Manh 2026-11-21): wire the in-Read selection
    /// monitor and the fake float icon. A separate path from the real
    /// float icon — nothing here touches `TriggerIconController`.
    private func setupAlternativeIcon() {
        let iconController = AlternativeIconController()
        // Click → start a click-to-listen session (new speaker law,
        // Manh 2026-11-27): the same shared flow as the real float
        // icon — the chaining controller owns the session and the
        // SEPARATE speak indicator appears at the icon's frame. A new
        // click replaces the old session (one voice at a time);
        // pause/resume is the indicator's job.
        iconController.onSpeakRequested = { [weak self] text in
            guard let self else { return }
            // Read the frame BEFORE dismissing (dismiss clears it).
            let indicatorFrame = self.alternativeIconController.currentFrame
            self.alternativeIconController.dismissSilently()
            // A selection inside Read is a single speak (no hover
            // block, no chaining — the controller stops any running
            // session first, so this replaces it).
            self.continuousSpeakController.start(text: text, indicatorFrame: indicatorFrame)
        }
        // Hover → translate the selected word. Per surface (design doc
        // §5): Window Read opens the panel at the cursor (normal icon
        // flow); Lite only translates — the panel follows `sourceText`
        // to the center tab on its own, and calling showAtCursor here
        // would move the panel to the cursor.
        iconController.onTranslateRequested = { [weak self] text, surface in
            guard let self else { return }
            Task { @MainActor in
                await self.cancelSmartTranslationAndWait()
                await self.coordinator.translateTriggeredSelection(text)
                if case .idle = self.coordinator.phase { return }
                if surface == .windowRead {
                    self.panelController.showAtCursor()
                }
            }
        }
        self.alternativeIconController = iconController

        let monitor = ReadSelectionMonitor()
        // The icon only appears for selections inside a Fast Read
        // surface — never for the translate input or Settings.
        monitor.isInWindowRead = { [weak self] point in
            self?.rsvpWindowController.contains(point) ?? false
        }
        monitor.isInLiteRead = { [weak self] point in
            guard let self else { return false }
            return self.panelController.contains(point)
                && self.panelController.selectedTab == .fastRead
        }
        monitor.isInAlternativeIcon = { [weak self] point in
            self?.alternativeIconController.contains(point) ?? false
        }
        monitor.onSelectionFound = { [weak self] text, point, surface in
            self?.alternativeIconController.show(text: text, near: point, surface: surface)
        }
        monitor.onSelectionCleared = { [weak self] in
            self?.alternativeIconController.dismissSilently()
        }
        self.readSelectionMonitor = monitor
        monitor.start()
    }

    /// Language for click-to-speak: detect the text itself first, then the
    /// configured source language when it names a real language. "auto" (or an
    /// empty value) cannot be spoken — AppleTTSProvider would resolve it to no
    /// voice and fall back to the system default — so default to English.
    /// Internal (not private) since Manh 2026-11-21: the Fast Read view
    /// model reuses this one rule for its speaker button, so the two
    /// speak paths can never disagree on language.
    static func speakLanguage(for text: String) -> String {
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

