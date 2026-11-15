import AppKit
import Defaults
import SwiftUI

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOCRRequested: (() -> Void)?
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
            // App name uses the top bar font size; slogan is 2pt smaller.
            // The hint is 4pt smaller than the app name and dimmer — it
            // tells new users the float icon's two gestures (Manh 2026-11-15).
            VStack(spacing: 2) {
                Text("TransPeek")
                    .font(.system(size: CGFloat(topBarFontSize), weight: .bold))
                Text("Translate anywhere, Peek instantly!")
                    .font(.system(size: CGFloat(max(topBarFontSize - 2, 8))))
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
                                    }
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
                // This row's height is asserted in PopupPanelLayoutTests
                // (256 / 376) — update those numbers if this row changes.
                HStack(spacing: 4) {
                    Spacer()

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
            .padding(.top, 6)
        }
        .padding(.bottom, contentHorizontalPadding)
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
        baselineHeight: CGFloat(Defaults[.popupDefaultHeight]),
        maximumHeight: panel.maxSize.height,
        visibleFrame: screen.visibleFrame
    )
}

/// Shared drag-end for panel resize handles (corner grip + edge handles).
/// Saves the width; when `resizeHeight` is true, snaps the height back to
/// the fitted height when the content is short (no useless whitespace),
/// otherwise saves the height and suppresses auto-fit for this generation.
/// A width-only drag must not touch the height.
private func finishPanelResize(
    panel: PopupPanel,
    dragStartFrame: NSRect?,
    translationGeneration: Int,
    layout: PopupResultLayout,
    resizeHeight: Bool
) {
    Defaults[.popupDefaultWidth] = Int(panel.frame.width)
    guard resizeHeight else { return }
    let draggedHeight = panel.frame.height
    // Snap back on release (Manh 2026-11-15, "Windows full" vertical resize,
    // native mac way): if the user dragged the panel taller than the content
    // needs, shrink it back to the fitted height so no useless whitespace
    // is left under the results. Long content keeps the dragged height —
    // the results ScrollView already expanded to show more text.
    if let fitted = popupFittedFrame(for: panel, layout: layout),
       draggedHeight > fitted.height + 0.5 {
        panel.setFrame(fitted, display: true, animate: true)
        // Do not save the tall height and do not suppress auto-fit:
        // the panel is back at its fitted size.
    } else if let initial = dragStartFrame,
              abs(draggedHeight - initial.height) > 8 {
        Defaults[.popupDefaultHeight] = Int(draggedHeight)
        panel.manualResizeGeneration = translationGeneration
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

                    let newW = min(max(initial.width + deltaX, panel.minSize.width), panel.maxSize.width)
                    let newH = min(max(initial.height - deltaY, panel.minSize.height), panel.maxSize.height)

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
        .onDisappear { panel?.isUserResizing = false }
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
        Color.clear
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
                            let newW = min(max(initial.width + deltaX, panel.minSize.width), panel.maxSize.width)
                            panel.setFrame(
                                NSRect(x: initial.origin.x, y: initial.origin.y, width: newW, height: initial.height),
                                display: true
                            )
                        case .height:
                            let deltaY = mouse.y - start.y
                            let newH = min(max(initial.height - deltaY, panel.minSize.height), panel.maxSize.height)
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
            .onDisappear { panel?.isUserResizing = false }
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
