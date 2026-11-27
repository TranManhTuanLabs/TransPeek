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
    /// Default colors. Word + sentence follow Speechify (Manh
    /// 2026-11-27): the word is Speechify's `highlight50` indigo
    /// `#5666F0`, the sentence is its `highlight30` light periwinkle
    /// `#ABB3FE`. Speechify's own sentence color is the paler
    /// `highlight20` `#E0E3FF`, but at the overlay's fixed fill
    /// opacity 0.30 that is nearly invisible, so the next step in
    /// its palette is used instead. Block + line keep the pastel
    /// palette from the trial (Manh 2026-11-24 00:38). Also the
    /// "Reset" targets in Settings.
    static let lineDefaultHex = "#8CBFFF" // blue nhạt, đặc
    static let blockDefaultHex = "#BFF2B3" // green nhạt
    static let sentenceDefaultHex = "#ABB3FE" // tím nhạt (Speechify highlight30)
    static let wordDefaultHex = "#5666F0" // chàm (Speechify highlight50)
    /// Default cluster color (Manh 2026-11-27): light pink, from the
    /// preset palette — distinct from the other four fills, so the
    /// paragraph reads as its own level. Chosen by the parent (Manh
    /// did not name a color); changeable in Settings like the rest.
    static let clusterDefaultHex = "#FFC2D1" // hồng nhạt
    /// What the vertical line marks (Manh 2026-11-27): the line's
    /// height can follow the sentence being read, the paragraph
    /// (cluster) around it, or the whole block (the original
    /// behaviour). Stored as its raw string in Defaults; an unknown
    /// stored value falls back to the branch default (paragraph) in
    /// the overlay instead of crashing.
    enum LineFollows: String, CaseIterable {
        case sentence
        case paragraph
        case block
        /// The label shown in the Settings picker.
        var displayName: String {
            switch self {
            case .sentence: return "Sentence"
            case .paragraph: return "Paragraph"
            case .block: return "Block"
            }
        }
    }
    /// Fixed opacity for the fills (translucent so the text underneath
    /// stays readable) and the line (solid so it reads as a marker,
    /// not a tint).
    static let fillAlpha: CGFloat = 0.30
    static let lineAlpha: CGFloat = 1.0
    /// Preset swatches shown under each layer in Settings — the 6
    /// layer colors (line, block, sentence, word, cluster pink,
    /// orange), so any layer can be reset to any of them at a tap.
    /// Tapping a swatch sets that layer's color at once.
    static let pastelPresets: [String] = [
        "#8CBFFF", // light blue
        "#BFF2B3", // light green
        "#ABB3FE", // light periwinkle (Speechify sentence)
        "#5666F0", // indigo (Speechify word)
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
