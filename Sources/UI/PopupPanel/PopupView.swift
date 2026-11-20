import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// The three panels of the multi-tab frame (Manh 2026-11-17, hub layout).
/// Official names (Manh 2026-11-18 — use these, not numbers, to avoid
/// confusion): panel left = shortcuts (temporary), panel center = dịch
/// (SETTLED, the default), panel right = Fast Read (temporary,
/// placeholder until Fast Read ships). In casual speech the panels may
/// be called panel 1/2/3 (left/center/right). The enum order is left →
/// right, so rawValue is the dot index — the cases are named by feature,
/// not by number, because the numbers may map to different features
/// later (Manh 2026-11-17 12:24).
private enum PanelTab: Int, CaseIterable {
    case shortcut = 0
    case translate = 1
    case fastRead = 2
}

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator
    /// Tracks the language picker's popover window so the dismiss monitor
    /// treats clicks in it as clicks inside the panel (Manh 2026-11-19,
    /// 0.1.5). Created by the PopupPanelController, shared with the monitor.
    let languagePopoverTracker: LanguagePopoverTracker
    /// Focus timer store (Manh 2026-11-20, focus timer + panel decor):
    /// one store for the app (created by AppDelegate, passed through
    /// the panel controller) — the panel-left card, the panel-right
    /// reading view, and the Rest window all read the same state.
    let focusTimerStore: FocusTimerStore
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOCRRequested: (() -> Void)?
    /// Called when a Run button in the "?" shortcuts panel is clicked:
    /// runs the named shortcut through AppDelegate.performShortcut, the
    /// same dispatch the physical hotkeys use (Manh 2026-11-17).
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?
    /// Called when the "Fast Read" button in the Actions row is clicked:
    /// opens the RSVP reading window with the text being translated
    /// (Manh 2026-11-17).
    var onFastRead: ((String) -> Void)?
    /// Whether the "?" shortcuts table (embedded at the top of the
    /// output box, Manh 2026-11-17) is shown. It is a plain section, not
    /// a popover and not a provider card.
    @State private var showingShortcuts = false
    /// Whether the "How the icon works" intro card (above the shortcuts
    /// table, Manh 2026-11-18) is collapsed. Remembered in Defaults, so
    /// once the reader knows the flow they can keep it collapsed and the
    /// shortcuts table is the main thing on show.
    @State private var isFlowIntroCollapsed: Bool = Defaults[.flowIntroCollapsed]
    /// Whether the "Keyboard Shortcuts" card in panel left is collapsed
    /// (Manh 2026-11-18, round 9). Same pattern as the flow card above:
    /// remembered in Defaults, so both cards can stay collapsed and
    /// leave room for the future focus/tomato timer in panel left.
    @State private var isShortcutsCollapsed: Bool = Defaults[.shortcutsCollapsed]
    /// Whether the "Focus & Rest" card in panel left is collapsed
    /// (Manh 2026-11-20, focus timer + panel decor). Same pattern as
    /// the flow / shortcuts cards: remembered in Defaults.
    @State private var isFocusTimerCollapsed: Bool = Defaults[.focusTimerCollapsed]
    /// Which panel of the multi-tab frame is showing (Manh 2026-11-17).
    /// Panel dịch (middle) is the default; a new translation always
    /// returns here (see the sourceText onChange below).
    @State private var selectedTab: PanelTab = .translate
    @State private var editableText: String = ""
    /// Text the dictionary links look up (SPEC §3.2): the text selected
    /// inside the source editor or a translation result when there is one,
    /// otherwise `nil` and the bar falls back to the source text that
    /// opened the panel.
    @State private var lookupText: String? = nil
    @State private var expandedProviders: Set<String> = []
    @State private var autoPlayedGeneration: Int = -1
    @Environment(\.ttsCoordinator) private var ttsCoordinator
    @Environment(\.popupPanel) private var panel
    /// Two-finger trackpad swipe → tab switch (Manh 2026-11-17). The dots
    /// row's DragGesture only sees mouse drags; a 2-finger swipe arrives
    /// as scroll-wheel events, so it needs this monitor (see
    /// TrackpadSwipeMonitor.swift). The swipe works anywhere over the
    /// panel — a trackpad swipe is a scroll event, not a mouse drag, so it
    /// never steals text selection, and vertical swipes pass through to
    /// the results ScrollView untouched.
    @StateObject private var trackpadSwipeMonitor = TrackpadSwipeMonitor()
    @State private var sourceLang: String = Defaults[.sourceLanguage]
    @State private var targetLang: String = SupportedLanguages.resolvedTarget(
        Defaults[.targetLanguage],
        favoriteCodes: Defaults[.favoriteTargetLanguages]
    )
    @State private var inputHeight: CGFloat = CGFloat(Defaults[.popupInputHeight])
    @State private var resultLayout = PopupResultLayout()
    var onResultLayoutChange: ((PopupResultLayout) -> Void)?
    @Default(.popupFontSize) private var fontSize
    @Default(.popupTopBarFontSize) private var topBarFontSize
    @Default(.popupFontName) private var fontName

    private let inputMinHeight: CGFloat = 36
    private let contentHorizontalPadding: CGFloat = 14

    private var inputSixLineHeight: CGFloat {
        let editorLineHeight = NSFont.popup(name: fontName, size: CGFloat(fontSize)).lineHeight
        let hintLineHeight = NSFont.popup(name: fontName, size: max(CGFloat(fontSize - 4), 8)).lineHeight
        return ceil(editorLineHeight * 6 + hintLineHeight + 8)
    }

    private var maxInputHeight: CGFloat {
        // Reserve 120pt for language bar + results, while capping the editor at six visible lines.
        let containerHeight = resultLayout.containerHeight ?? CGFloat(Defaults[.popupDefaultHeight])
        let availableHeight = max(containerHeight - 120, inputMinHeight)
        return max(inputMinHeight, min(inputSixLineHeight, availableHeight))
    }

    /// Cap for each result card's text area (Manh 2026-11-17): the text
    /// scrolls inside the card past this height, so the card's speaker/Copy
    /// row stays visible without scrolling the panel (Windows parity).
    /// Normally the auto-fit cap (260); grows with the panel viewport when
    /// the user drags taller, so the text area expands instead of leaving
    /// empty space below the card (Windows raises its cap the same way).
    /// The card's non-text chrome is subtracted so the whole card fits the
    /// viewport; the frameToFit cap (260 + chrome) matches.
    private var resultTextCap: CGFloat {
        let viewport = resultLayout.viewportHeight ?? PopupPanelSizing.autoFitOutputCap
        return max(
            PopupPanelSizing.autoFitOutputCap,
            viewport - PopupPanelSizing.resultCardChrome
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch coordinator.phase {
            case .idle:
                EmptyView()

            case .active:
                activeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: PopupResultLayoutPreferenceKey.self,
                        value: PopupResultLayout(containerHeight: geo.size.height)
                    )
            }
        )
        .onPreferenceChange(PopupResultLayoutPreferenceKey.self) { layout in
            resultLayout = layout
            clampInputHeightToAllowedRange()
            onResultLayoutChange?(layout)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // Resize handles sit AFTER the clip on purpose: the rounded corner
        // (radius 12) would otherwise clip away the grip's outer corner, so
        // hovering the corner from OUTSIDE the panel (below) never hit the
        // grip — the cursor only changed when coming from inside. The grip's
        // 3 lines are drawn inset from the corner, so they stay inside the
        // rounded rect; only the (invisible) hit area extends to the tip.
        .overlay(alignment: .trailing) { rightEdgeResizeHandle }
        .overlay(alignment: .bottom) { bottomEdgeResizeHandle }
        .overlay(alignment: .bottomTrailing) {
            ResizeGripView(
                translationGeneration: coordinator.translationGeneration,
                resultLayout: resultLayout,
                onResizeEnd: reportResultLayout
            )
        }
        .onChange(of: coordinator.sourceText) { _, newValue in
            editableText = newValue
            // A new source text means a new lookup: forget any in-panel
            // selection from the previous text (SPEC §3.2).
            lookupText = nil
            // A new translation always opens on panel dịch (the middle,
            // default tab) — the user is here to see the translation, not
            // whichever tab they left the panel on (Manh 2026-11-17).
            selectedTab = .translate
            if Defaults[.ttsAutoPlaySource],
               !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let tts = ttsCoordinator
            {
                let lang = coordinator.detectedLanguage ?? Defaults[.sourceLanguage]
                tts.speak(MarkdownSupport.speakableText(newValue), language: lang)
            }
        }
        .onChange(of: coordinator.targetLanguage) { _, newValue in
            targetLang = newValue
        }
        .onAppear {
            editableText = coordinator.sourceText
            sourceLang = Defaults[.sourceLanguage]
            targetLang = coordinator.targetLanguage
            expandedProviders = Set(coordinator.activeSlots.map(\.id))
            clampInputHeightToAllowedRange()

            // Two-finger trackpad swipe → tab switch (Manh 2026-11-17).
            // The monitor is scoped to the panel window, so it is inert
            // while the panel is hidden; start() is a no-op if it is
            // already installed (onAppear can fire more than once).
            if let panel {
                trackpadSwipeMonitor.start(panel: panel)
            }

            if Defaults[.ttsAutoPlaySource],
               !coordinator.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let tts = ttsCoordinator
            {
                let lang = coordinator.detectedLanguage ?? Defaults[.sourceLanguage]
                tts.speak(MarkdownSupport.speakableText(coordinator.sourceText), language: lang)
            }

            // A reminder fired while the panel was hidden (destination
            // Right Panel): the store holds the request; open on the
            // Fast Read tab and start the read (Manh 2026-11-20).
            consumePanelRightRequest(focusTimerStore.panelRightRequest)
        }
        // A 2-finger trackpad swipe switches tabs (Manh 2026-11-17): next
        // is the panel on the right, previous the one on the left.
        // NOTE (flipped 2026-11-17 ~20:28): the trackpad swipe is now the
        // OPPOSITE direction of the dots-row drag swipe — Manh tested the
        // first mapping (same as drag) and it felt backwards, so fingers
        // left is now the previous (left) panel, fingers right the next
        // (right) panel. The mouse drag is unchanged (drag left → next).
        .onReceive(trackpadSwipeMonitor.swipePublisher) { direction in
            switch direction {
            case .next:
                selectedTab = PanelTab(rawValue: min(selectedTab.rawValue + 1, PanelTab.fastRead.rawValue)) ?? selectedTab
            case .previous:
                selectedTab = PanelTab(rawValue: max(selectedTab.rawValue - 1, PanelTab.shortcut.rawValue)) ?? selectedTab
            }
        }
        .onChange(of: coordinator.translationGeneration) { _, _ in
            expandedProviders = Set(coordinator.activeSlots.map(\.id))
        }
        .onChange(of: coordinator.copiedProviderID) { _, providerID in
            guard let providerID else { return }
            expandedProviders.insert(providerID)
        }
        .onChange(of: coordinator.providerStates) { _, newStates in
            handleAutoPlay(states: newStates)
        }
        // A focus / rest-eyes reminder fired with destination Right
        // Panel (Manh 2026-11-20): the store holds the request; switch
        // to the Fast Read tab and start the read. `.onReceive` on the
        // @Published publisher — NOT `.onChange`: this view holds the
        // store as a plain `let` on purpose (the banner observes the
        // store itself so the panel does not re-render every second of
        // the timer), so `.onChange` only fires when some OTHER state
        // re-renders the body. Pressing Fast Read with "Right Panel"
        // while the panel was already visible set the request but
        // nothing re-rendered, so the tab never switched and the read
        // only started when a later swipe re-rendered the body (Manh
        // 2026-11-20 bug report, build 286). `.onReceive` subscribes
        // directly to the publisher, so it fires the moment the
        // request is set, with no re-render needed. The `.onAppear`
        // consume above stays as the path for a request set while the
        // panel was hidden; either path consumes it once (the second
        // call sees nil and returns).
        .onReceive(focusTimerStore.$panelRightRequest) { request in
            consumePanelRightRequest(request)
        }
        // While a read runs in the panel, freeze auto-fit (Manh
        // 2026-11-20): the reading view fills the panel, so its content
        // height would otherwise shrink a tall panel back to the fitted
        // size. Same mechanism as a manual drag
        // (`manualResizeGeneration`); cleared when the read stops, so
        // auto-fit resumes for the demo.
        .onChange(of: focusTimerStore.panelReadingViewModel == nil) { _, isNil in
            guard let panel else { return }
            if isNil {
                panel.manualResizeGeneration = nil
            } else {
                panel.manualResizeGeneration = coordinator.translationGeneration
            }
        }
    }

    /// Start a panel-right read requested by the focus timer (Manh
    /// 2026-11-20): switch to the Fast Read tab, start the read, and
    /// pin the panel so an outside click never dismisses the reminder
    /// mid-read.
    private func consumePanelRightRequest(_ request: PanelRightRequest?) {
        guard let request else { return }
        focusTimerStore.panelRightRequest = nil
        selectedTab = .fastRead
        focusTimerStore.startPanelReading(text: request.text, countdownSeconds: request.countdownSeconds)
        coordinator.isPinned = true
    }

    private var pinButton: some View {
        Button {
            coordinator.isPinned.toggle()
        } label: {
            Image(systemName: coordinator.isPinned ? "pin.fill" : "pin")
                .font(.system(size: CGFloat(fontSize - 2)))
                .foregroundStyle(coordinator.isPinned ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(coordinator.isPinned ? "Unpin Popup" : "Pin Popup")
        .background { InteractiveMarker() }
        .panelHoverHighlight()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// "Version 0.1.0 (123)"; local builds (build number "1") show just the version.
    private var versionText: String {
        buildNumber == "1" ? "Version \(appVersion)" : "Version \(appVersion) (\(buildNumber))"
    }

    private static let repoURL = URL(string: "https://github.com/TranManhTuanLabs/TransPeek")!

    // MARK: - Active Content

    @ViewBuilder
    /// The multi-tab frame (Manh 2026-11-17, hub layout): the top bar
    /// and the bottom bar stay the same on every tab; only the middle
    /// content switches — panel dịch (middle, default), panel shortcut
    /// (left, the shortcuts table), panel Fast Read (temporary name)
    /// (right, placeholder until Fast Read ships). The dots row below the
    /// content is the tab switcher (tap a dot, or swipe on the dots row).
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar

            // Dots row — TEMPORARY position (Manh 2026-11-18): moved up
            // from below the tab content to right under the top bar
            // (app name / slogan / hint), into the empty line there, so
            // Manh can try it. The dots still switch panels (tap or
            // swipe); the swipe gesture lives on the dots row, not the
            // content, because a drag over the results is text selection.
            dotsRow

            // A break reminder that fired while reading waits here
            // (Manh 2026-11-20, 05:33): the banner is its own view
            // (observing the store), so the panel never re-renders on
            // the timer's one-second ticks. It shows on every tab.
            PendingReminderBanner(store: focusTimerStore)

            switch selectedTab {
            case .translate:
                translateContent
                    .transition(.opacity)
            case .shortcut:
                shortcutContent
                    .transition(.opacity)
            case .fastRead:
                fastReadContent
                    .transition(.opacity)
            }

            bottomBar
        }
        // Smooth tab switch (Manh 2026-11-17 ~20:38, faster 23:55): swiping changed tabs
        // instantly, which felt abrupt — fade between tabs (0.15s ease-out;
        // was 0.25s ease-in-out, Manh said it felt a bit slow).
        // The swipe detection itself is unchanged (50pt, 1 swipe = 1 tab).
        .animation(.easeOut(duration: 0.15), value: selectedTab)
        .padding(.bottom, 12)
    }

    /// Top bar (same on every tab): app name + slogan + float-icon hint,
    /// centered. The whole top bar is a drag handle (TopBarDragMarker).
    private var topBar: some View {
        VStack(spacing: 2) {
            // Top bar: app name + slogan + float-icon hint, centered.
            // App name uses the top bar font size; slogan is 1pt smaller
            // (Windows parity 17/16/13, Manh 2026-11-17).
            // The hint is 4pt smaller than the app name and dimmer — it
            // tells new users the float icon's two gestures (Manh 2026-11-15).
            // The app name is the accent color (Manh 2026-11-18, round 9):
            // sea blue, for beauty — the app has no custom accent color
            // (AccentColor.colorset is empty), so this is the system
            // accent blue, the same blue as the selected dot and the
            // active icons in the panel.
            Text("TransPeek")
                .font(.system(size: CGFloat(topBarFontSize), weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text("Translate anywhere, Peek instantly!")
                .font(.system(size: CGFloat(max(topBarFontSize - 1, 8))))
                .italic()
                .foregroundStyle(.secondary)
            Text("Hover icon to translate, Click to listen")
                .font(.system(size: CGFloat(max(topBarFontSize - 4, 8))))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 2)
        // TopBarDragMarker: the whole top bar (app name / slogan /
        // hint) is a drag handle. The app-name Text ("TransPeek",
        // bold) is backed by NSTextField, which refuses
        // mouseDownCanMoveWindow, so without this marker a drag
        // starting on the app name — the spot the user grabs most —
        // would not move the panel (Manh 2026-11-16; the slogan/hint
        // drag fine, only the app name is affected).
        // PopupPanel.shouldStartWindowDrag treats this region as
        // always draggable. The top bar has no buttons, so nothing
        // interactive is covered.
        .background { TopBarDragMarker() }
    }

    /// Panel dịch (middle, default tab): the full translate panel —
    /// global error, or the source input + language bar + provider
    /// results (with the embedded "?" shortcuts table) + OCR section +
    /// Actions row + dictionary bar. Unchanged from the single-panel
    /// layout; only moved into its own property for the multi-tab frame.
    private var translateContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = coordinator.globalError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, contentHorizontalPadding)
            } else {
                // Source input
                SourceInputView(
                    text: $editableText,
                    sourceLanguage: coordinator.detectedLanguage ?? sourceLang,
                    onSubmit: {
                        coordinator.translate(editableText)
                    },
                    onCopyAndClose: {
                        copySourceAndClose()
                    },
                    onSwapLanguages: {
                        swapLanguages()
                    },
                    onContentHeightChange: { preferredHeight in
                        expandInputHeightIfNeeded(for: preferredHeight)
                    },
                    attachments: coordinator.sourceAttachments,
                    onSelectionChange: { selected in
                        lookupText = selected
                    }
                )
                .frame(height: inputHeight)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, contentHorizontalPadding)
                .padding(.bottom, 4)

                DraggableDividerView(
                    inputHeight: $inputHeight,
                    minHeight: inputMinHeight,
                    maxHeight: maxInputHeight,
                    horizontalPadding: contentHorizontalPadding,
                    onDragEnd: { Defaults[.popupInputHeight] = Int(inputHeight) }
                )

                // Language bar + Capture OCR (Manh 2026-11-15): pickers on
                // the left, Capture OCR on the right — like Windows'
                // TranslatePanelWindow.xaml language row (Grid 2 columns:
                // pickers *, Capture OCR Auto; commit ab5ffbf). Pin +
                // Settings moved to the Actions row below the results.
                HStack(spacing: 4) {
                    LanguageBarView(
                        sourceLanguage: $sourceLang,
                        detectedLanguage: coordinator.detectedLanguage,
                        detectionConfidence: coordinator.detectionResult?.confidence,
                        targetLanguage: $targetLang,
                        onSwap: {
                            swapLanguages()
                        },
                        popoverTracker: languagePopoverTracker
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // TransPeek Phase 1: screenshot OCR from the float panel.
                    // Shows the "Capture OCR" text next to the icon, like
                    // Windows (TranslatePanelWindow.xaml, OcrButton
                    // Content="Capture OCR").
                    Button {
                        onOCRRequested?()
                    } label: {
                        // Icon + text close together (HStack spacing 2):
                        // a plain Label leaves ~1 space between icon and
                        // text, which reads as too far apart (Manh 2026-11-15).
                        HStack(spacing: 2) {
                            Image(systemName: "text.viewfinder")
                            Text("Capture OCR")
                        }
                        .font(.system(size: CGFloat(fontSize - 2)))
                        .foregroundStyle(.secondary)
                        // Blue outline only (Manh 2026-11-19), made as
                        // light as possible (Manh 2026-11-20: the full
                        // blue was too bright and distracting — 0.25
                        // opacity keeps just a hint of the border). No
                        // fill, no text/icon color change. The small
                        // padding is just so the border doesn't touch
                        // the text.
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .help("OCR Screen Translate")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, 4)
                .onChange(of: targetLang) { _, newValue in
                    Defaults[.targetLanguage] = newValue
                    // Skip retranslation when this change came from coordinator sync
                    guard newValue != coordinator.targetLanguage else { return }
                    if !editableText.isEmpty {
                        coordinator.translate(editableText)
                    }
                }
                .onChange(of: sourceLang) { _, newValue in
                    Defaults[.sourceLanguage] = newValue
                    if !editableText.isEmpty {
                        coordinator.translate(editableText)
                    }
                }

                Divider()
                    .padding(.horizontal, contentHorizontalPadding)

                // Provider results
                ScrollView {
                    VStack(spacing: 6) {
                        // "?" shortcuts table (Manh 2026-11-17): embedded
                        // at the top of the output box, above the provider
                        // cards — a plain section, not a provider card and
                        // not a popover (a popover lost focus to the
                        // panel's click-outside auto-hide, so it could not
                        // be clicked). The providers stay below it; the
                        // table scrolls with the content, and the panel
                        // auto-fits up to the output cap.
                        // NOTE (Manh 2026-11-18): the "How the icon works"
                        // card used to sit here, above this table — it was
                        // moved to panel left (shortcutContent), above the
                        // shortcuts table there. Panel center is back to
                        // how it was before the card was added.
                        if showingShortcuts {
                            ShortcutsTableView(
                                onRunShortcut: onRunShortcut,
                                onClose: { showingShortcuts = false }
                            )
                        }

                        ForEach(coordinator.activeSlots, id: \.id) { provider in
                            if let state = coordinator.providerStates[provider.id] {
                                ProviderResultCard(
                                    provider: provider,
                                    state: state,
                                    targetLanguage: targetLang,
                                    isExpanded: expandedBinding(for: provider.id),
                                    isCopyFeedbackActive: coordinator.copiedProviderID == provider.id,
                                    copyFeedbackGeneration: coordinator.copyFeedbackGeneration,
                                    onCopy: {
                                        coordinator.copyResult(forProviderID: provider.id)
                                    },
                                    onTranslate: {
                                        coordinator.translateProvider(provider)
                                    },
                                    onRetry: {
                                        coordinator.retryProvider(provider)
                                    },
                                    attachments: coordinator.sourceAttachments,
                                    onSelectionChange: { selected in
                                        lookupText = selected
                                    },
                                    textCap: resultTextCap
                                )
                            }
                        }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.vertical, 6)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: PopupResultLayoutPreferenceKey.self,
                                    value: PopupResultLayout(contentHeight: geometry.size.height)
                                )
                        }
                    }
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: PopupResultLayoutPreferenceKey.self,
                                value: PopupResultLayout(viewportHeight: geometry.size.height)
                            )
                    }
                }

                // TransPeek Phase 1: OCR result with two separate copy buttons.
                if let ocrSource = coordinator.ocrSourceText, !ocrSource.isEmpty {
                    Divider()
                        .padding(.horizontal, contentHorizontalPadding)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(ocrSource)
                                .font(.system(size: CGFloat(fontSize)))
                                .lineLimit(3)
                            Spacer()
                            Button("Copy source") { _ = coordinator.copyOCRSource() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy recognized text")
                                .background { InteractiveMarker() }
                                .panelHoverHighlight()
                        }
                        if let ocrTranslation = coordinator.ocrTranslationText, !ocrTranslation.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Text(ocrTranslation)
                                    .font(.system(size: CGFloat(fontSize)))
                                    .lineLimit(3)
                                Spacer()
                                Button("Copy translation") { _ = coordinator.copyOCRTranslation() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("Copy translation")
                                    .background { InteractiveMarker() }
                                    .panelHoverHighlight()
                            }
                        }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.vertical, 6)
                }

                // Actions (Manh 2026-11-15): only Pin + Settings remain
                // here — Capture OCR moved up to the language row, like
                // Windows (TranslatePanelWindow.xaml, commit ab5ffbf).
                // Order is Pin then Settings, like Windows (PinButton
                // before SettingsButton in the Actions StackPanel).
                // The "?" shortcuts button (Manh 2026-11-17) sits directly
                // left of Pin: it toggles the shortcuts table embedded at
                // the top of the output box (not a popover — a popover
                // lost focus to the panel's click-outside auto-hide, so
                // the table could not be clicked). The button shows a
                // filled accent icon while the table is open. Tapping "?"
                // again (or the table's close button) hides the table.
                // This row's height is asserted in PopupPanelLayoutTests
                // (256 / 376) — update those numbers if this row changes.
                HStack(spacing: 4) {
                    // Fast Read (Manh 2026-11-17): opens the RSVP reading
                    // window with the text being translated — no need to
                    // re-select it. Sits at the left end of the Actions row.
                    // The icon and the "Fast Read" text sit close together
                    // (Manh 2026-11-18, round 8): a plain `Label` leaves a
                    // gap between icon and text, so this is an HStack with
                    // a small spacing instead — 4pt (Manh 2026-11-19,
                    // 0.1.5: spacing 0 was still too tight, double it).
                    Button {
                        onFastRead?(coordinator.sourceText)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                            Text("Fast Read")
                        }
                        .font(.system(size: CGFloat(fontSize - 2)))
                        .foregroundStyle(.secondary)
                        // Turmeric outline only (Manh 2026-11-19): a thin
                        // border lining around the button, no fill, no
                        // text/icon color change. Same turmeric as the
                        // Fast Read "A+" icon (0.78 / 0.50 / 0.05), made
                        // as light as possible (Manh 2026-11-20: the full
                        // turmeric was too bright and distracting — 0.25
                        // opacity keeps just a hint of the border). The
                        // small padding is just so the border doesn't
                        // touch the text.
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.78, green: 0.50, blue: 0.05).opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .help("Fast Read (RSVP)")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()

                    Spacer()

                    Button {
                        showingShortcuts.toggle()
                    } label: {
                        Image(systemName: showingShortcuts ? "questionmark.circle.fill" : "questionmark.circle")
                            .font(.system(size: CGFloat(fontSize - 2)))
                            .foregroundStyle(showingShortcuts ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Keyboard shortcuts")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()

                    Button {
                        onOpenSettings?()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: CGFloat(fontSize - 2)))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings")
                    .background { InteractiveMarker() }
                    .panelHoverHighlight()
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, 4)

                // TransPeek Phase 1: dictionary links at the bottom of the panel.
                Divider()
                    .padding(.horizontal, contentHorizontalPadding)
                DictionaryBarView(lookupText: lookupText ?? coordinator.sourceText)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, 6)
            }
        }
    }

    /// Panel left (panel 1, shortcuts — temporary content): the "How the
    /// icon works" intro card on top, then the Focus & Rest timer card,
    /// then the full shortcuts table as a page — the same
    /// ShortcutsTableView that the "?" button embeds in panel center,
    /// reused here (Manh 2026-11-17). The flow card moved
    /// here from panel center (Manh 2026-11-18 — it was put in panel
    /// center by mistake; panel center goes back to how it was). Run
    /// calls the same code path as the hotkey; closing the table (×, or
    /// the title) returns to panel center. The table scrolls inside its
    /// own ScrollView so it still fits when the panel is short, and it
    /// reports its height through the same layout preference as the
    /// provider results so auto-fit sizes the panel for this tab too.
    /// At the very bottom, the Share TransPeek row (Manh 2026-11-19):
    /// the same share icons as the Fast Read completion window and the
    /// About tab, no card — just a small label + the icons.
    private var shortcutContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                // "How the icon works" intro card (Manh 2026-11-18):
                // above the shortcuts table, so a new reader learns the
                // icon flow first; it collapses to a header and remembers
                // the state, so once the reader knows the flow the
                // shortcuts table is the main thing on show.
                FlowIntroCard(isCollapsed: $isFlowIntroCollapsed)
                    .onChange(of: isFlowIntroCollapsed) { _, newValue in
                        Defaults[.flowIntroCollapsed] = newValue
                    }

                // Focus & Rest timer card (Manh 2026-11-20, focus timer
                // + panel decor): Pomodoro + rest eyes + where the
                // reminder shows. Directly under "How the icon works",
                // above the shortcuts table (Manh 2026-11-20, 07:06 —
                // moved up from under the shortcuts table).
                FocusTimerCard(store: focusTimerStore, isCollapsed: $isFocusTimerCollapsed)
                    .onChange(of: isFocusTimerCollapsed) { _, newValue in
                        Defaults[.focusTimerCollapsed] = newValue
                    }

                // "Keyboard Shortcuts" card (Manh 2026-11-18, round 9):
                // collapsible in panel left — the header toggles collapse
                // (chevron) instead of closing the card, like the flow
                // card above it, so the cards can stay collapsed and
                // leave room. The `onClose` still switches to the
                // translate tab after a Run button, so the result is
                // visible — only the header changed from close to
                // collapse. (Panel center's "?" table does NOT pass
                // isCollapsed: its header still hides the table, as
                // before.)
                ShortcutsTableView(
                    onRunShortcut: onRunShortcut,
                    onClose: { selectedTab = .translate },
                    isCollapsed: $isShortcutsCollapsed
                )
                .onChange(of: isShortcutsCollapsed) { _, newValue in
                    Defaults[.shortcutsCollapsed] = newValue
                }

                // Share TransPeek — at the bottom of panel left
                // (Manh 2026-11-19): the same share row as the Fast
                // Read completion window and the About tab. No card —
                // just a small label + the icons, so it stays light
                // in a panel that is already dense. It scrolls with
                // the shortcuts table (inside this ScrollView) so
                // auto-fit still sizes the panel from the content.
                Text("Share TransPeek")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                ShareRowView(text: "TransPeek — Translate anywhere, Peek instantly!")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.vertical, 6)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: PopupResultLayoutPreferenceKey.self,
                            value: PopupResultLayout(contentHeight: geometry.size.height)
                        )
                }
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: PopupResultLayoutPreferenceKey.self,
                        value: PopupResultLayout(viewportHeight: geometry.size.height)
                    )
            }
        }
    }

    /// Panel Fast Read (right tab): in-panel reading + focus demo
    /// (Manh 2026-11-20, focus timer + panel decor). The placeholder
    /// is gone as the idle state — `PanelFastReadView` shows the demo
    /// ("reading", yellow "a", half-bars) and a "Read in panel"
    /// button, and swaps in the reading view (same RSVP engine / view
    /// model / view as the Fast Read window) when a read starts.
    /// The panel stays at its minimum height on this tab when idle;
    /// while reading, auto-fit is frozen (see the
    /// `panelReadingViewModel` onChange below) so the reading view
    /// never shrinks a tall panel back to the fitted size.
    private var fastReadContent: some View {
        PanelFastReadView(
            store: focusTimerStore,
            sourceText: editableText,
            onStartReading: { coordinator.isPinned = true },
            onToggleMaximize: { togglePanelSize() }
        )
    }

    /// Toggle the panel between its default size and its maximum size
    /// (Manh 2026-11-20): the Maximize button in the panel-right
    /// reading chrome. Keeps the top edge fixed and clamps to the
    /// visible frame; marks the size as a manual resize so auto-fit
    /// does not fight it for this generation (same as a drag — see
    /// `finishPanelResize`). The maximum is the panel's own max
    /// CLAMPED to the visible frame (Manh 2026-11-20, 08:11): when
    /// the visible height is under 800 (Dock / menu bar), the
    /// maximized panel is only as tall as the visible frame, so it
    /// never covers the Dock — and the toggle still works, because
    /// "is max" is measured against that same clamped maximum.
    private func togglePanelSize() {
        guard let panel else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let effectiveMax = CGSize(
            width: min(PopupPanel.maximumSize.width, visible.width),
            height: min(PopupPanel.maximumSize.height, visible.height)
        )
        let current = panel.frame.size
        let isMax = current.width >= effectiveMax.width - 1
            && current.height >= effectiveMax.height - 1
        let target: CGSize = isMax
            ? CGSize(
                width: CGFloat(Defaults[.popupDefaultWidth]),
                height: CGFloat(Defaults[.popupDefaultHeight])
            )
            : effectiveMax
        let width = min(max(target.width, PopupPanel.minimumSize.width), effectiveMax.width)
        let height = min(max(target.height, PopupPanel.minimumSize.height), effectiveMax.height)
        let x = min(max(panel.frame.minX, visible.minX), visible.maxX - width)
        let y = min(max(panel.frame.maxY - height, visible.minY), visible.maxY - height)
        panel.manualResizeGeneration = coordinator.translationGeneration
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: true)
    }

    /// Dots row (Manh 2026-11-17): 3 dots, one per panel, centered.
    /// The selected dot is accent-colored, the others dimmed. Tap a dot
    /// to switch panels. A horizontal swipe on the dots row also
    /// switches (left → next panel, right → previous panel). Swipe lives
    /// here — not on the tab content — because a drag over the
    /// results/input is text selection, and a swipe gesture on the
    /// content would steal it.
    /// TEMPORARY position (Manh 2026-11-18): the row sits right under the
    /// top bar (app name / slogan / hint), in the empty line there —
    /// moved up from below the tab content so Manh can try it. The row
    /// is compact here (2pt top padding) so it reads as part of the
    /// top bar, not as a gap before the content.
    /// The `<` / `>` arrows beside the dots (Manh 2026-11-18, round 8)
    /// are a visible affordance that the row is clickable — the dots
    /// alone did not look tappable. Both arrows are the same width, so
    /// the dots stay centered; an arrow is dimmed at its end (no
    /// previous / no next panel). The dots' position is UNCHANGED
    /// (Manh 2026-11-18: keep it as-is on both repos for comparison).
    private var dotsRow: some View {
        ZStack {
            HStack(spacing: 8) {
                Button {
                    selectedTab = PanelTab(rawValue: max(selectedTab.rawValue - 1, PanelTab.shortcut.rawValue)) ?? selectedTab
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundStyle(selectedTab == .shortcut ? Color.secondary.opacity(0.3) : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(selectedTab == .shortcut)
                .help("Previous panel")
                .background { InteractiveMarker() }
                .panelHoverHighlight()

                ForEach(PanelTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Circle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                    .buttonStyle(.plain)
                    .help(dotHelp(tab))
                    .background { InteractiveMarker() }
                }

                Button {
                    selectedTab = PanelTab(rawValue: min(selectedTab.rawValue + 1, PanelTab.fastRead.rawValue)) ?? selectedTab
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(selectedTab == .fastRead ? Color.secondary.opacity(0.3) : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(selectedTab == .fastRead)
                .help("Next panel")
                .background { InteractiveMarker() }
                .panelHoverHighlight()
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Pin button (Manh 2026-11-20, 07:08 + 07:10, temporary):
            // at the left end of the dots row, near the panel's left
            // edge with a small padding (10pt — was 4pt, shifted 6pt
            // right, Manh 2026-11-20, 07:54) so it looks neat — not
            // flush to the edge (0), not the row's normal large
            // padding. The dots row is shared across all 3 tabs, so
            // the pin is on every tab.
            HStack {
                pinButton
                Spacer()
            }
            .padding(.leading, 10)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .gesture(swipeGesture)
    }

    /// A horizontal swipe on the dots row switches panels: swiping left
    /// reveals the panel on the right, swiping right reveals the panel on
    /// the left (standard paging). Only a clear horizontal swipe counts
    /// (|width| > 50 and wider than tall), so a tap or a vertical scroll
    /// never switches tabs.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 50, abs(horizontal) > abs(vertical) * 1.5 else { return }
                if horizontal < 0 {
                    selectedTab = PanelTab(rawValue: min(selectedTab.rawValue + 1, PanelTab.fastRead.rawValue)) ?? selectedTab
                } else {
                    selectedTab = PanelTab(rawValue: max(selectedTab.rawValue - 1, PanelTab.shortcut.rawValue)) ?? selectedTab
                }
            }
    }

    /// The help text for a dot: the panel's feature name (not a number —
    /// the numbers may map to different features later, Manh 2026-11-17).
    private func dotHelp(_ tab: PanelTab) -> String {
        switch tab {
        case .shortcut: return "Shortcuts"
        case .translate: return "Translate"
        case .fastRead: return "Fast Read"
        }
    }

    /// Bottom bar (same on every tab): GitHub link centered, version
    /// dimmed on the right — quaternary like the shortcut hint in the
    /// input row, so it reads as metadata, not content. The version was
    /// briefly removed (round 3) and restored dimmed: it is the quickest
    /// way to tell which build is running when reporting a bug from the
    /// panel.
    /// The InteractiveMarker is what makes the links clickable: without
    /// it PopupPanel treats a click here as a window drag (see
    /// PopupPanel.shouldStartWindowDrag), like every other button in
    /// this panel carries one.
    private var bottomBar: some View {
        HStack {
            Spacer()

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .overlay(alignment: .center) {
            HStack(spacing: 4) {
                Link(destination: Self.repoURL) {
                    GitHubMarkShape()
                        .fill(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("View TransPeek on GitHub")
                .onHover { hovering in
                    // System pointing-hand cursor for links (Manh
                    // 2026-11-20): NSCursor.pointingHand IS the macOS
                    // system cursor for links, not a custom hand image.
                    // Plain buttons do NOT get this — macOS buttons
                    // highlight instead of changing the cursor.
                    if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                }

                Link("GitHub", destination: Self.repoURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                    }
            }
            .background { InteractiveMarker() }
        }
        .padding(.horizontal, contentHorizontalPadding)
        // Top and bottom gaps are both 12pt (Manh 2026-11-16, try 12
        // instead of 14): the GitHub icon used to sit only 6pt below
        // the dictionary links but 14pt above the bottom edge, which
        // read as unbalanced once the 3-line corner grip drew the eye
        // to the bottom. 12pt even on both sides. This is 4pt less
        // than the 14pt version — PopupPanelLayoutTests was updated
        // in the same commit.
        .padding(.top, 12)
    }

    // MARK: - Helpers

    /// Right-edge resize handle (width only). Extracted into its own property
    /// so the compiler type-checks it separately — inlining both edge handles
    /// in the body made the compiler give up ("unable to type-check this
    /// expression in reasonable time", Tests #180).
    private var rightEdgeResizeHandle: some View {
        EdgeResizeHandle(
            axis: EdgeResizeHandle.Axis.width,
            translationGeneration: coordinator.translationGeneration,
            resultLayout: resultLayout,
            onResizeEnd: reportResultLayout
        )
        // Width pinned to 6 (min == max); height expands to fill the panel.
        // NOTE: .frame has no (width + maxHeight) overload — the mixed form
        // is a compile error ("extra argument 'width' in call", Tests #181).
        .frame(minWidth: 6, maxWidth: 6, maxHeight: .infinity)
    }

    /// Bottom-edge resize handle (height only, snaps back like the corner grip).
    private var bottomEdgeResizeHandle: some View {
        EdgeResizeHandle(
            axis: EdgeResizeHandle.Axis.height,
            translationGeneration: coordinator.translationGeneration,
            resultLayout: resultLayout,
            onResizeEnd: reportResultLayout
        )
        // Height pinned to 6 (min == max); width expands to fill the panel.
        .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
    }

    private func reportResultLayout() {
        onResultLayoutChange?(resultLayout)
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedProviders.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedProviders.insert(id)
                } else {
                    expandedProviders.remove(id)
                }
            }
        )
    }

    private func clampInputHeightToAllowedRange() {
        let clamped = min(max(inputHeight, inputMinHeight), maxInputHeight)
        guard clamped != inputHeight else { return }
        inputHeight = clamped
    }

    /// Reflow the input height to follow content. Grows up to `maxInputHeight` and
    /// shrinks back down to the user-set baseline (persisted in `popupInputHeight`),
    /// so deleting pasted long text reclaims the space.
    private func expandInputHeightIfNeeded(for preferredHeight: CGFloat) {
        let baseline = min(max(CGFloat(Defaults[.popupInputHeight]), inputMinHeight), maxInputHeight)
        let targetHeight = min(max(preferredHeight, baseline), maxInputHeight)
        guard abs(targetHeight - inputHeight) > 0.5 else { return }
        inputHeight = targetHeight
    }

    private func swapLanguages() {
        let effectiveSource = sourceLang == "auto"
        ? (coordinator.detectedLanguage ?? targetLang)
        : sourceLang
        // When auto-detect has no result yet, effectiveSource falls back
        // to targetLang and swap becomes a no-op
        guard effectiveSource != targetLang else { return }
        sourceLang = targetLang
        targetLang = effectiveSource
    }

    private func copySourceAndClose() {
        let source = MarkdownSupport.removingAttachmentPlaceholders(editableText)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(source, forType: .string) else { return }
        onDismiss?()
    }

    private func handleAutoPlay(states: [String: TranslationCoordinator.ProviderState]) {
        guard Defaults[.ttsAutoPlayTarget],
              let tts = ttsCoordinator,
              coordinator.translationGeneration != autoPlayedGeneration else { return }

        let preferredProvider = Defaults[.ttsAutoPlayTargetProvider]

        let completedText: String?
        if preferredProvider == "first" {
            // Auto-play the first provider (in display order) that has completed
            completedText = coordinator.activeSlots
                .lazy
                .compactMap { provider -> String? in
                    if case .completed(let text) = states[provider.id] { return text }
                    return nil
                }
                .first
        } else {
            // Wait for the specific provider to complete
            if case .completed(let text) = states[preferredProvider] {
                completedText = text
            } else {
                completedText = nil
            }
        }

        if let text = completedText {
            autoPlayedGeneration = coordinator.translationGeneration
            tts.speak(MarkdownSupport.speakableText(text), language: targetLang)
        }
    }
}

// Collect one layout pass before reporting sizes; separate state callbacks can mix
// a new viewport height with the previous container height and keep resizing the panel.
/// Merges layout measurements from the panel content. Internal (not
/// private) since 2026-11-20: `PanelFastReadView` reports its own
/// content/viewport heights the same way the other tabs do.
struct PopupResultLayoutPreferenceKey: PreferenceKey {
    static var defaultValue: PopupResultLayout { PopupResultLayout() }

    static func reduce(value: inout PopupResultLayout, nextValue: () -> PopupResultLayout) {
        let next = nextValue()
        if let height = next.contentHeight { value.contentHeight = height }
        if let height = next.viewportHeight { value.viewportHeight = height }
        if let height = next.containerHeight { value.containerHeight = height }
    }
}

// MARK: - Resize Grip

/// The frame auto-fit would produce right now, from the latest measured
/// result layout. Nil when the layout has not been measured yet — the
/// snap-back is then skipped and the drag behaves as before.
/// `chromeHeight` (container − viewport) and `contentHeight` do not change
/// while dragging (the extra height all goes to the ScrollView viewport),
/// so the fitted height is stable even if the measurement lags the drag
/// by a frame.
private func popupFittedFrame(for panel: PopupPanel, layout: PopupResultLayout) -> NSRect? {
    guard let contentHeight = layout.contentHeight,
          let viewportHeight = layout.viewportHeight,
          let containerHeight = layout.containerHeight,
          viewportHeight > 0,
          let screen = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
    else { return nil }
    return PopupPanelSizing.frameToFit(
        currentFrame: panel.frame,
        contentHeight: contentHeight,
        viewportHeight: viewportHeight,
        measuredContainerHeight: containerHeight,
        minimumHeight: PopupPanel.minimumSize.height,
        maximumHeight: PopupPanel.maximumSize.height,
        visibleFrame: screen.visibleFrame
    )
}

/// Shared drag-end for panel resize handles (corner grip + edge handles).
/// No size is saved here: the panel always opens at the Settings default
/// size (Manh 2026-11-16 — Settings only sets the default minimum; a
/// manual drag only changes the size for this session, so there is no
/// dragged size to persist and no conflict with the default).
/// When `resizeHeight` is true, snaps the height back to the fitted height
/// when the content is short (no useless whitespace), otherwise suppresses
/// auto-fit for this generation. A width-only drag must not touch the
/// height — but it CAN snap the width back (see below).
private func finishPanelResize(
    panel: PopupPanel,
    dragStartFrame: NSRect?,
    translationGeneration: Int,
    layout: PopupResultLayout,
    resizeHeight: Bool
) {
    let fitted = popupFittedFrame(for: panel, layout: layout)
    var targetFrame = panel.frame

    // Vertical snap-back (Manh 2026-11-15, "Windows full" vertical resize,
    // native mac way): if the user dragged the panel taller than the content
    // needs, shrink it back to the fitted height so no useless whitespace
    // is left under the results. Long content keeps the dragged height —
    // the results ScrollView already expanded to show more text.
    // Do not suppress auto-fit when snapping back: the panel is back at
    // its fitted size.
    // The +8 threshold mirrors Windows' SettleResizedSize (Manh
    // 2026-11-17, Windows parity): only snap back when the drag left
    // more than 8pt of white space — a smaller overshoot is tolerated,
    // so the panel does not visibly jump for a 1–2pt overshoot.
    if resizeHeight, let fitted, panel.frame.height > fitted.height + 8 {
        targetFrame.size.height = fitted.height
        targetFrame.origin.y = fitted.origin.y
    } else if resizeHeight, let initial = dragStartFrame,
              abs(panel.frame.height - initial.height) > 8 {
        panel.manualResizeGeneration = translationGeneration
    }

    // Horizontal snap-back (Manh 2026-11-16, report 4.2): if the content
    // is short (fitted height at the panel minimum) and the panel was
    // dragged wider than the default, snap the width back to the default
    // so a too-wide drag does not leave an ugly wide panel. Long content
    // keeps the dragged width — a wider panel shows more of it per line.
    // The +8 threshold mirrors Windows' SettleResizedSize (Manh
    // 2026-11-17): only snap back a width more than 8pt past the default.
    if let fitted,
       panel.frame.width > CGFloat(Defaults[.popupDefaultWidth]) + 8,
       fitted.height <= PopupPanel.minimumSize.height + 0.5 {
        targetFrame.size.width = CGFloat(Defaults[.popupDefaultWidth])
    }

    if targetFrame != panel.frame {
        panel.setFrame(targetFrame, display: true, animate: true)
    }
}

/// A draggable grip in the bottom-right corner for resizing the popup panel.
/// Uses SwiftUI DragGesture with NSEvent.mouseLocation (screen coordinates) to avoid
/// EXC_BAD_ACCESS caused by overriding mouse events on NSPanel with NSHostingView.
private struct ResizeGripView: View {
    let translationGeneration: Int
    /// Latest measured result layout (content / viewport / container heights,
    /// via GeometryReader preferences). Used on drag end to snap the panel
    /// back to its fitted height when the content is short.
    let resultLayout: PopupResultLayout
    let onResizeEnd: () -> Void
    @Environment(\.popupPanel) private var panel
    @State private var dragStartMouse: NSPoint?
    @State private var dragStartFrame: NSRect?

    var body: some View {
        Canvas { context, size in
            let lineCount = 3
            let spacing: CGFloat = 3
            let lineWidth: CGFloat = 1
            // Each line i runs from the bottom edge to the right edge, inset
            // by (i+1)*spacing from the corner, so all 3 lines have nonzero
            // length. (The old formula put the last line exactly on the
            // corner, a zero-length point, so only 2 lines were visible.)
            for i in 0..<lineCount {
                let a = CGFloat(i + 1) * spacing
                let start = CGPoint(x: a, y: size.height)
                let end = CGPoint(x: size.width, y: a)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: lineWidth)
            }
        }
        .frame(width: 12, height: 12)
        .padding(4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    let mouse = NSEvent.mouseLocation
                    if dragStartMouse == nil {
                        dragStartMouse = mouse
                        dragStartFrame = panel?.frame
                    }
                    guard let start = dragStartMouse,
                          let initial = dragStartFrame,
                          let panel else { return }

                    let deltaX = mouse.x - start.x
                    let deltaY = mouse.y - start.y
                    panel.isUserResizing = true

                    // Clamp to PopupPanel.minimumSize / maximumSize directly,
                    // not panel.minSize / panel.maxSize — the window
                    // properties can be reset by NSHostingView, so reading
                    // them at drag time silently ignored the minimum on
                    // build #191 (Manh 2026-11-16). windowWillResize is the
                    // AppKit-level backstop for the same bounds.
                    let newW = min(max(initial.width + deltaX, PopupPanel.minimumSize.width), PopupPanel.maximumSize.width)
                    let newH = min(max(initial.height - deltaY, PopupPanel.minimumSize.height), PopupPanel.maximumSize.height)

                    // Keep top-left corner fixed
                    let newY = initial.maxY - newH
                    panel.setFrame(
                        NSRect(x: initial.origin.x, y: newY, width: newW, height: newH),
                        display: true
                    )
                }
                .onEnded { _ in
                    if let panel {
                        finishPanelResize(
                            panel: panel,
                            dragStartFrame: dragStartFrame,
                            translationGeneration: translationGeneration,
                            layout: resultLayout,
                            resizeHeight: true
                        )
                        panel.isUserResizing = false
                        onResizeEnd()
                    }
                    dragStartMouse = nil
                    dragStartFrame = nil
                }
        )
        .onDisappear {
            // Only clear the flag when no drag is in progress. If SwiftUI
            // recreates this view mid-drag, the old instance's onDisappear
            // must NOT clear isUserResizing, or resizeForResultContent
            // will snap the panel back to the fitted height and fight the
            // drag — the vertical jerk when dragging down (Manh 2026-11-16).
            if dragStartMouse == nil {
                panel?.isUserResizing = false
            }
        }
        .onHover { hovering in
            if hovering {
                if #available(macOS 15.0, *) {
                    NSCursor.frameResize(position: .bottomRight, directions: .all).set()
                } else {
                    NSCursor.crosshair.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
        .background { InteractiveMarker() }
    }
}

/// An invisible resize handle along the panel's right or bottom edge.
/// Same drag mechanism as ResizeGripView (DragGesture + panel.setFrame),
/// but constrained to one axis: the right edge changes width only, the
/// bottom edge changes height only (and snaps back like the corner grip
/// when the content is short). The corner grip is overlaid on top of
/// these in the corner region, so it wins the diagonal drag there.
/// A borderless panel gets no system edge resize from macOS, so these
/// handles are how the edges become resizable (Manh 2026-11-15).
private struct EdgeResizeHandle: View {
    enum Axis {
        case width   // right edge: drag horizontally
        case height  // bottom edge: drag vertically
    }

    let axis: Axis
    let translationGeneration: Int
    let resultLayout: PopupResultLayout
    let onResizeEnd: () -> Void
    @Environment(\.popupPanel) private var panel
    @State private var dragStartMouse: NSPoint?
    @State private var dragStartFrame: NSRect?

    var body: some View {
        // NOT Color.clear: a clear view draws nothing, and on first
        // appearance its hover/drag tracking is not reliably established
        // — the first hover over an edge did not change the cursor, and
        // the first drag could start late and jump (Manh 2026-11-17: "lần
        // đầu di chuột vào cạnh thì chuột không đổi icon, phải kéo góc
        // lần đầu", and the drag-down jerk). A white fill at 0.001
        // opacity is invisible but DOES draw, so the tracking area is
        // solid from the first layout — the corner grip (a Canvas that
        // draws) never had this problem. The drag jerk and the missing
        // first-hover cursor share this root cause: when hit-testing is
        // broken the DragGesture engages late, so the panel jumps when
        // it finally catches the mouse.
        Color.white.opacity(0.001)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouse = NSEvent.mouseLocation
                        if dragStartMouse == nil {
                            dragStartMouse = mouse
                            dragStartFrame = panel?.frame
                        }
                        guard let start = dragStartMouse,
                              let initial = dragStartFrame,
                              let panel else { return }
                        panel.isUserResizing = true
                        switch axis {
                        case .width:
                            let deltaX = mouse.x - start.x
                            // Clamp to PopupPanel.minimumSize / maximumSize
                            // directly (see ResizeGripView): panel.minSize /
                            // panel.maxSize are not reliable at drag time.
                            let newW = min(max(initial.width + deltaX, PopupPanel.minimumSize.width), PopupPanel.maximumSize.width)
                            panel.setFrame(
                                NSRect(x: initial.origin.x, y: initial.origin.y, width: newW, height: initial.height),
                                display: true
                            )
                        case .height:
                            let deltaY = mouse.y - start.y
                            let newH = min(max(initial.height - deltaY, PopupPanel.minimumSize.height), PopupPanel.maximumSize.height)
                            // Keep top-left corner fixed
                            let newY = initial.maxY - newH
                            panel.setFrame(
                                NSRect(x: initial.origin.x, y: newY, width: initial.width, height: newH),
                                display: true
                            )
                        }
                    }
                    .onEnded { _ in
                        if let panel {
                            finishPanelResize(
                                panel: panel,
                                dragStartFrame: dragStartFrame,
                                translationGeneration: translationGeneration,
                                layout: resultLayout,
                                resizeHeight: axis == .height
                            )
                            panel.isUserResizing = false
                            onResizeEnd()
                        }
                        dragStartMouse = nil
                        dragStartFrame = nil
                    }
            )
            .onDisappear {
                // Only clear the flag when no drag is in progress — same
                // mid-drag view-recreation guard as the corner grip (see
                // ResizeGripView): clearing isUserResizing mid-drag lets
                // resizeForResultContent snap the height back and fight
                // the drag, which is the vertical jerk (Manh 2026-11-16).
                if dragStartMouse == nil {
                    panel?.isUserResizing = false
                }
            }
            .onHover { hovering in
                if hovering {
                    switch axis {
                    case .width: NSCursor.resizeLeftRight.set()
                    case .height: NSCursor.resizeUpDown.set()
                    }
                } else {
                    NSCursor.arrow.set()
                }
            }
            .background { InteractiveMarker() }
    }
}

// MARK: - Draggable Divider

/// A horizontal divider between the source input and translation results that can be
/// dragged vertically to resize the input area.
private struct DraggableDividerView: View {
    @Binding var inputHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let horizontalPadding: CGFloat
    let onDragEnd: () -> Void

    @State private var dragStartMouse: CGFloat?
    @State private var dragStartHeight: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Divider()
            .padding(.horizontal, horizontalPadding)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouseY = NSEvent.mouseLocation.y
                        if dragStartMouse == nil {
                            dragStartMouse = mouseY
                            dragStartHeight = inputHeight
                        }
                        guard let startY = dragStartMouse, let startH = dragStartHeight else { return }
                        // Screen Y points up; dragging down decreases mouseY but should increase inputHeight
                        let delta = startY - mouseY
                        let newHeight = startH + delta
                        inputHeight = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        dragStartMouse = nil
                        dragStartHeight = nil
                        onDragEnd()
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                }
            }
            .background { InteractiveMarker() }
    }
}

// MARK: - Interactive Marker

/// NSView marker placed as `.background()` on SwiftUI gesture views.
/// `PopupPanel.sendEvent` checks for this marker to prevent window dragging
/// over areas that handle their own drag gestures (divider, resize grip).
final class InteractiveMarkerView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct InteractiveMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> InteractiveMarkerView { InteractiveMarkerView() }
    func updateNSView(_: InteractiveMarkerView, context: Context) {}
}

// MARK: - Top Bar Drag Marker

/// NSView marker placed as `.background()` on the top bar (app name /
/// slogan / hint). `PopupPanel.sendEvent` treats this region as always
/// draggable, so the app-name Text — backed by NSTextField, which refuses
/// `mouseDownCanMoveWindow` — never blocks window dragging. (Only the app
/// name is affected; the slogan/hint drag fine.) The opposite of
/// InteractiveMarker: this one *allows* dragging instead of preventing it.
/// The top bar contains no buttons, so nothing interactive is covered.
final class TopBarDragMarkerView: NSView {}

struct TopBarDragMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> TopBarDragMarkerView { TopBarDragMarkerView() }
    func updateNSView(_: TopBarDragMarkerView, context: Context) {}
}
