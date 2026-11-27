import AppKit
import Foundation

// MARK: - HighlightColors

/// Reading indicator highlight colors (Manh 2026-11-27): the 5 layers'
/// colors are user-customizable in Settings (Audio tab → Highlight
/// colors) and stored as "#RRGGBB" hex strings in Defaults. The overlay
/// reads them live at draw time, so a change applies at once — no
/// restart. Opacity stays fixed in code (fills 0.30, line solid 1.0) —
/// the picker never edits it, so a color can never hide the text.
enum HighlightColors {
    /// Default colors — also the "Reset" targets in Settings. Block,
    /// cluster and line keep the pastel palette from the trial (Manh
    /// 2026-11-24 00:38): the hex values are the rounded equivalents of
    /// the RGB values the overlay used before (block 0.75/0.95/0.70,
    /// line 0.55/0.75/1.0), so those defaults look identical to the old
    /// hardcoded colors. The cluster default (Manh 2026-11-27) is light
    /// pink — a preset already in the palette, distinct from the other
    /// four fills — chosen by the parent agent (Manh did not pick a
    /// colour); change it in Settings if another pink reads better.
    /// Word and sentence follow Speechify (Manh 2026-11-27 03:41): the
    /// word is Speechify's highlight50 indigo `#5666F0`, the sentence
    /// is Speechify's highlight30 light periwinkle `#ABB3FE` (NOT
    /// Speechify's sentence `#e0e3ff` — at fill 0.30 that is so pale it
    /// is nearly invisible). Speechify itself draws opaque (1.0) and
    /// recolors the text, but this overlay draws over the page and
    /// cannot recolor the text, so the fills stay translucent (0.30)
    /// and the text underneath stays readable.
    static let lineDefaultHex = "#8CBFFF" // blue nhạt, đặc
    static let blockDefaultHex = "#BFF2B3" // green nhạt
    static let sentenceDefaultHex = "#ABB3FE" // tím nhạt (Speechify highlight30)
    static let wordDefaultHex = "#5666F0" // chàm (Speechify highlight50)
    static let clusterDefaultHex = "#FFC2D1" // hồng nhạt
    /// Fixed opacity for the fills (translucent so the text underneath
    /// stays readable) and the line (solid so it reads as a marker,
    /// not a tint).
    static let fillAlpha: CGFloat = 0.30
    static let lineAlpha: CGFloat = 1.0
    /// Preset swatches shown under each layer in Settings — one shared
    /// palette, any layer can use any color. Tapping a swatch sets that
    /// layer's color at once. The palette holds the 5 layer defaults
    /// plus light orange; the word and sentence swatches are
    /// Speechify's colors (Manh 2026-11-27 03:41), the rest are the
    /// trial pastels.
    static let pastelPresets: [String] = [
        "#8CBFFF", // light blue
        "#BFF2B3", // light green
        "#ABB3FE", // Speechify light periwinkle (sentence default)
        "#5666F0", // Speechify indigo (word default)
        "#FFC2D1", // light pink
        "#FFD9A6", // light orange
    ]

    /// Parse "#RRGGBB" (with or without "#") into RGB components 0...1.
    /// Returns nil for malformed input — the caller falls back to the
    /// layer's default color.
    static func rgb(from hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        return (
            r: CGFloat((value >> 16) & 0xFF) / 255,
            g: CGFloat((value >> 8) & 0xFF) / 255,
            b: CGFloat(value & 0xFF) / 255
        )
    }

    /// Format an NSColor as "#RRGGBB" (uppercase, no alpha — opacity is
    /// fixed in code, never stored).
    static func string(from color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// An NSColor from a hex string + alpha, falling back to
    /// `fallbackHex` when the stored hex is malformed (only possible by
    /// hand-editing UserDefaults — the Settings picker only writes
    /// valid hex).
    static func nsColor(hex: String, alpha: CGFloat, fallbackHex: String) -> NSColor {
        if let rgb = rgb(from: hex) {
            return NSColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
        }
        let fallback = rgb(from: fallbackHex) ?? (r: 0, g: 0, b: 0)
        return NSColor(red: fallback.r, green: fallback.g, blue: fallback.b, alpha: alpha)
    }
}
