import AppKit
import Defaults

/// Central coordinator that orchestrates: text grabbing → language detection → multi-provider translation.
@MainActor
@Observable
final class TranslationCoordinator {
    /// Tells an action entry point whether it should present a new popup.
    enum ActionOutcome: Sendable, Equatable {
        case present
        case preserve

        var shouldPresent: Bool {
            self == .present
        }
    }

    /// Overall translation phase.
    enum Phase: Sendable {
        case idle
        case active
    }

    /// Per-provider translation state.
    enum ProviderState: Sendable, Equatable {
        case awaitingUser
        case waiting
        case translating
        case streaming(partial: String)
        case completed(text: String)
        case error(message: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var sourceText: String = ""
    /// Images captured with rich source text, keyed by placeholder id. Released with the request.
    private(set) var sourceAttachments: [String: SourceImageAttachment] = [:]
    private(set) var detectedLanguage: String?
    private(set) var targetLanguage: String = ""
    private(set) var providerStates: [String: ProviderState] = [:]
    /// Setting a non-nil error also auto-unpins, so an error never appears in a frozen pinned panel.
    private(set) var globalError: String? {
        didSet {
            if globalError != nil { isPinned = false }
        }
    }
    private(set) var detectionResult: DetectionResult?
    /// Snapshot of expanded provider slots for the current translation session.
    /// PopupView reads this instead of `registry.enabledSlots` to avoid recomputation during streaming.
    private(set) var activeSlots: [any TranslationProvider] = []
    /// Monotonically increasing counter; increments each time `translate()` is called.
    /// Used by PopupView to reset `expandedProviders` for subsequent translations.
    private(set) var translationGeneration: Int = 0
    private(set) var copiedProviderID: String?
    private(set) var copyFeedbackGeneration: Int = 0
    /// OCR-panel flow: recognized source text and its first completed translation.
    /// Shown in the float panel with separate [Copy gốc] / [Copy dịch] buttons.
    private(set) var ocrSourceText: String?
    private(set) var ocrTranslationText: String?
    /// Provider that produced `ocrTranslationText`, if any.
    private(set) var lastOCRTranslationProviderID: String?
    /// Outcome of the most recent copy-only OCR run, so the panel controller
    /// can show the "Đã copy" toast only on a real copy (not on cancel).
    private(set) var lastCopyOnlyOutcome: SilentOCROutcome?
    /// Single source of truth for popup pin state. PopupView toggles, PopupPanelController reads.
    var isPinned: Bool = false

    let registry: TranslationProviderRegistry
    private let permissionManager: any PermissionChecking
    private let grabSelection: @MainActor () async -> RichSourceDocument?
    private let captureOCR: @MainActor () async throws -> String
    private let resolveSmart: @MainActor () async -> SmartTranslationResult
    private let ocrPasteboard: NSPasteboard
    /// Invalidates capture actions that are still awaiting a result when a newer session starts.
    private var actionToken = 0
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var copyFeedbackTask: Task<Void, Never>?

    init(
        permissionManager: any PermissionChecking,
        registry: TranslationProviderRegistry,
        grabSelection: @escaping @MainActor () async -> RichSourceDocument? = TextSelectionManager.grabSelectedDocument,
        captureOCR: @escaping @MainActor () async throws -> String = ScreenCaptureOCR.captureAndRecognize,
        resolveSmart: @escaping @MainActor () async -> SmartTranslationResult = { await SmartTranslationResolver.resolve() },
        ocrPasteboard: NSPasteboard = .general
    ) {
        self.permissionManager = permissionManager
        self.registry = registry
        self.grabSelection = grabSelection
        self.captureOCR = captureOCR
        self.resolveSmart = resolveSmart
        self.ocrPasteboard = ocrPasteboard
    }

    // MARK: - Public Actions

    /// Triggered by the smart shortcut: selected content → invocation-time clipboard → manual input.
    /// Selection capture intentionally runs without an Accessibility permission gate so the
    /// clipboard and manual-input fallbacks remain available when that permission is missing.
    @discardableResult
    func translateSmart() async -> SmartTranslationResult {
        let requestToken = beginAction()
        let result = await resolveSmart()
        guard !Task.isCancelled, requestToken == actionToken else { return .cancelled }

        switch result {
        case let .selection(document), let .clipboard(document):
            translate(document: document)
        case .manualInput:
            prepareInputMode()
        case .cancelled:
            break
        }
        return result
    }

    /// Triggered by keyboard shortcut: grab selected text → translate.
    @discardableResult
    func translateSelection() async -> ActionOutcome {
        let requestToken = beginAction()
        guard permissionManager.isAccessibilityGranted else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Accessibility permission not granted. Open Settings to enable it.")
            return .present
        }

        guard let document = await grabSelection(),
              !document.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !Task.isCancelled,
              requestToken == actionToken
        else {
            return .preserve
        }

        translate(document: document)
        return .present
    }

