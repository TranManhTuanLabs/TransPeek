import Defaults
import SwiftUI

/// OCR settings: what happens after OCR, auto-copy, and recognition languages.
/// Wired into Settings by the parent agent.
struct OCRSettingsView: View {
    @Default(.ocrPostMode) private var postMode
    @Default(.ocrAutoCopyTranslation) private var autoCopyTranslation
    @Default(.ocrLanguages) private var ocrLanguages

    /// Languages offered for OCR recognition (BCP 47 codes).
    static let availableLanguages: [String] = [
        "vi-VN", "en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE",
    ]

    var body: some View {
        Form {
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
