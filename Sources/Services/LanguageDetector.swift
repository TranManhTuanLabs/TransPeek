import NaturalLanguage

struct DetectionResult: Sendable {
    let language: String?
    let confidence: Double
    let isReliable: Bool
}

enum LanguageDetector {
    // Detection does NOT set languageConstraints. The full 250-language
    // catalog (0.1.5) broke Polish detection (CI #249, #250, #251):
    // stuffing 250 constraints (many the framework doesn't support)
    // into the recognizer made it fall back to English, then
    // Indonesian, for clearly Polish text. Restricting to 2-letter
    // codes (edb0b4a) did NOT fix it either — the set was still ~100
    // languages, many unsupported for recognition. Lowering the
    // English hint 2.0 -> 1.0 was tried (dc700fb) and did NOT fix it.
    // The framework's recognizer is most accurate with NO constraints:
    // it then uses its full built-in model over the languages it
    // actually supports (~60 major languages, all in the 250 catalog).
    // languageHints below still bias it toward common languages.
    // Only the Polish detection test depends on this; the other
    // LanguagePreferencesTests test the catalog/mappings, not detection.

    // Base language weight hints (inspired by Easydict, simplified)
    private static let baseHints: [NLLanguage: Double] = [
        .english: 2.0,
        .simplifiedChinese: 1.5,
        .traditionalChinese: 0.8,
        .japanese: 0.6,
        .korean: 0.5,
        .french: 0.4, .spanish: 0.4, .italian: 0.4,
        .portuguese: 0.3, .german: 0.3, .russian: 0.3,
        .arabic: 0.2, .thai: 0.2, .vietnamese: 0.2,
        NLLanguage(rawValue: "pl"): 0.2,
        NLLanguage(rawValue: "nl"): 0.2,
        NLLanguage(rawValue: "tr"): 0.2,
        NLLanguage(rawValue: "uk"): 0.2,
        NLLanguage(rawValue: "id"): 0.2,
        NLLanguage(rawValue: "sv"): 0.2,
    ]

    /// Backward-compatible simple API.
    static func detect(_ text: String) -> String? {
        detectWithConfidence(text, threshold: 0.3).language
    }

    /// Full detection API with confidence and alternatives.
    /// `preferredSourceHints` uses BCP 47 codes as keys (e.g. "en", "zh-Hans").
    static func detectWithConfidence(
        _ text: String,
        threshold: Double = 0.3,
        preferredSourceHints: [String: Double]? = nil
    ) -> DetectionResult {
        let recognizer = NLLanguageRecognizer()
        // No languageConstraints (see the comment above): the
        // recognizer uses its full built-in model.

        // Merge base hints + user preference hints
        var hints = baseHints
        if let extra = preferredSourceHints {
            for (code, weight) in extra {
                if let nlLang = bcp47ToNLLanguage(code) {
                    hints[nlLang, default: 0] += weight
                }
            }
        }
        recognizer.languageHints = hints

        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        let sorted = hypotheses
            .map { (language: mapToBCP47($0.key), confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        guard let best = sorted.first else {
            return DetectionResult(language: nil, confidence: 0, isReliable: false)
        }

        // Use higher threshold for very short text
        let effectiveThreshold = text.count <= 5
            ? max(threshold, 0.5)
            : threshold

        let isReliable = best.confidence >= effectiveThreshold

        return DetectionResult(
            language: isReliable ? best.language : nil,
            confidence: best.confidence,
            isReliable: isReliable
        )
    }

    private static func bcp47ToNLLanguage(_ code: String) -> NLLanguage? {
        switch code {
        case "zh-Hans": return .simplifiedChinese
        case "zh-Hant": return .traditionalChinese
        case "pt", "pt-BR", "pt-PT": return .portuguese
        default:
            // Strip script/region subtags ("fa-AF" -> "fa",
            // "crh-Latn" -> "crh", "ms-Arab" -> "ms"): the framework
            // only knows base languages, and a subtagged value isn't a
            // real NLLanguage the recognizer can use.
            let base = code.split(separator: "-", maxSplits: 1).first.map(String.init) ?? code
            return NLLanguage(rawValue: base)
        }
    }

    private static func mapToBCP47(_ language: NLLanguage) -> String {
        switch language {
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .portuguese: return "pt-BR"
        default: return language.rawValue
        }
    }
}
