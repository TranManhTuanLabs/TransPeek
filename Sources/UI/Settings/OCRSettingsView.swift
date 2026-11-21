import Defaults
import SwiftUI

/// OCR settings: what happens after OCR, auto-copy, and recognition languages.
/// Wired into Settings by the parent agent.
struct OCRSettingsView: View {
    @Default(.ocrPostMode) private var postMode
    @Default(.appTextSize) private var appTextSize
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
                    .font(.settingsCaption(appTextSize: appTextSize))
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

            // Tesseract fallback (Manh 2026-11-20): runs when Vision
            // can't recognise the requested language. English and
            // Vietnamese are built into the app; the other languages
            // download automatically the first time they are needed.
            // Apple Silicon only (Manh 2026-11-21, option B): the
            // Tesseract XCFramework ships arm64 slices only, so this
            // section is hidden on Intel (Vision only there).
            #if arch(arm64)
            Section {
                // Prompt (Manh 2026-11-21): ask which languages the
                // user usually uses OCR for, so they tick them in
                // Recognition languages above — missing data then
                // downloads automatically on first use.
                Text("Which languages do you usually use OCR for? Tick them in Recognition languages above — missing language data downloads automatically.")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
                Text(tesseractStatusText)
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Tesseract fallback")
            } footer: {
                Text("Tesseract runs only when Vision can't handle the request. Languages not listed above download automatically when needed.")
            }
            #endif
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

    /// Which of the 8 OCR languages Tesseract can already recognise
    /// (bundled eng + vie, or already downloaded). The rest download
    /// on demand the first time they are needed. Apple Silicon only
    /// (the Tesseract fallback section is hidden on Intel).
    #if arch(arm64)
    private var tesseractStatusText: String {
        let ready = Self.availableLanguages.filter { code in
            guard let tess = TesseractLanguageDataManager.tessCode(forBCP47: code) else { return false }
            return TesseractLanguageDataManager.availableCodes().contains(tess)
        }
        if ready.isEmpty {
            return String(localized: "No Tesseract language data installed yet.")
        }
        let names = ready.map { languageName(for: $0) }.joined(separator: ", ")
        return String(localized: "Ready: \(names).")
    }
    #endif

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
