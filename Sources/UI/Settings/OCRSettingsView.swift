import Defaults
import SwiftUI

/// OCR settings: what happens after OCR, auto-copy, and recognition languages.
/// Wired into Settings by the parent agent.
struct OCRSettingsView: View {
    @Default(.ocrPostMode) private var postMode
    @Default(.appTextSize) private var appTextSize
    @Default(.appDescriptionTextSize) private var descriptionTextSize
    @Default(.ocrAutoCopyTranslation) private var autoCopyTranslation
    @Default(.ocrLanguages) private var ocrLanguages

    /// Languages offered for OCR recognition (BCP 47 codes).
    static let availableLanguages: [String] = [
        "vi-VN", "en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE",
    ]

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "After OCR"), selection: $postMode) {
                    Text("Open translation panel").tag(OCRPostMode.panel)
                    Text("Copy only").tag(OCRPostMode.copyOnly)
                }

                Toggle(String(localized: "Automatically copy translation after OCR"), isOn: $autoCopyTranslation)
                    .disabled(postMode == .copyOnly)
                Text("Auto-copy will overwrite the current clipboard contents. Only applies when opening the translation panel.")
                    .font(.settingsCaption(descriptionTextSize: descriptionTextSize))
                    .foregroundStyle(.secondary)
            } header: {
                Text("After taking a screenshot")
            }

            Section {
                ForEach(Self.availableLanguages, id: \.self) { code in
                    Toggle(languageName(for: code), isOn: binding(for: code))
                        // Keep at least one language selected.
                        .disabled(ocrLanguages == [code])
                }
            } header: {
                Text("Recognition languages")
            } footer: {
                Text("Vietnamese support depends on the macOS version and is checked at runtime: if the system does not support Vietnamese, Vision will only use the remaining languages.")
            }
        }
        // Same grouped look as the General tab: the plain form style
        // stretches the rows across the whole window, which is what made
        // this tab look bare and off-center.
        .formStyle(.grouped)
        .padding()
    }

    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    private func binding(for code: String) -> Binding<Bool> {
        Binding(
            get: { ocrLanguages.contains(code) },
            set: { isOn in
                if isOn {
                    if !ocrLanguages.contains(code) {
                        ocrLanguages.append(code)
                    }
                } else {
                    // Never leave the list empty.
                    guard ocrLanguages.count > 1 else { return }
                    ocrLanguages.removeAll { $0 == code }
                }
            }
        )
    }
}
