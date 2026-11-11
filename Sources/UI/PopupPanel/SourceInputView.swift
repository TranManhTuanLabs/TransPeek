import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Editable source text input with Enter to translate, Shift+Enter for newline.
struct SourceInputView: View {
    @Binding var text: String
    let sourceLanguage: String
    let onSubmit: () -> Void
    let onCopyAndClose: () -> Void
    let onSwapLanguages: () -> Void
    var onContentHeightChange: ((CGFloat) -> Void)?
    var attachments: [String: SourceImageAttachment] = [:]
    /// Reports the text currently selected inside the source editor, or `nil`
    /// when the selection is empty. `PopupView` uses it to retarget the
    /// dictionary links (SPEC §3.2): links follow the in-panel selection
    /// while there is one, and fall back to the source text otherwise.
    var onSelectionChange: ((String?) -> Void)?
    @Default(.popupFontSize) private var fontSize
    @Default(.sourceViewMode) private var sourceViewMode
    @Default(.captureRichText) private var captureRichText
    @Default(.popupFontName) private var fontName
    @Default(.ttsAccent) private var ttsAccent
    @Environment(\.ttsCoordinator) private var ttsCoordinator
    // Keyboard shortcuts only reach the panel when it is the key window (e.g. selection
    // translation shows the panel without focus); dim the hints when they wouldn't work.
    @State private var isWindowKey = false
    @State private var swapShortcut = SwapLanguagesShortcut.current
    /// Copy-button feedback ("Copied" for ~1.5s), local to this view — mirrors
    /// ProviderResultCard's copy feedback for the output side.
    @State private var isSourceCopyFeedbackActive = false
    @State private var sourceCopyFeedbackTask: Task<Void, Never>?

