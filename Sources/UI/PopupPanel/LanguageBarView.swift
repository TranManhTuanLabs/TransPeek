import Defaults
import SwiftUI

/// Language selection bar with source picker + swap + target picker.
struct LanguageBarView: View {
    @Binding var sourceLanguage: String
    let detectedLanguage: String?
    var detectionConfidence: Double?
    @Binding var targetLanguage: String
    let onSwap: () -> Void
    @Default(.popupFontSize) private var fontSize
    @Default(.favoriteTargetLanguages) private var favoriteTargetLanguages

    private var pickerControlSize: ControlSize {
        if fontSize <= 12 { .small }
        else if fontSize <= 16 { .regular }
        else { .large }
    }

    var body: some View {
        // Pickers are intrinsic width and cluster left (Manh 2026-11-15):
        // no maxWidth .infinity on either picker, so widening the panel does
        // not push the target picker + swap button to the right edge — they
        // stay next to the source (Auto Detect) picker on the left.
        HStack(spacing: 8) {
            // Source language picker
            Picker("", selection: $sourceLanguage) {
                Text(autoDetectDisplayName).tag("auto")
                ForEach(SupportedLanguages.all, id: \.code) { code, name in
                    Text(name).tag(code)
                }
            }
            .labelsHidden()
            .controlSize(pickerControlSize)

            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: CGFloat(fontSize - 2)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Target language picker
            Picker("", selection: $targetLanguage) {
                ForEach(
                    SupportedLanguages.targetPickerCodes(
                        favoriteTargetLanguages,
                        selectedTarget: targetLanguage
                    ),
                    id: \.self
                ) { code in
                    Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(code)
                }
            }
            .labelsHidden()
            .controlSize(pickerControlSize)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background { InteractiveMarker() }
    }

    /// Shows a "?" when confidence is above the detection threshold (so a language is returned)
    /// but below this display threshold. Derived from the user's detection threshold to stay in sync.
    private var uncertainDisplayThreshold: Double {
        min(Defaults[.detectionConfidenceThreshold] + 0.3, 0.8)
    }

    private var autoDetectDisplayName: String {
        if sourceLanguage == "auto", let lang = detectedLanguage {
            let name = Locale.current.localizedString(forIdentifier: lang) ?? lang
            if let conf = detectionConfidence, conf < uncertainDisplayThreshold {
                return "\(String(localized: "Auto Detect")) (\(name) ?)"
            }
            return "\(String(localized: "Auto Detect")) (\(name))"
        }
        return String(localized: "Auto Detect")
    }
}
