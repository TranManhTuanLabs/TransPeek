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

    // Reading indicator highlight colors (Manh 2026-11-27): the 5
    // layers' colors, stored as "#RRGGBB" hex strings. The overlay
    // reads them live, so a change applies at once.
    @Default(.highlightLineHex) private var highlightLineHex
    @Default(.highlightBlockHex) private var highlightBlockHex
    @Default(.highlightSentenceHex) private var highlightSentenceHex
    @Default(.highlightWordHex) private var highlightWordHex
    @Default(.highlightClusterHex) private var highlightClusterHex
    // Reading indicator layer visibility (Manh 2026-11-27): one Show
    // toggle per layer (in its color row). The overlay reads them
    // live, so toggling applies at once.
    @Default(.highlightLineShown) private var highlightLineShown
    @Default(.highlightBlockShown) private var highlightBlockShown
    @Default(.highlightSentenceShown) private var highlightSentenceShown
    @Default(.highlightWordShown) private var highlightWordShown
    @Default(.highlightClusterShown) private var highlightClusterShown
    // Which unit the vertical line follows (Manh 2026-11-27):
    // "sentence" / "paragraph" / "block". The overlay reads it live,
    // so changing it applies at once.
    @Default(.highlightLineFollows) private var highlightLineFollows

    @State private var isLanguageRatesExpanded = false
    @State private var testText = "Hello, 你好世界"
    @State private var testLanguage = "en"

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
                HighlightColorRow(
                    title: "Vertical line",
                    subtitle: "Solid bar at the block's left edge",
                    hex: $highlightLineHex,
                    shown: $highlightLineShown,
                    defaultHex: HighlightColors.lineDefaultHex,
                    lineFollows: $highlightLineFollows
                )
                HighlightColorRow(
                    title: "Block",
                    subtitle: "Highlight for the whole block being read",
                    hex: $highlightBlockHex,
                    shown: $highlightBlockShown,
                    defaultHex: HighlightColors.blockDefaultHex
                )
                HighlightColorRow(
                    title: "Paragraph",
                    subtitle: "Highlight for the paragraph (cluster) being read",
                    hex: $highlightClusterHex,
                    shown: $highlightClusterShown,
                    defaultHex: HighlightColors.clusterDefaultHex
                )
                HighlightColorRow(
                    title: "Sentence",
                    subtitle: "Highlight for the sentence being read",
                    hex: $highlightSentenceHex,
                    shown: $highlightSentenceShown,
                    defaultHex: HighlightColors.sentenceDefaultHex
                )
                HighlightColorRow(
                    title: "Word",
                    subtitle: "Highlight for the word being spoken",
                    hex: $highlightWordHex,
                    shown: $highlightWordShown,
                    defaultHex: HighlightColors.wordDefaultHex
                )

                Button("Reset all to default") {
                    highlightLineHex = HighlightColors.lineDefaultHex
                    highlightBlockHex = HighlightColors.blockDefaultHex
                    highlightClusterHex = HighlightColors.clusterDefaultHex
                    highlightSentenceHex = HighlightColors.sentenceDefaultHex
                    highlightWordHex = HighlightColors.wordDefaultHex
                }
            } header: {
                Text("Highlight colors")
            } footer: {
                Text("Colors for the reading indicator shown over the page while listening. Changes apply at once — no restart needed. Opacity is fixed so the text underneath stays readable. Use the Show switch on each row to hide a layer you don't want. The vertical line can follow the sentence, the paragraph, or the whole block — pick it in the line's row.")
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
/// 2026-11-27): name + Show toggle + native ColorPicker + hex +
/// per-layer Reset, with a preset swatch row underneath. The picker
/// never edits opacity (`supportsOpacity: false`) — opacity stays
/// fixed in code (fills 0.30, line solid 1.0), so a color can never
/// hide the text. The hex is display-only (shown for users who want
/// the exact value); the color is picked with the swatch or the system
/// color panel. The Show switch hides/shows this layer (the overlay
/// reads it live, so it applies at once); the color stays editable
/// while hidden, so the user can set it first and show it after. The
/// Vertical line row also carries the "Line follows" picker (Manh
/// 2026-11-27): which unit the line is as tall as — the sentence, the
/// paragraph (cluster) or the whole block. Only that row passes
/// `lineFollows`; the other rows leave it nil and show no picker.
private struct HighlightColorRow: View {
    let title: String
    let subtitle: String
    @Binding var hex: String
    @Binding var shown: Bool
    let defaultHex: String
    var lineFollows: Binding<String>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(hex.uppercased())
                    .monospaced()
                    .foregroundStyle(.secondary)
                Toggle("Show", isOn: $shown)
                    .help("Show this highlight layer while listening")
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                Button("Reset") { hex = defaultHex }
                    .buttonStyle(.plain)
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
            // its bounds) the line falls back to the whole block.
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
