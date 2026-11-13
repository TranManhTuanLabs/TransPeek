import SwiftUI

extension Font {
    /// Settings description text (the small grey explanations under
    /// settings, e.g. the Appearance note or the Dictionary favicon
    /// note). 2pt smaller than the main Text Size, so it stays smaller
    /// than body text but still scales when the user drags Text Size.
    /// At the default Text Size (14) this is 12pt, the same as .caption.
    /// Plain .caption does not scale with the Text Size setting on
    /// macOS (the explicit base font only affects Text without its own
    /// font, and Dynamic Type is unreliable for Settings Forms), so
    /// description texts use this instead of .caption.
    static func settingsCaption(appTextSize: Int) -> Font {
        .system(size: CGFloat(max(appTextSize - 2, 8)))
    }
}