    /// Plain selections keep the editor; the read-only rich view only appears for rich captures.
    private var offersRichView: Bool {
        (captureRichText || !attachments.isEmpty) && MarkdownSupport.looksLikeMarkdown(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if offersRichView && sourceViewMode == .rich {
                ScrollView {
                    MarkdownResultView(
                        text: text,
                        font: .popup(name: fontName, size: CGFloat(fontSize)),
                        attachments: attachments,
                        showsAttachments: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .background { InteractiveMarker() }
            } else {
                SourceTextEditor(
                    text: $text,
                    fontSize: CGFloat(fontSize),
                    fontName: fontName,
                    onSubmit: onSubmit,
                    onCopyAndClose: onCopyAndClose,
                    onSwapLanguages: onSwapLanguages,
                    onSelectionChange: onSelectionChange,
                    onWindowKeyChange: { isKey in
                        isWindowKey = isKey
                    },
                    onContentHeightChange: { editorHeight in
                        onContentHeightChange?(sourceInputHeight(forEditorHeight: editorHeight))
                    }
                )
                .frame(maxHeight: .infinity)
                .background { InteractiveMarker() }
            }

            HStack(spacing: 4) {
                Text(shortcutHint)
                    .font(.popup(name: fontName, size: CGFloat(fontSize - 4)))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(isWindowKey ? 1 : 0.4)

                if offersRichView {
                    Picker("View", selection: $sourceViewMode) {
                        Text("Edit").tag(SourceViewMode.editor)
                        Text("Rich Text").tag(SourceViewMode.rich)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.mini)
                    .labelsHidden()
                    .fixedSize()
                    .help("Switch source view")
                    .background { InteractiveMarker() }
                }

                // Speak + Copy sit on the right, mirroring the provider
                // result card below: same bordered mini buttons, so the
                // speaker icon matches the target side in shape and colour.
                if let ttsCoordinator {
                    let spokenText = MarkdownSupport.speakableText(text)
                    let speaking = ttsCoordinator.isPlaying(spokenText)
                    Button {
                        if speaking {
                            ttsCoordinator.stop()
                        } else {
                            ttsCoordinator.speak(spokenText, language: sourceLanguage)
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: speaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            if sourceLanguage.hasPrefix("en") {
                                Text(ttsAccent.shortLabel)
                            }
                        }
                        .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    // Same minimum width as the Copy button, so the two sit evenly.
                    .frame(minWidth: 56)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Speak source text")
                    .background { InteractiveMarker() }
                }

                // Copy source text (stays in the panel, unlike ⌘↵ Copy & Close).
                Button {
                    copySource()
                } label: {
                    Label(
                        isSourceCopyFeedbackActive ? "Copied" : "Copy",
                        systemImage: isSourceCopyFeedbackActive ? "checkmark" : "doc.on.doc"
                    )
                    .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .frame(minWidth: 56)
                .tint(isSourceCopyFeedbackActive ? .green : nil)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Copy source text")
                .background { InteractiveMarker() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SwapLanguagesShortcut.didChangeNotification)) { _ in
            swapShortcut = SwapLanguagesShortcut.current
        }
    }

    /// Copy the current source text to the pasteboard without closing the
    /// panel (unlike ⌘↵ Copy & Close). Same content as the ⌘↵ path.
    private func copySource() {
        let source = MarkdownSupport.removingAttachmentPlaceholders(text)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(source, forType: .string) else { return }
        isSourceCopyFeedbackActive = true
        sourceCopyFeedbackTask?.cancel()
        sourceCopyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isSourceCopyFeedbackActive = false
        }
    }

    /// The swap shortcut is user-configurable, so the hint shows whatever is currently
    /// bound and drops that segment entirely once the user clears the binding.
    private var shortcutHint: String {
        let base = String(localized: "↵ Translate · ⌘↵ Copy & Close · ⇧↵ Newline")
        guard let swap = swapShortcut else { return base }
        return base + String(localized: " · \(swap.description) Swap")
    }

    private func sourceInputHeight(forEditorHeight editorHeight: CGFloat) -> CGFloat {
        let hintSize = max(CGFloat(fontSize - 4), 8)
        let hintHeight = NSFont.popup(name: fontName, size: hintSize).lineHeight
        return ceil(editorHeight + hintHeight + 8)
    }
}

private struct SourceTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let fontName: String
    let onSubmit: () -> Void
    let onCopyAndClose: () -> Void
    let onSwapLanguages: () -> Void
    let onSelectionChange: ((String?) -> Void)?
    let onWindowKeyChange: (Bool) -> Void
    let onContentHeightChange: (CGFloat) -> Void

    private var resolvedFont: NSFont {
        .popup(name: fontName, size: fontSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textView = SubmitAwareTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.identifier = NSUserInterfaceItemIdentifier(PopupPanelViewIdentifier.sourceInputTextView)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = coordinator
        textView.textContainerInset = .zero
        textView.onSubmit = onSubmit
        textView.onCopyAndClose = onCopyAndClose
        textView.onSwapLanguages = onSwapLanguages
        textView.onWindowKeyChange = onWindowKeyChange
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.applyDisplayAttributes(font: resolvedFont)
        textView.setExternalText(text)

        scrollView.documentView = textView
        coordinator.textView = textView
        coordinator.onContentHeightChange = onContentHeightChange
        coordinator.onSelectionChange = onSelectionChange

        // First-responder is established by `SubmitAwareTextView.viewDidMoveToWindow`
        // (event-driven, no polling). Initial content height is reported here as soon
        // as layout settles.
        Task { @MainActor in
            coordinator.reportContentHeight()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        let coordinator = context.coordinator
        coordinator.onContentHeightChange = onContentHeightChange
        coordinator.onSelectionChange = onSelectionChange
        textView.applyDisplayAttributes(font: resolvedFont)
        textView.updateLayout(for: nsView.contentSize)

        if textView.string != text {
            textView.setExternalText(text)
        }

        textView.onSubmit = onSubmit
        textView.onCopyAndClose = onCopyAndClose
        textView.onSwapLanguages = onSwapLanguages
        textView.onWindowKeyChange = onWindowKeyChange

        coordinator.reportContentHeight()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: SubmitAwareTextView?
        var onContentHeightChange: ((CGFloat) -> Void)?
        var onSelectionChange: ((String?) -> Void)?
        private var lastReportedContentHeight: CGFloat?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? SubmitAwareTextView else { return }
            textView.refreshDisplay()
            text = textView.string
            reportContentHeight()
        }

        /// Reports the selected text (or `nil` for an empty selection) so the
        /// dictionary links can follow the in-panel selection (SPEC §3.2).
        /// Also fires when `setExternalText` moves the cursor to the end with
        /// an empty selection — that resets the lookup to the source text.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? SubmitAwareTextView else { return }
            let range = textView.selectedRange()
            guard range.length > 0 else {
                onSelectionChange?(nil)
                return
            }
            let selected = (textView.string as NSString).substring(with: range)
            onSelectionChange?(selected.isEmpty ? nil : selected)
        }

        func reportContentHeight() {
            guard let textView else { return }
            let height = textView.measuredContentHeight()
            guard lastReportedContentHeight.map({ abs($0 - height) > 0.5 }) ?? true else { return }
            lastReportedContentHeight = height
            let onContentHeightChange = onContentHeightChange
            DispatchQueue.main.async {
                onContentHeightChange?(height)
            }
        }
    }
}

private final class SubmitAwareTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCopyAndClose: (() -> Void)?
    var onSwapLanguages: (() -> Void)?
    var onWindowKeyChange: ((Bool) -> Void)?
    private var displayFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)

    func applyDisplayAttributes(font: NSFont) {
        displayFont = font
        self.font = displayFont
        textColor = .labelColor
        insertionPointColor = .labelColor
        typingAttributes = mergedTypingAttributes()
        selectedTextAttributes = [
            .foregroundColor: NSColor.selectedTextColor,
            .backgroundColor: NSColor.selectedTextBackgroundColor,
        ]
        applyDisplayAttributesToTextStorage()
        refreshDisplay()
    }

    func setExternalText(_ newValue: String) {
        string = newValue
        typingAttributes = mergedTypingAttributes()
        applyDisplayAttributesToTextStorage()
        setSelectedRange(NSRange(location: (newValue as NSString).length, length: 0))
        refreshDisplay()
    }

    func updateLayout(for contentSize: NSSize) {
        minSize = NSSize(width: 0, height: contentSize.height)
        if let textContainer {
            textContainer.containerSize = NSSize(
                width: contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.widthTracksTextView = true
        }
        frame.size.width = contentSize.width
        refreshDisplay()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDisplayAttributes(font: displayFont)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowKeyStatus()
        // Event-driven first responder handoff: when SwiftUI mounts this text view into
        // the panel, consume the panel's one-shot focus request set by `focusSourceInput()`.
        guard let panel = window as? PopupPanel else { return }
        panel.onSwapLanguagesShortcut = { [weak self] event in
            self?.handleSwapLanguagesShortcut(event) ?? false
        }
        panel.consumePendingSourceInputFocus(into: self)
    }

    /// Tracks whether the hosting panel is the key window, so SwiftUI can dim the
    /// shortcut hints when keystrokes would go to another app instead.
    private func observeWindowKeyStatus() {
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        center.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        guard let window else {
            onWindowKeyChange?(false)
            return
        }
        center.addObserver(
            self,
            selector: #selector(reportWindowKeyStatus),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(reportWindowKeyStatus),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
        // Async so the initial report doesn't mutate SwiftUI state mid view update
        Task { @MainActor [weak self] in
            self?.reportWindowKeyStatus()
        }
    }

    @objc private func reportWindowKeyStatus() {
        onWindowKeyChange?(window?.isKeyWindow ?? false)
    }

    private func handleSwapLanguagesShortcut(_ event: NSEvent) -> Bool {
        guard !hasMarkedText(), SwapLanguagesShortcut.matches(event) else { return false }
        if !event.isARepeat {
            onSwapLanguages?()
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        let hasShift = event.modifierFlags.contains(.shift)
        let hasCommand = event.modifierFlags.contains(.command)

        // During IME composition (e.g. Chinese Pinyin), Enter should first commit marked text.
        // Only handle Return shortcuts when composition has ended.
        if isReturnKey, hasCommand, !hasShift, !hasMarkedText() {
            guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            onCopyAndClose?()
            return
        }

        if isReturnKey, !hasCommand, !hasShift, !hasMarkedText() {
            guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }

    private func mergedTypingAttributes() -> [NSAttributedString.Key: Any] {
        var attributes = typingAttributes
        attributes[.font] = displayFont
        attributes[.foregroundColor] = NSColor.labelColor
        return attributes
    }

    private func applyDisplayAttributesToTextStorage() {
        guard let textStorage else { return }
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        if range.length > 0 {
            textStorage.addAttributes(
                [
                    .font: displayFont,
                    .foregroundColor: NSColor.labelColor,
                ],
                range: range
            )
        }
        textStorage.endEditing()
    }

    func refreshDisplay() {
        if let textContainer, let layoutManager {
            layoutManager.ensureLayout(for: textContainer)
        }
        needsDisplay = true
        setNeedsDisplay(bounds)
        enclosingScrollView?.contentView.needsDisplay = true
        enclosingScrollView?.needsDisplay = true
    }

    func measuredContentHeight() -> CGFloat {
        guard let textContainer, let layoutManager else {
            return ceil(displayFont.lineHeight)
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        return ceil(max(displayFont.lineHeight, usedHeight))
    }
}
