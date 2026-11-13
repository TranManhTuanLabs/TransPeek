import SwiftUI

extension Font {
    /// Settings description text (the small grey explanations under
    /// settings, e.g. the Appearance note or the Dictionary favicon
    /// note). 1pt smaller than the main Text Size, so it stays slightly
    /// smaller than body text but still scales when the user drags Text
    /// Size. At the default Text Size (14) this is 13pt.
    /// Plain .caption (12pt) is too small, so description texts use
    /// this instead of .caption.
    static func settingsCaption(appTextSize: Int) -> Font {
        .system(size: CGFloat(max(appTextSize - 1, 8)))
    }
}
