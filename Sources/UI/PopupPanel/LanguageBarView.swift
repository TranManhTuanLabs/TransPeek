import Defaults
import SwiftUI

/// Language selection bar with source picker + swap + target picker.
/// Both pickers are searchable dropdowns (Manh 2026-11-19, 0.1.5):
/// a button showing the current language, opening a floating popover
/// with a searchable list (Popular 20 first, then all languages A-Z).
/// The old native `Picker` showed all 249 languages as one long menu —
/// unusable at this size. Native Popover + List + an explicit search TextField, no
/// NSComboBox, no custom dropdown.
struct LanguageBarView: View {
    @Binding var sourceLanguage: String
    let detectedLanguage: String?
    var detectionConfidence: Double?
    @Binding var targetLanguage: String
    let onSwap: () -> Void
    /// Tracks the picker's popover window so the dismiss monitor treats
    /// clicks in it as clicks inside the panel.
    let popoverTracker: LanguagePopoverTracker
    @Default(.popupFontSize) private var fontSize
    @Default(.favoriteTargetLanguages) private var favoriteTargetLanguages

    var body: some View {
        // Pickers are intrinsic width and cluster left (Manh 2026-11-15):
        // no maxWidth .infinity on either picker, so widening the panel does
        // not push the target picker + swap button to the right edge — they
        // stay next to the source (Auto Detect) picker on the left.
        HStack(spacing: 8) {
            // Source language picker (Auto Detect + all languages)
            SearchableLanguagePicker(
                selection: $sourceLanguage,
                leadingOption: (code: "auto", label: autoDetectDisplayName),
                displayName: { code in
                    code == "auto" ? autoDetectDisplayName : SupportedLanguages.nativeName(for: code)
                },
                popoverTracker: popoverTracker
            )
            .panelHoverHighlight()

            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: CGFloat(fontSize - 2)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .panelHoverHighlight()

            // Target language picker
            SearchableLanguagePicker(
                selection: $targetLanguage,
                popoverTracker: popoverTracker
            )
            .panelHoverHighlight()
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
