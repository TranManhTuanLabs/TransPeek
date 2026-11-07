import Defaults
import SwiftUI

/// OCR settings: engine selection, what happens after OCR, auto-copy, and
/// recognition languages. Wired into Settings by the parent agent.
struct OCRSettingsView: View {
    @Default(.ocrPostMode) private var postMode
    @Default(.ocrAutoCopyTranslation) private var autoCopyTranslation
    @Default(.ocrLanguages) private var ocrLanguages
    // M2+M3: provider selection + Tesseract fallback (disabled by default).
    @Default(.ocrProvider) private var ocrProviderID
    @Default(.ocrTesseractEnabled) private var tesseractEnabled

    @State private var installedTessCodes: [String] = TesseractLanguageDataManager.installedCodes()
    @State private var downloadingCode: String?
    @State private var downloadError: String?

    /// Languages offered for OCR recognition (BCP 47 codes).
    static let availableLanguages: [String] = [
        "vi-VN", "en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE",
    ]

    private var tesseractAvailable: Bool { TesseractOCRProvider.isEngineAvailable }
    private var tesseractStatus: String { TesseractOCRProvider().status }

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "OCR engine"), selection: $ocrProviderID) {
                    Text("Vision (on-device)").tag(OcrProviderID.vision.rawValue)
                    Text("Tesseract (fallback)").tag(OcrProviderID.tesseract.rawValue)
                }
                .disabled(!tesseractAvailable || !tesseractEnabled)
                Text("Vision is the default. Tesseract only runs when it is installed and the fallback below is enabled — pick it here to try it first, with Vision as its fallback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Engine")
            }

            Section {
                Toggle(String(localized: "Enable Tesseract fallback"), isOn: $tesseractEnabled)
                    .disabled(!tesseractAvailable)
                HStack {
                    Text("Status")
                    Spacer()
                    Text(tesseractStatus)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if !tesseractAvailable {
                    Text("Tesseract is not installed on this Mac. Install it with: brew install tesseract tesseract-lang — no app changes needed, TransPeek finds the Homebrew binary automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(["vie", "eng"], id: \.self) { code in
                        HStack {
                            Text(code == "vie" ? "Vietnamese (vie)" : "English (eng)")
                            Spacer()
                            if installedTessCodes.contains(code) {
                                Label("Downloaded", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if downloadingCode == code {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button("Download") {
                                    downloadingCode = code
                                    downloadError = nil
                                    Task {
                                        do {
                                            try await TesseractLanguageDataManager.download(code: code)
                                        } catch {
                                            downloadError = error.localizedDescription
                                        }
                                        downloadingCode = nil
                                        installedTessCodes = TesseractLanguageDataManager.installedCodes()
                                    }
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                    if let downloadError {
                        Text(downloadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Language files download on demand from tessdata_best into Application Support — they are never bundled with the app. Vision vs Tesseract on real Vietnamese photos has not been compared yet: try both on the same photo and keep Vision if it already reads well.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Tesseract (fallback only)")
            }

            Section {
                Picker(String(localized: "Sau OCR"), selection: $postMode) {
                    Text("Mở panel dịch").tag(OCRPostMode.panel)
                    Text("Chỉ copy").tag(OCRPostMode.copyOnly)
                }

                Toggle(String(localized: "Tự động copy bản dịch sau OCR"), isOn: $autoCopyTranslation)
                    .disabled(postMode == .copyOnly)
                Text("Tự động copy sẽ ghi đè nội dung clipboard hiện tại. Chỉ áp dụng khi mở panel dịch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Sau khi chụp màn hình")
            }

            Section {
                ForEach(Self.availableLanguages, id: \.self) { code in
                    Toggle(languageName(for: code), isOn: binding(for: code))
                        // Keep at least one language selected.
                        .disabled(ocrLanguages == [code])
                }
            } header: {
                Text("Ngôn ngữ nhận dạng")
            } footer: {
                Text("Hỗ trợ tiếng Việt phụ thuộc vào phiên bản macOS và được kiểm tra lúc chạy: nếu máy không hỗ trợ tiếng Việt, Vision sẽ chỉ dùng các ngôn ngữ còn lại.")
            }
        }
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
