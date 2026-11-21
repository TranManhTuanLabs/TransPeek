import Defaults
import SwiftUI

/// OCR settings: what happens after OCR, auto-copy, and recognition languages.
/// Wired into Settings by the parent agent.
struct OCRSettingsView: View {
    @Default(.ocrPostMode) private var postMode
    @Default(.appTextSize) private var appTextSize
    @Default(.ocrAutoCopyTranslation) private var autoCopyTranslation
    @Default(.ocrLanguages) private var ocrLanguages

    /// Languages offered for OCR recognition (BCP 47 codes) — every
    /// language either engine can read (Manh 2026-11-21): Vietnamese and
    /// English first (the defaults), then the rest alphabetically. One
    /// list drives BOTH engines: Vision reads 18 of them, Tesseract reads
    /// 31 (all except Arabic (Najdi) and the two Cantonese variants, which
    /// are Vision-only — Tesseract has no model for them, so the fallback
    /// skips them and reads English instead if Vision fails). A language
    /// Vision doesn't support is still readable: when Vision supports none
    /// of the selected languages, the capture skips straight to Tesseract.
    static let availableLanguages: [String] = [
        "vi-VN", "en-US",
        "ar-SA", "ars-SA", "bg-BG", "cs-CZ", "da-DK", "de-DE", "el-GR",
        "es-ES", "fi-FI", "fr-FR", "he-IL", "hi-IN", "hu-HU", "id-ID",
        "it-IT", "ja-JP", "ko-KR", "ms-MY", "nb-NO", "nl-NL", "pl-PL",
        "pt-BR", "ro-RO", "ru-RU", "sv-SE", "th-TH", "tr-TR", "uk-UA",
        "yue-Hans", "yue-Hant", "zh-Hans", "zh-Hant",
    ]

    /// Whether the Recognition languages list is expanded. Collapsed by
    /// default so 34 languages don't stretch the Settings tab (Manh
    /// 2026-11-21); the collapsed row still shows which languages are
    /// selected.
    @State private var isLanguagesExpanded = false

    /// Pre-download state for the Tesseract section (Apple Silicon only,
    /// Manh 2026-11-21).
    #if arch(arm64)
    @State private var isDownloadingLanguages = false
    @State private var downloadResult: String?
    #endif

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
                // Collapsible card (Manh 2026-11-21): 18 languages would
                // stretch the tab, so the list hides behind a tap — the
                // collapsed row still shows which languages are selected.
                DisclosureGroup(isExpanded: $isLanguagesExpanded) {
                    ForEach(Self.availableLanguages, id: \.self) { code in
                        Toggle(languageName(for: code), isOn: binding(for: code))
                            // Keep at least one language selected.
                            .disabled(ocrLanguages == [code])
                    }
                } label: {
                    Text(selectedLanguagesSummary)
                        .foregroundStyle(.secondary)
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
                // Pre-download (Manh 2026-11-21): download the selected
                // languages' missing data now, while online, so the first
                // OCR doesn't have to wait for a download mid-capture.
                // The capture itself still downloads silently if data is
                // missing — a failed download only drops that language for
                // that one capture; the next capture retries automatically.
                if !missingTesseractCodes.isEmpty {
                    Button("Download missing language data") {
                        downloadMissingLanguages()
                    }
                    .disabled(isDownloadingLanguages)
                }
                if isDownloadingLanguages {
                    ProgressView("Downloading language data…")
                        .controlSize(.small)
                }
                if let downloadResult {
                    Text(downloadResult)
                        .font(.settingsCaption(appTextSize: appTextSize))
                        .foregroundStyle(.secondary)
                }
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

    /// The languages currently selected, for the collapsed row of the
    /// Recognition languages card (e.g. "Vietnamese, English").
    private var selectedLanguagesSummary: String {
        ocrLanguages.map { languageName(for: $0) }.joined(separator: ", ")
    }

    /// Which of the 34 OCR languages Tesseract can already recognise
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

    /// Tesseract codes for the selected languages whose data is neither
    /// bundled with the app nor downloaded yet. These are the only ones
    /// worth pre-downloading — bundled eng + vie never show up here.
    private var missingTesseractCodes: [String] {
        let available = Set(TesseractLanguageDataManager.availableCodes())
        let codes = Set(ocrLanguages.compactMap { TesseractLanguageDataManager.tessCode(forBCP47: $0) })
        return codes.subtracting(available).sorted()
    }

    /// Download the selected languages' missing data now. Runs off the
    /// main actor; the result line tells the user what downloaded and
    /// what failed, and the status above refreshes because this @State
    /// change re-renders the view.
    private func downloadMissingLanguages() {
        let codes = missingTesseractCodes
        guard !codes.isEmpty else { return }
        isDownloadingLanguages = true
        downloadResult = nil
        Task {
            let result = await TesseractLanguageDataManager.downloadMany(codes)
            isDownloadingLanguages = false
            let downloadedNames = result.downloaded.map { languageName(for: TesseractLanguageDataManager.bcp47(forTessCode: $0)) }
            let failedNames = result.failed.map { languageName(for: TesseractLanguageDataManager.bcp47(forTessCode: $0.code)) }
            if failedNames.isEmpty {
                downloadResult = String(localized: "Downloaded: \(downloadedNames.joined(separator: ", ")).")
            } else if downloadedNames.isEmpty {
                downloadResult = String(localized: "Couldn't download: \(failedNames.joined(separator: ", ")). Check your connection and try again.")
            } else {
                downloadResult = String(localized: "Downloaded: \(downloadedNames.joined(separator: ", ")). Couldn't download: \(failedNames.joined(separator: ", ")).")
            }
        }
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
