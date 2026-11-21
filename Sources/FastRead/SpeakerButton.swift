import AVFoundation
import Defaults
import SwiftUI

/// Speaker (TTS) button for the Fast Read control rows (Window Read and
/// Fast Read Lite). One shared component so the behaviour is identical on
/// both surfaces. The speaker is a TTS on/off toggle FOR the RSVP
/// read-along (Manh 2026-11-21, CI314 fix) — NOT a separate "speak the
/// whole text" action: when TTS is on, Play/Space speaks each slide/line
/// as it shows (the speech drives the advance, so audio and text stay
/// in sync); when off, the read is silent (WPM timer). The icon shows
/// the toggle state — speaker with waves while TTS is on, speaker with
/// a slash while off. Hovering shows a voice picker (English /
/// Vietnamese system voices, the same lists as Settings → TTS) so the
/// reader can pick a voice without leaving the read. Hidden entirely
/// when no TTS coordinator is available (the Rest window does not wire
/// one), so it never shows a dead button.
struct SpeakerButton: View {
    @ObservedObject var viewModel: RSVPViewModel
    @Environment(\.ttsCoordinator) private var ttsCoordinator
    @Default(.ttsVoiceEN) private var ttsVoiceEN
    @Default(.ttsVoiceVI) private var ttsVoiceVI
    // Global TTS speech rate (the same key Settings → TTS uses, so the
    // picker slider and the Settings slider stay in sync). The slider
    // below shows the TRUE speech multiplier (0.6x–4x), not this stored
    // value — see speedMultiplierBinding.
    @Default(.ttsSpeechRate) private var speechRate

    @State private var isHoveringButton = false
    @State private var isHoveringPopover = false
    @State private var showingVoicePicker = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        // No coordinator (Rest window) — no button at all, rather than a
        // button that does nothing.
        if ttsCoordinator != nil {
            Button {
                // Toggle TTS for the read-along (Manh 2026-11-21, CI314
                // fix): the view model restarts playback in the new mode
                // at once, so turning sound on starts speaking the
                // current slide/line and turning it off stops the audio.
                viewModel.toggleTTS()
            } label: {
                Image(systemName: viewModel.ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .buttonStyle(.bordered)
            .help(viewModel.ttsEnabled ? "Turn sound off" : "Turn sound on (read aloud)")
            .hoverTooltip(viewModel.ttsEnabled ? "Turn sound off" : "Turn sound on (read aloud)")
            .onHover { hovering in
                isHoveringButton = hovering
                updateVoicePickerVisibility()
            }
            // Voice picker as a non-modal overlay, NOT a popover (Manh
            // 2026-11-21, CI314 fix): a popover is a separate window
            // that swallows the first click to dismiss itself, so the
            // user had to click the speaker twice (once to dismiss,
            // once to toggle sound). An overlay lives in this same
            // view hierarchy, so it never swallows the button's click
            // — clicking the speaker toggles sound at once while the
            // picker stays open, and the picker never covers the
            // button (it sits above it), so the button stays clickable.
            .overlay(alignment: .bottom) {
                if showingVoicePicker {
                    voicePickerContent
                        .onHover { hovering in
                            isHoveringPopover = hovering
                            updateVoicePickerVisibility()
                        }
                        // Above the button (the control rows sit at the
                        // bottom, so below would fall off the window).
                        // The picker's bottom edge sits just above the
                        // button's top edge; it grows upward, never over
                        // the button, so the button stays clickable.
                        .offset(y: -40)
                }
            }
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
    /// everywhere Apple TTS is used. Drawn as a floating panel (a
    /// material background + border + shadow) because it is an overlay
    /// now, not a popover — the system no longer draws the panel chrome.
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
            Divider()
            // Listening speed, as a slider (Manh 2026-11-21): the reader
            // changes the speed right here, without opening Settings.
            // 0.6x–4x is the TRUE speech multiplier (Apple's ceiling is
            // 4x normal speech); the value is stored in the same
            // ttsSpeechRate key Settings uses, so both stay in sync.
            // It takes effect from the next slide/line — each chunk reads
            // the rate when it starts speaking, so there is no need to
            // restart the read. A per-language override (if the user set
            // one in Settings) still wins for that language.
            HStack {
                Text("Speed")
                Slider(value: speedMultiplierBinding, in: 0.6 ... 4.0, step: 0.1) {
                    Text("Speed")
                }
                .labelsHidden()
                Text(String(format: "%.1fx", speedMultiplierBinding.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(12)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(radius: 8)
    }

    /// Slider binding: the slider shows the TRUE speech multiplier
    /// (0.6x–4x), while the stored `ttsSpeechRate` is the provider rate
    /// AppleTTSProvider multiplies by the default utterance rate. The two
    /// are NOT the same number above 1x (WWDC18: utterance.rate 0.5 = 1x
    /// normal speech, 1.0 = 4x — the scale is 0x→1x over [0, 0.5] and
    /// 1x→4x over [0.5, 1.0]). The conversion keeps the slider honest:
    /// 2.0x on the slider really is twice as fast as 1.0x. A stored rate
    /// outside the slider's range (e.g. 0.1 set in Settings) is clamped
    /// for display; dragging the slider writes a value back in range.
    private var speedMultiplierBinding: Binding<Double> {
        Binding(
            get: { min(max(multiplier(fromStoredRate: speechRate), 0.6), 4.0) },
            set: { speechRate = storedRate(fromMultiplier: $0) }
        )
    }

    /// True speech multiplier for a stored provider rate: the provider
    /// sets utterance.rate = 0.5 × rate, and Apple's scale makes that
    /// rate itself below 1x and 3×rate − 2 above it.
    private func multiplier(fromStoredRate rate: Double) -> Double {
        rate <= 1.0 ? rate : 3.0 * rate - 2.0
    }

    /// Stored provider rate for a true speech multiplier (the inverse of
    /// the above): 0.6x–1x maps 1:1, 1x–4x maps onto 1.0–2.0.
    private func storedRate(fromMultiplier multiplier: Double) -> Double {
        multiplier <= 1.0 ? multiplier : (multiplier + 2.0) / 3.0
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
