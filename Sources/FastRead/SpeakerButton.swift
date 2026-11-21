import AVFoundation
import Defaults
import SwiftUI

/// Speaker (TTS) button for the Fast Read control rows (Window Read and
/// Fast Read Lite). One shared component so the behaviour is identical on
/// both surfaces: click speaks the reading text aloud right away (via the
/// shared TTSCoordinator), click again stops it. The icon shows the
/// state — speaker with waves while speaking, speaker with a slash while
/// muted/stopped. Hovering shows a voice picker (English / Vietnamese
/// system voices, the same lists as Settings → TTS) so the reader can
/// pick a voice without leaving the read. Hidden entirely when no TTS
/// coordinator is available (the Rest window does not wire one), so it
/// never shows a dead button.
struct SpeakerButton: View {
    @ObservedObject var viewModel: RSVPViewModel
    @Environment(\.ttsCoordinator) private var ttsCoordinator
    @Default(.ttsVoiceEN) private var ttsVoiceEN
    @Default(.ttsVoiceVI) private var ttsVoiceVI

    @State private var isHoveringButton = false
    @State private var isHoveringPopover = false
    @State private var showingVoicePicker = false
    @State private var dismissTask: Task<Void, Never>?

    /// True while this exact text is being spoken (scoped per-button, so
    /// speech started elsewhere — e.g. the translate tab auto-play —
    /// does not light this button up).
    private var isSpeaking: Bool {
        guard let tts = ttsCoordinator else { return false }
        return tts.isPlaying(viewModel.text)
    }

    var body: some View {
        // No coordinator (Rest window) — no button at all, rather than a
        // button that does nothing.
        if let tts = ttsCoordinator {
            Button {
                toggleSpeak(using: tts)
            } label: {
                Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .buttonStyle(.bordered)
            .help(isSpeaking ? "Stop speaking" : "Speak (read aloud)")
            .hoverTooltip(isSpeaking ? "Stop speaking" : "Speak (read aloud)")
            .onHover { hovering in
                isHoveringButton = hovering
                updateVoicePickerVisibility()
            }
            .popover(isPresented: $showingVoicePicker) {
                voicePickerContent
                    .onHover { hovering in
                        isHoveringPopover = hovering
                        updateVoicePickerVisibility()
                    }
            }
        }
    }

    /// Click toggles speech for this read: stop if this text is already
    /// being spoken, otherwise speak the whole text at once.
    private func toggleSpeak(using tts: TTSCoordinator) {
        if tts.isPlaying(viewModel.text) {
            tts.stop()
        } else {
            tts.speak(viewModel.text, language: viewModel.speakLanguage)
        }
    }

    /// Keep the voice picker open while the mouse is on the button or on
    /// the picker itself; close it shortly after leaving both, so moving
    /// from the button into the picker does not flicker it shut mid-move.
    private func updateVoicePickerVisibility() {
        dismissTask?.cancel()
        if isHoveringButton || isHoveringPopover {
            showingVoicePicker = true
        } else {
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if !isHoveringButton && !isHoveringPopover {
                    showingVoicePicker = false
                }
            }
        }
    }

    /// Voice picker (English / Vietnamese), the same lists and the same
    /// stored keys as Settings → TTS, so picking here changes the voice
    /// everywhere Apple TTS is used.
    private var voicePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice")
                .font(.headline)
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
            Text("Applies to Apple TTS.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 260)
    }

    /// Installed system voices for a language prefix, in system order —
    /// the same source as Settings → TTS, so the two lists can never drift.
    private func voices(forLanguagePrefix prefix: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }
    }

    private var englishVoices: [AVSpeechSynthesisVoice] { voices(forLanguagePrefix: "en") }
    private var vietnameseVoices: [AVSpeechSynthesisVoice] { voices(forLanguagePrefix: "vi") }
}
