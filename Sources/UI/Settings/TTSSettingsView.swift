import AVFoundation
import Defaults
import SwiftUI

/// Settings view for TTS configuration: service selection, preferences, and testing.
struct TTSSettingsView: View {
    let registry: TTSProviderRegistry
    let translationRegistry: TranslationProviderRegistry
    let coordinator: TTSCoordinator

    @Default(.ttsProvider) private var selectedProviderID
    @Default(.appTextSize) private var appTextSize
    @Default(.ttsAccent) private var accent
    @Default(.ttsSpeechRate) private var speechRate
    @Default(.ttsAutoPlaySource) private var autoPlaySource
    @Default(.ttsAutoPlayTarget) private var autoPlayTarget
    @Default(.ttsAutoPlayTargetProvider) private var autoPlayTargetProvider
    @Default(.ttsLanguageRates) private var languageRates
    @Default(.ttsVoiceEN) private var ttsVoiceEN
    @Default(.ttsVoiceVI) private var ttsVoiceVI

    // Reading indicator highlight colors (Manh 2026-11-27): the 6
    // layers' colors, stored as "#RRGGBB" hex strings. The overlay
    // reads them live, so a change applies at once.
    @Default(.highlightLineHex) private var highlightLineHex
    @Default(.highlightBlockHex) private var highlightBlockHex
    @Default(.highlightSentenceHex) private var highlightSentenceHex
    @Default(.highlightWordHex) private var highlightWordHex
    @Default(.highlightClusterHex) private var highlightClusterHex
    @Default(.highlightUnderlineHex) private var highlightUnderlineHex
    // Reading indicator layer visibility (Manh 2026-11-27): one Show
    // toggle per layer (in its color row). The overlay reads them
    // live, so toggling applies at once.
    @Default(.highlightLineShown) private var highlightLineShown
    @Default(.highlightBlockShown) private var highlightBlockShown
    @Default(.highlightSentenceShown) private var highlightSentenceShown
    @Default(.highlightWordShown) private var highlightWordShown
    @Default(.highlightClusterShown) private var highlightClusterShown
    @Default(.highlightUnderlineShown) private var highlightUnderlineShown
    // Which unit the vertical line follows (Manh 2026-11-27):
    // "sentence" / "paragraph" / "block". The overlay reads it live,
    // so changing it applies at once.
    @Default(.highlightLineFollows) private var highlightLineFollows
    // Hide the highlight while the page scrolls (Manh 2026-11-27):
    // the overlay reads it live, so flipping it applies at once.
    @Default(.highlightHideWhileScrolling) private var highlightHideWhileScrolling

    @State private var isLanguageRatesExpanded = false
    @State private var testText = "Hello, 你好世界"
    @State private var testLanguage = "en"
    // Info popover for the "Hide highlights while scrolling" toggle
    // (Manh 2026-11-27 16:39): the same "i" button + popover pattern
    // as the layer rows, so the toggle's behaviour is explained in
    // place instead of only in the doc.
    @State private var showHideScrollInfo = false

