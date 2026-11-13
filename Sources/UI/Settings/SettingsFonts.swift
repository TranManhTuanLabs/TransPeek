import SwiftUI

extension Font {
    /// Settings description text (the small grey explanations under
    /// settings, e.g. the Appearance note or the Dictionary favicon
    /// note). Uses the Description Text Size setting, adjustable with
    /// its own slider in the Appearance section (below Text Size).
    /// Default 13pt. Plain .caption (12pt) is too small and does not
    /// scale with the Text Size setting on macOS (the explicit base
    /// font only affects Text without its own font, and Dynamic Type
    /// is unreliable for Settings Forms), so description texts use
    /// this instead of .caption.
    static func settingsCaption(descriptionTextSize: Int) -> Font {
        .system(size: CGFloat(max(descriptionTextSize, 8)))
    }
}
