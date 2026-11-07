import AVFoundation
import Defaults
import SwiftUI

/// Settings view for TTS configuration: service selection, preferences, and testing.
struct TTSSettingsView: View {
    let registry: TTSProviderRegistry
    let translationRegistry: TranslationProviderRegistry
    let coordinator: TTSCoordinator

    @Default(.ttsProvider) private var selectedProviderID
    @Default(.ttsAccent) private var accent
    @Default(.ttsSpeechRate) private var speechRate
    @Default(.ttsAutoPlaySource) private var autoPlaySource
    @Default(.ttsAutoPlayTarget) private var autoPlayTarget
    @Default(.ttsAutoPlayTargetProvider) private var autoPlayTargetProvider
    @Default(.ttsLanguageRates) private var languageRates
    @Default(.ttsVoiceEN) private var ttsVoiceEN
    @Default(.ttsVoiceVI) private var ttsVoiceVI
    // M2+M3: autoswitch (develop, OFF), Edge voices, extra System voices.
    @Default(.ttsAutoswitchEnabled) private var autoswitchEnabled
    @Default(.edgeVoiceByLanguage) private var edgeVoices
    @Default(.ttsVoiceByLanguage) private var extraVoices

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

                Text("Applies to System (Apple TTS). If a chosen voice is no longer installed, the system default voice for that language is used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Voices (EN / VI)")
            }

            // MARK: - More System voices (any installed OS language)

            Section {
                ForEach(extraVoicePrefixes, id: \.self) { prefix in
                    HStack {
                        Picker(languageName(for: prefix), selection: extraVoiceBinding(for: prefix)) {
                            Text("System default").tag("")
                            ForEach(voices(forLanguagePrefix: prefix), id: \.identifier) { voice in
                                Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                            }
                        }
                        Button {
                            var map = extraVoices
                            map.removeValue(forKey: prefix)
                            extraVoices = map
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove this language")
                    }
                }

                Picker("Add language", selection: $languageToAdd) {
                    Text("Add a language…").tag("")
                    ForEach(addableVoicePrefixes, id: \.self) { prefix in
                        Text(languageName(for: prefix)).tag(prefix)
                    }
                }
                .disabled(addableVoicePrefixes.isEmpty)
                .onChange(of: languageToAdd) { _, prefix in
                    guard !prefix.isEmpty else { return }
                    var map = extraVoices
                    map[prefix] = ""
                    extraVoices = map
                    languageToAdd = ""
                }

                Text("Voices installed on this Mac, beyond English and Vietnamese. The list comes from the OS — nothing is hardcoded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("More languages (System)")
            }

            // MARK: - Edge TTS voices (shown when Edge is the active provider)

            if selectedProviderID == EdgeTTSProvider.providerID {
                Section {
                    Picker("English voice", selection: edgeVoiceBinding(for: "en")) {
                        Text("Edge default (Aria)").tag("")
                        ForEach(edgeCatalogVoices(forLanguagePrefix: "en"), id: \.name) { voice in
                            Text("\(voice.name) (\(voice.locale))").tag(voice.name)
                        }
                    }
                    Picker("Vietnamese voice", selection: edgeVoiceBinding(for: "vi")) {
                        Text("Edge default (Hoài My)").tag("")
                        ForEach(edgeCatalogVoices(forLanguagePrefix: "vi"), id: \.name) { voice in
                            Text("\(voice.name) (\(voice.locale))").tag(voice.name)
                        }
                    }
                    Text("Free neural voices, no API key. If Edge fails or rate-limits, TransPeek falls back to System TTS automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Edge voices (EN / VI)")
                }
            }

            // MARK: - Autoswitch (develop, OFF by default)

            Section {
                Toggle("Autoswitch voice by detected language", isOn: $autoswitchEnabled)
                Text("Experimental: when on, the voice follows the language detected in the text instead of the language you asked for. Short text is often mis-detected, so this stays off unless you turn it on. Fallback: engine voice for the language → System voice for the language → English voice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Voice autoswitch (experimental)")
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

    @State private var languageToAdd = ""

    /// 2-letter prefixes of installed OS voices, excluding EN/VI (covered above).
    private var installedVoicePrefixes: [String] {
        Array(Set(
            AVSpeechSynthesisVoice.speechVoices().map { String($0.language.prefix(2)).lowercased() }
        )).sorted()
    }

    /// Prefixes the user already added an extra voice for, in map order.
    private var extraVoicePrefixes: [String] {
        extraVoices.keys.sorted()
    }

    /// Installed prefixes not yet added (EN/VI excluded — they have their own pickers).
    private var addableVoicePrefixes: [String] {
        installedVoicePrefixes.filter { $0 != "en" && $0 != "vi" && extraVoices[$0] == nil }
    }

    private func languageName(for prefix: String) -> String {
        Locale.current.localizedString(forIdentifier: prefix) ?? prefix
    }

    private func extraVoiceBinding(for prefix: String) -> Binding<String> {
        Binding(
            get: { extraVoices[prefix] ?? "" },
            set: { newValue in
                var map = extraVoices
                map[prefix] = newValue
                extraVoices = map
            }
        )
    }

    /// Edge catalog voices for a language prefix (locale starts with prefix).
    private func edgeCatalogVoices(forLanguagePrefix prefix: String) -> [EdgeVoiceSelection] {
        EdgeTTSVoiceResolver.catalog.filter { $0.locale.lowercased().hasPrefix(prefix) }
    }

    private func edgeVoiceBinding(for prefix: String) -> Binding<String> {
        Binding(
            get: { edgeVoices[prefix] ?? "" },
            set: { newValue in
                var map = edgeVoices
                map[prefix] = newValue
                edgeVoices = map
            }
        )
    }
}