    var body: some View {
        Form {
            // MARK: - Service Selection

            Section {
                Picker("TTS Service", selection: $selectedProviderID) {
                    ForEach(registry.providers, id: \.id) { provider in
                        HStack(spacing: 6) {
                            Image(systemName: provider.iconSystemName)
                                .frame(width: 16)
                            Text(provider.displayName)
                        }
                        .tag(provider.id)
                    }
                }

                registry.activeProvider.makeSettingsView()
            } header: {
                Text("Service")
            }

            // MARK: - Preferences

            Section {
                Picker("English Accent", selection: $accent) {
                    ForEach(TTSAccent.allCases, id: \.self) { accent in
                        Text(accent.displayName).tag(accent)
                    }
                }

                HStack {
                    Text("Default Speech Rate")
                    Slider(value: $speechRate, in: 0.1 ... 2.0, step: 0.05) {
                        Text("Default Speech Rate")
                    }
                    .labelsHidden()
                    HStack(spacing: 1) {
                        TextField("", value: $speechRate, format: .number.precision(.fractionLength(0...2)))
                            .monospacedDigit()
                            .frame(width: 48)
                            .multilineTextAlignment(.trailing)
                        Text("x")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Auto-play source text", isOn: $autoPlaySource)
                    .onChange(of: autoPlaySource) { _, on in
                        if on { autoPlayTarget = false }
                    }
                Toggle("Auto-play translation result", isOn: $autoPlayTarget)
                    .onChange(of: autoPlayTarget) { _, on in
                        if on { autoPlaySource = false }
                    }
                if autoPlayTarget {
                    Picker("Auto-play provider", selection: $autoPlayTargetProvider) {
                        Text("First completed").tag("first")
                        ForEach(translationRegistry.providers, id: \.id) { provider in
                            Text(provider.displayName).tag(provider.id)
                        }
                    }
                }

                DisclosureGroup(isExpanded: $isLanguageRatesExpanded) {
                    ForEach(SupportedLanguages.all, id: \.code) { lang in
                        let hasOverride = languageRates[lang.code] != nil
                        HStack {
                            Text(lang.name)
                                .frame(width: 80, alignment: .leading)
                            Slider(
                                value: languageRateBinding(for: lang.code),
                                in: 0.1 ... 2.0,
                                step: 0.05
                            )
                            HStack(spacing: 1) {
                                TextField("", value: languageRateBinding(for: lang.code), format: .number.precision(.fractionLength(0...2)))
                                    .monospacedDigit()
                                    .frame(width: 48)
                                    .multilineTextAlignment(.trailing)
                                Text("x")
                                    .foregroundStyle(.secondary)
                            }
                            if hasOverride {
                                Button {
                                    languageRates.removeValue(forKey: lang.code)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reset to default rate")
                            }
                        }
                    }
                } label: {
                    Text("Per-Language Rate")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isLanguageRatesExpanded.toggle() }
                }
            } header: {
                Text("Preferences")
            }

            // MARK: - Voices (EN / VI)

            Section {
                Picker("English voice", selection: $ttsVoiceEN) {
                    Text("System default").tag("")
                    ForEach(englishVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                }

                Picker("Vietnamese voice", selection: $ttsVoiceVI) {
                    Text("System default").tag("")
                    ForEach(vietnameseVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                }

                Text("Applies to Apple TTS. If a chosen voice is no longer installed, the system default voice for that language is used.")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Voices (EN / VI)")
            }

            // MARK: - Highlight colors

            Section {
                // Row order (Manh 2026-11-27 15:57): Underline, Vertical
                // line, then the fills smallest → largest (Word,
                // Sentence, Paragraph, Block) — the narrow marks first,
                // the broad fills last.
                HighlightColorRow(
                    title: "Underline",
                    subtitle: "Underline under the word + sentence being read",
                    info: "A thin line under the word and sentence being read, in the underline color. It shows even when the fills are off, so you can use it instead of the fills. No rectangle, so no hard edge.",
                    hex: $highlightUnderlineHex,
                    shown: $highlightUnderlineShown,
                    defaultHex: HighlightColors.underlineDefaultHex
                )
                HighlightColorRow(
                    title: "Vertical line",
                    subtitle: "Solid bar at the block's left edge",
                    info: "A thin vertical bar left of the block, as tall as the unit it follows (see 'Line follows': sentence / paragraph / block). It helps the eye find the unit being read at a glance.",
                    howItWorks: "'Line follows' — Sentence / Paragraph / Block (default Sentence). Fallback: chosen unit → sentence → cluster, never back to block; if no unit has a frame, no line is drawn. The line still follows the unit even when that unit's fill is hidden.",
                    hex: $highlightLineHex,
                    shown: $highlightLineShown,
                    defaultHex: HighlightColors.lineDefaultHex,
                    lineFollows: $highlightLineFollows
                )
                HighlightColorRow(
                    title: "Word",
                    subtitle: "Highlight for the word being spoken",
                    info: "Highlights the word being spoken. It needs the app to provide the word's position (AXBoundsForRange); if the app does not provide it, the word highlight is skipped.",
                    hex: $highlightWordHex,
                    shown: $highlightWordShown,
                    defaultHex: HighlightColors.wordDefaultHex
                )
                HighlightColorRow(
                    title: "Sentence",
                    subtitle: "Highlight for the sentence being read",
                    info: "Highlights the sentence containing the word being spoken. It needs the app to provide the sentence's position; if the app does not provide it, the sentence highlight is skipped.",
                    hex: $highlightSentenceHex,
                    shown: $highlightSentenceShown,
                    defaultHex: HighlightColors.sentenceDefaultHex
                )
                HighlightColorRow(
                    title: "Paragraph",
                    subtitle: "Highlight for the paragraph (cluster) being read",
                    info: "Highlights the paragraph containing the current sentence. A paragraph is detected by a blank line, a single line break after a sentence ending with . / ! / ?, or an indented line. If the block has no paragraph break, the cluster is not shown — the block has its own Show toggle.",
                    howItWorks: "The cluster is the paragraph containing the sentence being read. A paragraph is detected by a blank line, a single line break after a sentence ending with . / ! / ? (a line break without a terminator is just a wrapped line, not a new paragraph), or an indented line. An indented line means a tab or 2+ spaces at the start of the next sentence; a single space does not count. If the block has no paragraph break, the cluster is not shown — use the block's Show toggle to highlight the whole block.",
                    hex: $highlightClusterHex,
                    shown: $highlightClusterShown,
                    defaultHex: HighlightColors.clusterDefaultHex
                )
                HighlightColorRow(
                    title: "Block",
                    subtitle: "Highlight for the whole block being read",
                    info: "Highlights the whole text block being read. It is always available when a block is detected.",
                    hex: $highlightBlockHex,
                    shown: $highlightBlockShown,
                    defaultHex: HighlightColors.blockDefaultHex
                )

                // Reset all (Manh 2026-11-27 15:57): restores the main
                // defaults for all six layers (colour + Show + the
                // line's unit) — the underline is a layer, so it is
                // reset like the other five. It does not touch the
                // "Hide highlights while scrolling" toggle below: that
                // is a behaviour preference, not a layer default.
                Button("Reset all to default") {
                    highlightUnderlineHex = HighlightColors.underlineDefaultHex
                    highlightLineHex = HighlightColors.lineDefaultHex
                    highlightWordHex = HighlightColors.wordDefaultHex
                    highlightSentenceHex = HighlightColors.sentenceDefaultHex
                    highlightClusterHex = HighlightColors.clusterDefaultHex
                    highlightBlockHex = HighlightColors.blockDefaultHex
                    highlightUnderlineShown = true
                    highlightLineShown = false
                    highlightWordShown = true
                    highlightSentenceShown = false
                    highlightClusterShown = false
                    highlightBlockShown = false
                    highlightLineFollows = "sentence"
                }

                // Hide-during-scroll (Manh 2026-11-27): while the page
                // scrolls the highlight hides until the text stops
                // moving — the window still follows, so it reappears
                // in the right place. Off restores the old follow-only
                // behaviour (the highlight stays while scrolling, and
                // may jerk).
                // Info button (Manh 2026-11-27 16:39): the same native
                // "i" + popover as the layer rows, explaining the
                // toggle and its "How it works" detail in place. The
                // button sits after the toggle (the toggle keeps its
                // full-width layout, switch at the trailing edge), so
                // it does not move the switch.
                HStack {
                    Toggle("Hide highlights while scrolling", isOn: $highlightHideWhileScrolling)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help("Hide the reading highlight while the page scrolls, show it again when the text stops")
                    Button {
                        showHideScrollInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("About hiding highlights while scrolling")
                    .popover(isPresented: $showHideScrollInfo) {
                        // Fixed width + wrapping (Manh 2026-11-27 23:56):
                        // same clipping fix as the layer rows — the old
                        // `.frame(maxWidth: 300)` let the text measure at
                        // its ideal (unwrapped) width and get cut off on
                        // the right. A fixed 300 width plus
                        // `.fixedSize(horizontal: false, vertical: true)`
                        // makes the texts wrap at 300 and grow vertically.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hides the highlights while the page scrolls, so they don't jerk.")
                                .fixedSize(horizontal: false, vertical: true)
                            Text("How it works")
                                .font(.headline)
                            Text("'Hide highlights while scrolling' (default ON). While scrolling (block frame moves > 1pt), the fills, line and underline are hidden but the window keeps following; when the frame is stable for 2 polls (~0.6s), the highlights reappear. No extra accessibility reads.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .frame(width: 300)
                    }
                }
            } header: {
                Text("Highlight colors")
            } footer: {
                Text("Colors for the reading indicator shown over the page while listening. Changes apply at once — no restart needed. Opacity is fixed so the text underneath stays readable. Use the Show switch on each row to hide a layer you don't want. The underline marks the word and sentence being read with a thin solid line under the text, instead of a rectangle fill. The vertical line can follow the sentence, the paragraph, or the whole block — pick it in the line's row.")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
            }

            // MARK: - Test

            Section {
                TextField("Test text", text: $testText, axis: .vertical)
                    .lineLimit(1 ... 3)

                Picker("Language", selection: $testLanguage) {
                    ForEach(SupportedLanguages.all, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }

                HStack(spacing: 12) {
                    if coordinator.isPlaying {
                        Button {
                            coordinator.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .controlSize(.regular)

                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            coordinator.speak(testText, language: testLanguage)
                        } label: {
                            Label("Play Test", systemImage: "play.fill")
                        }
                        .controlSize(.regular)
                        .disabled(testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if case let .error(message) = coordinator.playbackState {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            } header: {
                Text("Test")
            }
        }
        .formStyle(.grouped)
    }

    private func languageRateBinding(for code: String) -> Binding<Double> {
        Binding(
            get: { languageRates[code] ?? speechRate },
            set: { languageRates[code] = $0 }
        )
    }

    /// Installed system voices for a language prefix, in system order.
    private func voices(forLanguagePrefix prefix: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }
    }

    private var englishVoices: [AVSpeechSynthesisVoice] { voices(forLanguagePrefix: "en") }
    private var vietnameseVoices: [AVSpeechSynthesisVoice] { voices(forLanguagePrefix: "vi") }
}

// MARK: - HighlightColorRow

/// One highlight layer's row in the Highlight colors section (Manh
/// 2026-11-27): name + Show/Hide toggle + native ColorPicker + hex +
/// per-layer Reset, with a preset swatch row underneath. The picker
/// never edits opacity (`supportsOpacity: false`) — opacity stays
/// fixed in code (fills 0.30, line + underline solid 1.0), so a color
/// can never hide the text. The hex is display-only (shown for users
/// who want the exact value); the color is picked with the swatch or
/// the system color panel. The Show/Hide switch hides/shows this layer
/// (the overlay reads it live, so it applies at once); the color stays
/// editable while hidden, so the user can set it first and show it
/// after. Its label follows the state — "Show" while the layer is on,
/// "Hide" while it is off (Manh 2026-11-27 16:24) — and it sits in a
/// tight group with the hex value immediately left of the switch
/// ([hex] [Show/Hide] [switch], Manh 2026-11-27 16:26), pushed to the
/// row's right edge by a Spacer (Manh 2026-11-27 21:31), so the hex +
/// label + switch read as one control, separate from the ColorPicker
/// + Reset on the left.
/// A small info button ("i", `info.circle`) right after the layer
/// name (title) opens a popover explaining how this layer works and
/// how it is detected (Manh 2026-11-27 16:21, moved next to the title
/// 2026-11-27 23:56 so it reads as the label's icon and the popover
/// anchors on the row's left). The Vertical line row also
/// carries the "Line follows" picker (Manh 2026-11-27): which unit the
/// line is as tall as — the sentence, the
/// paragraph (cluster) or the whole block. Only that row passes
/// `lineFollows`; the other rows leave it nil and show no picker.
private struct HighlightColorRow: View {
    let title: String
    let subtitle: String
    /// Short explanation shown in the row's info popover (Manh
    /// 2026-11-27 16:21): how this layer works and how it is detected
    /// — 2–3 sentences, English like the UX doc.
    let info: String
    /// Optional "How it works" detail for the row's info popover
    /// (Manh 2026-11-27 16:39): shown under a "How it works" heading
    /// after `info`. Only the Vertical line and Paragraph rows pass
    /// one; the other rows leave it nil and show the explanation
    /// alone.
    var howItWorks: String? = nil
    @Binding var hex: String
    @Binding var shown: Bool
    let defaultHex: String
    var lineFollows: Binding<String>? = nil
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Controls on the title's line, subtitle on its own line
            // below (Manh 2026-11-27 23:58).
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    // "?" right after the layer name ("Underline ?",
                    // Manh 2026-11-27 23:56, option b).
                    HStack(spacing: 4) {
                        Text(title)
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("About this layer")
                        .popover(isPresented: $showInfo) {
                            // Popover layout (Manh 2026-11-27 16:39): the short
                            // explanation first, then — only on rows that pass
                            // one — a "How it works" section with the detail
                            // Manh asked for (the line's fallback, the
                            // cluster's detection). Rows without one show the
                            // explanation alone.
                            // Fixed 300 width + wrapping (Manh 2026-11-27 23:56):
                            // texts wrap at 300 so the full description shows.
                            VStack(alignment: .leading, spacing: 8) {
                                Text(info)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let howItWorks {
                                    Text("How it works")
                                        .font(.headline)
                                    Text(howItWorks)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding()
                            .frame(width: 300)
                        }
                    }
                    // Colour well + Reset stay on the left/centre of the
                    // row (Manh 2026-11-27 21:31): they used to sit after
                    // the hex/Show group, which pushed that group into
                    // the middle of the row — the hex + Show/Hide label
                    // must sit at the row's right edge, immediately left
                    // of the switch, so the well + Reset move here.
                    ColorPicker("", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                    Button("Reset") { hex = defaultHex }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Hex + Show/Hide + switch as one tight group at the
                    // row's right edge (Manh 2026-11-27 16:26, moved to
                    // the edge 2026-11-27 21:31): the hex value and the
                    // dynamic Show/Hide label sit immediately left of the
                    // switch, close together, so they read as one control
                    // — not as loose items next to the ColorPicker. The
                    // Spacer before this group pushes it to the row's
                    // right edge. Order left to right: [hex] [Show/Hide]
                    // [switch].
                    HStack(spacing: 6) {
                        Text(hex.uppercased())
                            .monospaced()
                            .foregroundStyle(.secondary)
                        // Dynamic label (Manh 2026-11-27 16:24): the
                        // toggle's label follows its state — "Show" while
                        // the layer is on, "Hide" while it is off — so it
                        // always says whether the layer is shown or hidden.
                        Toggle(shown ? "Show" : "Hide", isOn: $shown)
                            .help("Show this highlight layer while listening")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Preset swatches: tap one to set this layer's color at
            // once. The current color gets a strong ring so the user
            // can see which preset (if any) is active.
            HStack(spacing: 8) {
                ForEach(HighlightColors.pastelPresets, id: \.self) { preset in
                    Button {
                        hex = preset
                    } label: {
                        Circle()
                            .fill(Color(nsColor: HighlightColors.nsColor(hex: preset, alpha: 1.0, fallbackHex: preset)))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if hex.uppercased() == preset.uppercased() {
                                    Circle().stroke(Color.primary, lineWidth: 2)
                                } else {
                                    Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(preset)
                }
            }
            // Line follows (only the Vertical line row): which unit the
            // line is as tall as. A segmented picker — one tap, no menu
            // — because there are only three choices. The overlay reads
            // the value live, so it applies at once, even mid-speech;
            // when the chosen unit has no frame (the app did not expose
            // its bounds) the line falls back to the sentence, then the
            // paragraph; if none has a frame there is no line (the
            // block is only a chosen unit, never a fallback).
            if let lineFollows {
                Picker("Line follows", selection: lineFollows) {
                    Text("Sentence").tag("sentence")
                    Text("Paragraph").tag("paragraph")
                    Text("Block").tag("block")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// The picker's Color binding: the stored hex is opaque (alpha 1.0
    /// for the picker — the overlay applies its own fixed alpha at draw
    /// time), and a picked color is stored back as "#RRGGBB".
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: HighlightColors.nsColor(hex: hex, alpha: 1.0, fallbackHex: defaultHex)) },
            set: { hex = HighlightColors.string(from: NSColor($0)) }
        )
    }
}
