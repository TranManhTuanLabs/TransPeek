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
    // Reading indicator layer visibility (Manh 2026-11-27): each layer
    // has its own Show toggle in its Highlight colors row. The overlay
    // reads them live, so hiding a layer applies at once.
    @Default(.highlightLineShown) private var highlightLineShown
    @Default(.highlightBlockShown) private var highlightBlockShown
    @Default(.highlightSentenceShown) private var highlightSentenceShown
    @Default(.highlightWordShown) private var highlightWordShown
    @Default(.highlightClusterShown) private var highlightClusterShown
    // Which unit the vertical line's height follows (Manh 2026-11-27):
    // the sentence, the paragraph (cluster), or the whole block. The
    // overlay reads it live, so a picker change applies at once.
    @Default(.highlightLineFollows) private var highlightLineFollows
    // Hide the highlight while the page scrolls (Manh 2026-11-27,
    // trial plan phase 2): the overlay reads it live, so flipping it
    // applies at once (the next follow poll re-evaluates).
    @Default(.highlightHideWhileScrolling) private var highlightHideWhileScrolling
    // Underline under the word + sentence being read (Manh
    // 2026-11-27): the 6th layer, with its own color + its own row
    // below. The overlay reads it live, so flipping it applies at
    // once (the next draw shows or hides the underlines). Default ON
    // — the underline reads better than the rectangle fills, whose
    // hard edges look like a border.
    @Default(.highlightUnderlineShown) private var highlightUnderlineShown

    @State private var isLanguageRatesExpanded = false
    @State private var testText = "Hello, 你好世界"
    @State private var testLanguage = "en"
    /// Whether the "Hide highlights while scrolling" info popover is
    /// open (Manh 2026-11-27): the toggle is not a HighlightColorRow,
    /// so it carries its own info state — the same "i" pattern as the
    /// layer rows (one state per popover, only the tapped one opens).
    @State private var showingHideWhileScrollingInfo = false

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

            // Row order (Manh 2026-11-27): Underline first, then the
            // Vertical line, then the fills small → large (Word,
            // Sentence, Cluster, Block) — the narrowest mark on top,
            // the broadest at the bottom.
            Section {
                HighlightColorRow(
                    title: "Underline",
                    subtitle: "Solid bar under the word + sentence being read",
                    infoText: "A thin line under the word and sentence being read, in the underline color. It shows even when the fills are off, so you can use it instead of the fills. No rectangle, so no hard edge.",
                    hex: $highlightUnderlineHex,
                    isShown: $highlightUnderlineShown,
                    defaultHex: HighlightColors.underlineDefaultHex
                )
                HighlightColorRow(
                    title: "Vertical line",
                    subtitle: "Solid bar beside the text — its height follows the unit below",
                    infoText: "A thin vertical bar left of the block, as tall as the unit it follows (see 'Line follows': sentence / paragraph / block). It helps the eye find the unit being read at a glance. How it works: 'Line follows' — Sentence / Paragraph / Block (default Paragraph). Fallback: chosen unit → sentence → cluster, never back to block; if no unit has a frame, no line is drawn. The line still follows the unit even when that unit's fill is hidden.",
                    hex: $highlightLineHex,
                    isShown: $highlightLineShown,
                    defaultHex: HighlightColors.lineDefaultHex,
                    lineFollows: $highlightLineFollows
                )
                HighlightColorRow(
                    title: "Word",
                    subtitle: "Highlight for the word being spoken",
                    infoText: "Highlights the word being spoken. It needs the app to provide the word's position (AXBoundsForRange); if the app does not provide it, the word highlight is skipped.",
                    hex: $highlightWordHex,
                    isShown: $highlightWordShown,
                    defaultHex: HighlightColors.wordDefaultHex
                )
                HighlightColorRow(
                    title: "Sentence",
                    subtitle: "Highlight for the sentence being read",
                    infoText: "Highlights the sentence containing the word being spoken. It needs the app to provide the sentence's position; if the app does not provide it, the sentence highlight is skipped.",
                    hex: $highlightSentenceHex,
                    isShown: $highlightSentenceShown,
                    defaultHex: HighlightColors.sentenceDefaultHex
                )
                HighlightColorRow(
                    title: "Cluster",
                    subtitle: "Highlight for the paragraph (group of sentences) being read",
                    infoText: "Highlights the paragraph containing the current sentence. How it works: the cluster is the paragraph containing the sentence being read. A paragraph is detected by a blank line, a single line break after a sentence ending in `.` / `!` / `?`, or an indented line. A line break after a sentence with no end mark is just a wrapped line, not a new paragraph. An indented line starts with a tab or 2+ spaces (a single space is just the separator between sentences). If the block has no paragraph break, the cluster is not shown — use the block's Show toggle to highlight the whole block.",
                    hex: $highlightClusterHex,
                    isShown: $highlightClusterShown,
                    defaultHex: HighlightColors.clusterDefaultHex
                )
                HighlightColorRow(
                    title: "Block",
                    subtitle: "Highlight for the whole block being read",
                    infoText: "Highlights the whole text block being read. It is always available when a block is detected.",
                    hex: $highlightBlockHex,
                    isShown: $highlightBlockShown,
                    defaultHex: HighlightColors.blockDefaultHex
                )

                // Hide-during-scroll (Manh 2026-11-27, trial plan phase
                // 2): while the page scrolls, the highlight content
                // hides (the window still follows, so it comes back in
                // the right place when the scroll stops). Off keeps the
                // old follow-only behaviour — the highlight stays up
                // while scrolling, which can read as jerkiness. The
                // info button (Manh 2026-11-27) explains it in a
                // popover — the same "i" pattern as the layer rows, so
                // the scroll rule (threshold, reappear timing, no extra
                // AX reads) is visible where the toggle is.
                HStack {
                    Toggle("Hide highlights while scrolling", isOn: $highlightHideWhileScrolling)
                    Button {
                        showingHideWhileScrollingInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .popover(isPresented: $showingHideWhileScrollingInfo) {
                        Text("Hides the highlights while the page scrolls, so they don't jerk. How it works: 'Hide highlights while scrolling' (default ON). While scrolling (block frame moves > 1pt), the fills, line and underline are hidden but the window keeps following; when the frame is stable for 2 polls (~0.6s), the highlights reappear. No extra accessibility reads.")
                            .frame(width: 280, alignment: .leading)
                            .padding()
                    }
                }

                Button("Reset all to default") {
                    highlightUnderlineHex = HighlightColors.underlineDefaultHex
                    highlightLineHex = HighlightColors.lineDefaultHex
                    highlightBlockHex = HighlightColors.blockDefaultHex
                    highlightSentenceHex = HighlightColors.sentenceDefaultHex
                    highlightWordHex = HighlightColors.wordDefaultHex
                    highlightClusterHex = HighlightColors.clusterDefaultHex
                    // Reset all restores the branch defaults (Manh
                    // 2026-11-27): the underline, line, sentence, word
                    // and cluster shown, the block hidden, and the line
                    // following the paragraph (cluster).
                    highlightUnderlineShown = true
                    highlightLineShown = true
                    highlightBlockShown = false
                    highlightSentenceShown = true
                    highlightWordShown = true
                    highlightClusterShown = true
                    highlightLineFollows = HighlightColors.LineFollows.paragraph.rawValue
                }
            } header: {
                Text("Highlight colors")
            } footer: {
                Text("Colors for the reading indicator shown over the page while listening. Changes apply at once — no restart needed. Opacity is fixed so the text underneath stays readable. Turn a layer off with its Show switch to hide it. The vertical line's height follows the unit picked in its row (sentence, paragraph, or block).")
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
/// 2026-11-27): name + native ColorPicker + hex + per-layer Reset, with
/// a preset swatch row underneath — and a Show toggle (Manh 2026-11-27)
/// to hide that one layer without touching its color. The picker never
/// edits opacity (`supportsOpacity: false`) — opacity stays fixed in
/// code (fills 0.30, line + underline solid 1.0), so a color can never
/// hide the text. The hex is display-only (shown for users who want
/// the exact value); the color is picked with the swatch or the system
/// color panel. A small info button ("i", Manh 2026-11-27) after the
/// name + subtitle opens a popover explaining how that layer works
/// and how it is detected — each row has its own text (`infoText`).
private struct HighlightColorRow: View {
    let title: String
    let subtitle: String
    /// Popover text for this layer: how it works + how it is detected
    /// (2–3 sentences, English like the UX doc). Shown by the info
    /// button after the name + subtitle.
    let infoText: String
    @Binding var hex: String
    @Binding var isShown: Bool
    let defaultHex: String
    /// Optional "Line follows" picker (only the Vertical line row has
    /// one — Manh 2026-11-27): which unit the line's height follows
    /// (sentence / paragraph / block). Shown below the presets when
    /// provided; other rows leave it nil.
    var lineFollows: Binding<String>? = nil

    /// Whether this row's info popover is open. Per-row state, so only
    /// the tapped row's popover opens.
    @State private var showingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Info button (Manh 2026-11-27): a small native "i"
                // that explains this layer in a popover — how it works
                // and how it is detected. Plain style + secondary
                // colour so it reads as a hint, not an action; it sits
                // right after the name + subtitle.
                Button {
                    showingInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $showingInfo) {
                    Text(infoText)
                        .frame(width: 280, alignment: .leading)
                        .padding()
                }
                // Colour well + Reset live on the left/middle (Manh
                // 2026-11-27): the right side of the row holds only
                // the hex + Show/Hide label + toggle, grouped close
                // together, so the hex reads as the toggle's value
                // instead of the colour well's. The well still opens
                // the system colour panel; Reset still restores only
                // this layer's default colour.
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                Button("Reset") { hex = defaultHex }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                // Hex + Show/Hide label + toggle as one tight group
                // (Manh 2026-11-27): a nested HStack(spacing: 6) so
                // the hex and the label sit immediately left of the
                // switch and read as one control at the row's right
                // edge — not as loose items drifting toward the
                // middle. Order left to right: hex, label, switch.
                // The label follows the state: "Show" while the layer
                // is on, "Hide" while it is off. Off hides the layer
                // from the overlay (its color is kept, so turning it
                // back on restores the same color). The overlay reads
                // the toggle live, so it applies at once. "Show" and
                // "Hide" are both 4 letters, so the label never shifts
                // the row.
                HStack(spacing: 6) {
                    Text(hex.uppercased())
                        .monospaced()
                        .foregroundStyle(.secondary)
                    Toggle(isShown ? "Show" : "Hide", isOn: $isShown)
                }
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
            // Line follows: which unit the vertical line's height
            // follows. The overlay reads it live, so a tap applies at
            // once (the line narrows to the sentence / paragraph, or
            // stretches back to the whole block).
            if let lineFollows {
                Picker("Line follows", selection: lineFollows) {
                    ForEach(HighlightColors.LineFollows.allCases, id: \.self) { follows in
                        Text(follows.displayName).tag(follows.rawValue)
                    }
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
