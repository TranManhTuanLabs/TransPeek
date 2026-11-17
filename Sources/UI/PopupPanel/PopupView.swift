import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOCRRequested: (() -> Void)?
    /// Called when a Run button in the "?" shortcuts panel is clicked:
    /// runs the named shortcut through AppDelegate.performShortcut, the
    /// same dispatch the physical hotkeys use (Manh 2026-11-17).
    var onRunShortcut: ((KeyboardShortcuts.Name) -> Void)?
    /// Whether the "?" shortcuts table (embedded at the top of the
    /// output box, Manh 2026-11-17) is shown. It is a plain section, not
    /// a popover and not a provider card.
    @State private var showingShortcuts = false
    @State private var editableText: String = ""
    /// Text the dictionary links look up (SPEC §3.2): the text selected
    /// inside the source editor or a translation result when there is one,
    /// otherwise `nil` and the bar falls back to the source text that
    /// opened the panel.
    @State private var lookupText: String? = nil
    @State private var expandedProviders: Set<String> = []
    @State private var autoPlayedGeneration: Int = -1
    @Environment(\.ttsCoordinator) private var ttsCoordinator
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

            if Defaults[.ttsAutoPlaySource],
               !coordinator.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let tts = ttsCoordinator
            {
                let lang = coordinator.detectedLanguage ?? Defaults[.sourceLanguage]
                tts.speak(MarkdownSupport.speakableText(coordinator.sourceText), language: lang)
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
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: app name + slogan + float-icon hint, centered.
            // App name uses the top bar font size; slogan is 1pt smaller
            // (Windows parity 17/16/13, Manh 2026-11-17).
            // The hint is 4pt smaller than the app name and dimmer — it
            // tells new users the float icon's two gestures (Manh 2026-11-15).
            VStack(spacing: 2) {
                Text("TransPeek")
                    .font(.system(size: CGFloat(topBarFontSize), weight: .bold))
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

            // Global error (no providers, permissions, etc.)
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
                        }
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
                    }
                    .buttonStyle(.plain)
                    .help("OCR Screen Translate")
                    .background { InteractiveMarker() }
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

                    pinButton

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

            // Bottom bar: GitHub link centered, version dimmed on the
            // right — quaternary like the shortcut hint in the input
            // row, so it reads as metadata, not content. The version
            // was briefly removed (round 3) and restored dimmed: it is
            // the quickest way to tell which build is running when
            // reporting a bug from the panel.
            // The InteractiveMarker is what makes the links clickable:
            // without it PopupPanel treats a click here as a window drag
            // (see PopupPanel.shouldStartWindowDrag), like every other
            // button in this panel carries one.
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

                    Link("GitHub", destination: Self.repoURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .padding(.bottom, 12)
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
private struct PopupResultLayoutPreferenceKey: PreferenceKey {
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