    /// Triggered by the floating icon, which already holds the plain selection. With rich
    /// capture on, re-copy the still-active selection to pick up formatting and images.
    func translateTriggeredSelection(_ text: String) async {
        if TextSelectionManager.isRichCaptureEnabled,
           let document = await ClipboardGrabber.grabRichViaClipboard() {
            translate(document: document)
        } else {
            translate(text)
        }
    }

    /// Triggered by OCR shortcut: screen capture → OCR → translate.
    @discardableResult
    func ocrAndTranslate() async -> ActionOutcome {
        let requestToken = beginAction()
        guard permissionManager.isScreenRecordingGranted else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Screen recording permission not granted. Open Settings to enable it.")
            return .present
        }

        do {
            let text = try await captureOCR()
            guard !Task.isCancelled, requestToken == actionToken else {
                return .preserve
            }
            translate(text)
            return .present
        } catch OCRError.captureCancelled {
            return .preserve
        } catch is CancellationError {
            return .preserve
        } catch {
            guard requestToken == actionToken else { return .preserve }
            phase = .active
            sourceText = ""
            globalError = String(localized: "OCR failed: \(error.localizedDescription)")
            return .present
        }
    }

    /// How a silent-OCR attempt ended: toast on success, panel on failure, nothing on cancel.
    enum SilentOCROutcome: Sendable, Equatable {
        case copied
        case cancelled
        case failed
    }

    /// Triggered by the silent-OCR shortcut: screen capture → OCR → clipboard. No popup.
    /// Success stays silent apart from the caller's toast; failures surface the panel with
    /// the error so a dead-looking shortcut is never left unexplained.
    @discardableResult
    func ocrToClipboard() async -> SilentOCROutcome {
        let requestToken = beginAction()
        guard permissionManager.isScreenRecordingGranted else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Screen recording permission not granted. Open Settings to enable it.")
            return .failed
        }

        do {
            let text = try await captureOCR()
            guard !Task.isCancelled, requestToken == actionToken else {
                return .cancelled
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .cancelled }
            return await ClipboardGrabber.withStableAccess(to: ocrPasteboard) { pasteboard -> SilentOCROutcome? in
                // A pending restoration may finish after this action is cancelled or superseded.
                guard !Task.isCancelled, requestToken == self.actionToken else { return .cancelled }
                pasteboard.clearContents()
                guard pasteboard.setString(trimmed, forType: .string) else { return .cancelled }
                return .copied
            } ?? .cancelled
        } catch OCRError.captureCancelled {
            return .cancelled
        } catch is CancellationError {
            return .cancelled
        } catch {
            guard requestToken == actionToken else { return .cancelled }
            phase = .active
            sourceText = ""
            globalError = String(localized: "OCR failed: \(error.localizedDescription)")
            return .failed
        }
    }

    /// How a screenshot-copy attempt ended: toast on success, panel on failure, nothing on cancel.
    enum ScreenshotCopyOutcome: Sendable, Equatable {
        case copied
        case cancelled
        case failed
    }

    /// Triggered by the screenshot-copy action: screen capture → image straight
    /// to the clipboard via `screencapture -i -c`. No OCR, no popup.
    /// Success stays silent apart from the caller's toast; failures surface the
    /// panel with the error so a dead-looking shortcut is never left unexplained.
    @discardableResult
    func screenshotCopy() async -> ScreenshotCopyOutcome {
        let requestToken = beginAction()
        guard permissionManager.isScreenRecordingGranted else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Screen recording permission not granted. Open Settings to enable it.")
            return .failed
        }

        do {
            try await ScreenCaptureOCR.captureImageToClipboard()
            guard !Task.isCancelled, requestToken == actionToken else {
                return .cancelled
            }
            return .copied
        } catch OCRError.captureCancelled {
            return .cancelled
        } catch is CancellationError {
            return .cancelled
        } catch {
            guard requestToken == actionToken else { return .cancelled }
            phase = .active
            sourceText = ""
            globalError = String(localized: "Screenshot copy failed: \(error.localizedDescription)")
            return .failed
        }
    }

    /// How a barcode/QR scan ended: nothing extra on open (the browser opened),
    /// toast on copy / not-found, panel on failure, nothing on cancel.
    enum BarcodeScanOutcome: Sendable, Equatable {
        case opened(URL)
        case copied(String)
        case notFound
        case cancelled
        case failed
    }

    /// Triggered by the scan-barcodes action: screen capture → Vision barcode
    /// detection. A URL payload opens in the default browser automatically
    /// (like OwlOCR); any other payload is copied to the clipboard for the
    /// caller to toast — phone numbers, bank account numbers, plain text,
    /// Wi-Fi strings and vCards are never auto-opened.
    @discardableResult
    func scanBarcodes() async -> BarcodeScanOutcome {
        let requestToken = beginAction()
        guard permissionManager.isScreenRecordingGranted else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Screen recording permission not granted. Open Settings to enable it.")
            return .failed
        }

        do {
            let image = try await ScreenCaptureOCR.captureImage()
            guard !Task.isCancelled, requestToken == actionToken else {
                return .cancelled
            }
            let payloads = try await BarcodeScanner.detectPayloads(in: image)
            guard !Task.isCancelled, requestToken == actionToken else {
                return .cancelled
            }
            guard let payload = payloads.first else { return .notFound }
            if let url = URL(string: payload),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
                return .opened(url)
            }
            let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .notFound }
            return await ClipboardGrabber.withStableAccess(to: ocrPasteboard) { pasteboard -> BarcodeScanOutcome? in
                // A pending restoration may finish after this action is cancelled or superseded.
                guard !Task.isCancelled, requestToken == self.actionToken else { return .cancelled }
                pasteboard.clearContents()
                guard pasteboard.setString(trimmed, forType: .string) else { return .cancelled }
                return .copied(trimmed)
            } ?? .cancelled
        } catch OCRError.captureCancelled {
            return .cancelled
        } catch is CancellationError {
            return .cancelled
        } catch {
            guard requestToken == actionToken else { return .cancelled }
            phase = .active
            sourceText = ""
            globalError = String(localized: "Barcode scan failed: \(error.localizedDescription)")
            return .failed
        }
    }

    /// Triggered by the OCR entry point that respects the user's post-OCR mode
    /// (`Defaults[.ocrPostMode]`): panel translation with optional auto-copy, or
    /// copy-only. Existing `ocrAndTranslate()` / `ocrToClipboard()` stay untouched
    /// for the ⌥S shortcuts.
    @discardableResult
    func ocrAndTranslateWithMode() async -> ActionOutcome {
        switch Defaults[.ocrPostMode] {
        case .copyOnly:
            // Same behaviour as ocrToClipboard(); the caller shows the "Đã copy" toast.
            let silentOutcome = await ocrToClipboard()
            lastCopyOnlyOutcome = silentOutcome
            switch silentOutcome {
            case .copied, .cancelled:
                return .preserve
            case .failed:
                return .present
            }
        case .panel:
            let requestToken = beginAction()
            guard permissionManager.isScreenRecordingGranted else {
                phase = .active
                sourceText = ""
                globalError = String(localized: "Screen recording permission not granted. Open Settings to enable it.")
                return .present
            }

            do {
                let text = try await captureOCR()
                guard !Task.isCancelled, requestToken == actionToken else {
                    return .preserve
                }
                translate(text)
                ocrSourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // startTranslation() bumps actionToken; capture the post-translation
                // token so the wait loop below is not invalidated by our own call.
                let sessionToken = actionToken

                // Wait for translation to finish (up to ~30s), then snapshot the
                // first completed result for the panel's [Copy dịch] button.
                let deadline = Date.now.addingTimeInterval(30)
                while !allFinished, Date.now < deadline {
                    try? await Task.sleep(for: .milliseconds(200))
                    try Task.checkCancellation()
                    guard sessionToken == actionToken else { return .preserve }
                }

                if let translation = firstCompletedTranslation() {
                    ocrTranslationText = translation
                    lastOCRTranslationProviderID = firstCompletedTranslationProviderID()
                    if Defaults[.ocrAutoCopyTranslation] {
                        NSPasteboard.general.clearContents()
                        _ = NSPasteboard.general.setString(translation, forType: .string)
                    }
                }
                return .present
            } catch OCRError.captureCancelled {
                return .preserve
            } catch is CancellationError {
                return .preserve
            } catch {
                guard requestToken == actionToken else { return .preserve }
                phase = .active
                sourceText = ""
                globalError = String(localized: "OCR failed: \(error.localizedDescription)")
                return .present
            }
        }
    }

    /// First completed provider result in `activeSlots` order, with attachment
    /// placeholders stripped. Returns `nil` when no provider has completed with
    /// non-empty text yet.
    func firstCompletedTranslation() -> String? {
        firstCompletedResult()?.text
    }

    /// Provider ID behind `firstCompletedTranslation()`, if any.
    private func firstCompletedTranslationProviderID() -> String? {
        firstCompletedResult()?.providerID
    }

    private func firstCompletedResult() -> (providerID: String, text: String)? {
        for provider in activeSlots {
            guard case let .completed(text) = providerStates[provider.id] else { continue }
            let cleaned = MarkdownSupport.removingAttachmentPlaceholders(text)
            guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            return (provider.id, cleaned)
        }
        return nil
    }

    /// Copy the OCR source text (backs the panel's [Copy gốc] button).
    @discardableResult
    func copyOCRSource() -> Bool {
        guard let text = ocrSourceText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copy the OCR translation (backs the panel's [Copy dịch] button).
    @discardableResult
    func copyOCRTranslation() -> Bool {
        guard let text = ocrTranslationText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    /// Read clipboard text and translate directly.
    func translateClipboard() async {
        if Defaults[.captureRichText],
           let payload = RichTextImporter.payload(from: NSPasteboard.general),
           let document = await RichTextImporter.document(from: payload) {
            translate(document: document)
            return
        }
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Clipboard is empty. Copy some text first.")
            return
        }
        translate(text)
    }

    /// Reset state and enter input mode (empty source input for manual typing).
    func prepareInputMode() {
        invalidatePendingAction()
        cancelAll()
        clearCopyFeedback()
        globalError = nil
        sourceText = ""
        sourceAttachments = [:]
        detectedLanguage = nil
        targetLanguage = SupportedLanguages.resolvedTarget(
            Defaults[.targetLanguage],
            favoriteCodes: Defaults[.favoriteTargetLanguages]
        )
        providerStates = [:]
        detectionResult = nil
        activeSlots = []
        phase = .active
    }

    /// Translate text with all enabled providers in parallel.
    /// Launches provider tasks in the background and returns immediately.
    /// Attachments from the current session survive as long as the text still references them.
    func translate(_ text: String) {
        startTranslation(
            text,
            attachments: SourceAttachmentReference.retainedAttachments(sourceAttachments, referencedIn: text)
        )
    }

    func translate(document: RichSourceDocument) {
        startTranslation(document.markdown, attachments: document.attachments)
    }

    private func startTranslation(_ text: String, attachments: [String: SourceImageAttachment]) {
        invalidatePendingAction()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .active
            sourceText = ""
            globalError = String(localized: "Empty text")
            return
        }

        cancelAll()
        clearCopyFeedback()
        globalError = nil

        sourceText = trimmed
        sourceAttachments = attachments
        ocrSourceText = nil
        ocrTranslationText = nil
        lastOCRTranslationProviderID = nil

        // Language detection: check sourceLanguage setting
        let forcedSource = Defaults[.sourceLanguage]

        if forcedSource != "auto" {
            // User specified a source language in the panel or settings
            detectedLanguage = forcedSource
            detectionResult = nil
        } else {
            // Auto-detect with configurable threshold and hints
            let threshold = Defaults[.detectionConfidenceThreshold]
            let hints = buildLanguageHints()
            let result = LanguageDetector.detectWithConfidence(
                trimmed, threshold: threshold, preferredSourceHints: hints
            )
            detectionResult = result
            detectedLanguage = result.language
        }

        targetLanguage = resolveTargetLanguage(detected: detectedLanguage)
        phase = .active

        let providers = registry.orderedSlots(
            primaryID: Defaults[.primaryProviderID],
            fallbackID: Defaults[.fallbackProviderID]
        )
        activeSlots = providers
        translationGeneration += 1
        guard !providers.isEmpty else {
            globalError = String(localized: "No providers enabled. Enable at least one in Settings.")
            return
        }

        // Initialize every enabled slot, but only launch providers configured for automatic translation.
        providerStates = [:]
        for provider in providers {
            providerStates[provider.id] = registry.translatesAutomatically(provider) ? .waiting : .awaitingUser
        }

        for provider in providers where registry.translatesAutomatically(provider) {
            launchProvider(provider, text: trimmed, from: detectedLanguage, to: targetLanguage)
        }
    }

    /// Start an enabled provider that was left idle for on-demand translation.
    func translateProvider(_ provider: any TranslationProvider) {
        guard phase == .active,
              !sourceText.isEmpty,
              activeSlots.contains(where: { $0.id == provider.id }),
              providerStates[provider.id] == .awaitingUser
        else { return }

        providerStates[provider.id] = .waiting
        launchProvider(provider, text: sourceText, from: detectedLanguage, to: targetLanguage)
    }

    /// Retry a single provider that previously errored.
    func retryProvider(_ provider: any TranslationProvider) {
        guard phase == .active,
              !sourceText.isEmpty,
              providerStates[provider.id]?.isError == true
        else { return }
        activeTasks[provider.id]?.cancel()
        providerStates[provider.id] = .waiting
        launchProvider(provider, text: sourceText, from: detectedLanguage, to: targetLanguage)
    }

    @discardableResult
    func copyResult(atDisplayIndex index: Int) -> Bool {
        guard activeSlots.indices.contains(index) else { return false }
        return copyResult(forProviderID: activeSlots[index].id)
    }

    @discardableResult
    func copyResult(forProviderID providerID: String) -> Bool {
        guard let rawText = providerStates[providerID]?.copyableText else { return false }
        let resultText = MarkdownSupport.removingAttachmentPlaceholders(rawText)
        guard !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(resultText, forType: .string) else { return false }
        showCopyFeedback(forProviderID: providerID)
        return true
    }

    func dismiss() {
        invalidatePendingAction()
        cancelAll()
        clearCopyFeedback()
        phase = .idle
        sourceText = ""
        sourceAttachments = [:]
        ocrSourceText = nil
        ocrTranslationText = nil
        lastOCRTranslationProviderID = nil
        detectedLanguage = nil
        targetLanguage = ""
        providerStates = [:]
        globalError = nil
        detectionResult = nil
        activeSlots = []
        isPinned = false
    }

    // MARK: - Computed Helpers

    /// Whether any provider has completed with a result.
    var hasAnyResult: Bool {
        providerStates.values.contains { state in
            if case .completed = state { return true }
            return false
        }
    }

    /// Whether no provider has active translation work, including untouched on-demand providers.
    var allFinished: Bool {
        guard !providerStates.isEmpty else { return true }
        return providerStates.values.allSatisfy { state in
            switch state {
            case .awaitingUser, .completed, .error: return true
            default: return false
            }
        }
    }

    // MARK: - Private

    private func beginAction() -> Int {
        actionToken &+= 1
        return actionToken
    }

    private func invalidatePendingAction() {
        actionToken &+= 1
    }

    /// Markdown sources go to LLM providers verbatim with a preserve-formatting instruction;
    /// machine translation APIs get plain text because they cannot honor either.
    private func launchProvider(
        _ provider: any TranslationProvider,
        text: String,
        from sourceLang: String?,
        to targetLang: String
    ) {
        let isMarkdown = MarkdownSupport.looksLikeMarkdown(text)
        let sendsMarkdown = isMarkdown && provider.acceptsMarkdownInput
        let providerText = (isMarkdown && !provider.acceptsMarkdownInput) ? MarkdownSupport.plainText(from: text) : text
        guard !providerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            providerStates[provider.id] = .error(message: String(localized: "Nothing to translate after removing images."))
            return
        }
        let generation = translationGeneration
        let task = Task {
            await TranslationRequestContext.$sourceIsMarkdown.withValue(sendsMarkdown) {
                await runProvider(
                    provider,
                    text: providerText,
                    from: sourceLang,
                    to: targetLang,
                    generation: generation
                )
            }
        }
        activeTasks[provider.id] = task
    }

    private func runProvider(
        _ provider: any TranslationProvider,
        text: String,
        from sourceLang: String?,
        to targetLang: String,
        generation: Int
    ) async {
        defer {
            // Only clean up if not cancelled: when retryProvider() replaces a task,
            // the cancelled old task must not remove the new task's dictionary entry.
            if !Task.isCancelled {
                activeTasks.removeValue(forKey: provider.id)
            }
        }
        guard !Task.isCancelled, generation == translationGeneration else { return }
        providerStates[provider.id] = .translating

        do {
            var accumulated = ""
            for try await chunk in provider.translateStream(text, from: sourceLang, to: targetLang) {
                guard !Task.isCancelled, generation == translationGeneration else { return }
                accumulated += chunk
                providerStates[provider.id] = .streaming(partial: accumulated)
            }

            guard !Task.isCancelled, generation == translationGeneration else { return }

            if accumulated.isEmpty {
                providerStates[provider.id] = .error(message: String(localized: "Translation returned empty result"))
            } else {
                providerStates[provider.id] = .completed(text: accumulated)
            }
        } catch {
            guard !Task.isCancelled, generation == translationGeneration else { return }
            providerStates[provider.id] = .error(message: error.localizedDescription)
        }
    }

    private func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    private func showCopyFeedback(forProviderID providerID: String) {
        copyFeedbackTask?.cancel()
        copiedProviderID = providerID
        copyFeedbackGeneration += 1

        copyFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            guard self?.copiedProviderID == providerID else { return }
            self?.copiedProviderID = nil
            self?.copyFeedbackTask = nil
        }
    }

    private func clearCopyFeedback() {
        copyFeedbackTask?.cancel()
        copyFeedbackTask = nil
        copiedProviderID = nil
    }

    /// Build language hints (BCP 47 codes) based on user's target/source language preferences.
    /// Likely source languages are inferred from the target language for common translation pairs.
    private func buildLanguageHints() -> [String: Double]? {
        let target = SupportedLanguages.resolvedTarget(
            Defaults[.targetLanguage],
            favoriteCodes: Defaults[.favoriteTargetLanguages]
        )
        let source = Defaults[.sourceLanguage]

        var hints: [String: Double] = [:]

        // If user specified a preferred source language, give it a boost
        if source != "auto" {
            hints[source] = 0.5
        }

        // Infer likely source languages from target language
        switch target {
        case let t where t.hasPrefix("zh"):
            hints["en", default: 0] += 0.2
            hints["ja", default: 0] += 0.1
            hints["ko", default: 0] += 0.05
        case "en":
            hints["zh-Hans", default: 0] += 0.2
            hints["ja", default: 0] += 0.1
            hints["ko", default: 0] += 0.05
            hints["fr", default: 0] += 0.05
            hints["de", default: 0] += 0.05
            hints["es", default: 0] += 0.05
        case "ja":
            hints["en", default: 0] += 0.2
            hints["zh-Hans", default: 0] += 0.1
        case "ko":
            hints["en", default: 0] += 0.2
            hints["zh-Hans", default: 0] += 0.1
            hints["ja", default: 0] += 0.05
        case "fr", "de", "es", "it", "pt-BR", "pl", "nl", "tr", "uk", "id", "sv":
            hints["en", default: 0] += 0.2
            hints["fr", default: 0] += 0.05
            hints["de", default: 0] += 0.05
            hints["es", default: 0] += 0.05
            hints["it", default: 0] += 0.05
            hints["pt-BR", default: 0] += 0.05
        case "ru":
            hints["en", default: 0] += 0.2
        case "ar":
            hints["en", default: 0] += 0.2
        default:
            break
        }

        // Don't hint the target language itself as a source
        hints.removeValue(forKey: target)

        return hints.isEmpty ? nil : hints
    }

    private func resolveTargetLanguage(detected: String?) -> String {
        SupportedLanguages.resolvedTarget(
            Defaults[.targetLanguage],
            detectedLanguage: detected,
            favoriteCodes: Defaults[.favoriteTargetLanguages]
        )
    }
}

private extension TranslationCoordinator.ProviderState {
    var copyableText: String? {
        switch self {
        case let .streaming(partial):
            partial
        case let .completed(text):
            text
        case .awaitingUser, .waiting, .translating, .error:
            nil
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
