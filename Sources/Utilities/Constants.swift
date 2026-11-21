import AppKit
import Defaults
import Foundation
import KeyboardShortcuts

// MARK: - Supported Languages

/// Languages available throughout the app. Individual providers can support a subset.
enum SupportedLanguages {
    /// The default target list (favorites for new users). Order: Vietnamese
    /// first, then English, then Chinese, then the rest — set 2026-11-16
    /// (Manh: prioritize Vietnamese) because the app is for Vietnamese users
    /// learning English, translating English text into Vietnamese.
    static let defaultTargetCodes: [String] = [
        "vi", "en", "zh-Hans", "zh-Hant", "ja", "ko",
        "fr", "de", "es", "pt-BR", "ru", "ar", "it", "th",
    ]

    /// The 20 popular target languages, in the exact order Manh set
    /// (2026-11-19, 0.1.5) — shown first in the language dropdown.
    /// `pt` is the generic-Portuguese alias (not in Google's 249 list,
    /// which has `pt-BR` and `pt-PT`); it maps to `pt` for Google.
    static let popularTargetCodes: [String] = [
        "en", "vi", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "pt",
        "ru", "it", "th", "ar", "hi", "id", "tr", "nl", "pl", "uk",
    ]

    /// Full catalog: all 249 Google Translate languages + the `pt` alias,
    /// sorted by English name A-Z. Each entry: (code, native name, English name).
    /// Source: verified against Wikipedia (249), Google Cloud NMT table,
    /// google-translate-api-x languages.cjs — see docs (Manh 2026-11-19, 0.1.5).
    static let allLanguages: [(code: String, nativeName: String, englishName: String)] = [
        ("ab", "Аԥсшәа", "Abkhaz"),
        ("ace", "Bahsa Acèh", "Acehnese"),
        ("ach", "Acholi", "Acholi"),
        ("aa", "Qafaraf", "Afar"),
        ("af", "Afrikaans", "Afrikaans"),
        ("sq", "Shqip", "Albanian"),
        ("alz", "Lur", "Alur"),
        ("am", "አማርኛ", "Amharic"),
        ("ar", "العربية", "Arabic"),
        ("hy", "հայերեն", "Armenian"),
        ("as", "অসমীয়া", "Assamese"),
        ("av", "МагӀарул мацӀ", "Avar"),
        ("awa", "अवधी", "Awadhi"),
        ("ay", "Aymar aru", "Aymara"),
        ("az", "Azərbaycan dili", "Azerbaijani"),
        ("ban", "ᬩᬲᬩᬮᬶ", "Balinese"),
        ("bal", "Balóchí", "Baluchi"),
        ("bm", "Bamanankan", "Bambara"),
        ("bci", "Wawle", "Baoulé"),
        ("ba", "Башҡортса", "Bashkir"),
        ("eu", "Euskara", "Basque"),
        ("btx", "Batak Karo", "Batak Karo"),
        ("bts", "Bahasa Simalungun", "Batak Simalungun"),
        ("bbc", "Hata Batak", "Batak Toba"),
        ("be", "Беларуская", "Belarusian"),
        ("bem", "Ichibemba", "Bemba"),
        ("bn", "বাংলা", "Bengali"),
        ("bew", "Basa Betawi", "Betawi"),
        ("bho", "भोजपुरी", "Bhojpuri"),
        ("bik", "Sentral Bikol", "Bikol"),
        ("bs", "Bosanski", "Bosnian"),
        ("br", "Brezhoneg", "Breton"),
        ("bg", "Български", "Bulgarian"),
        ("bua", "Буряад хэлэн", "Buryat"),
        ("yue", "粵語", "Cantonese"),
        ("ca", "Català", "Catalan"),
        ("ceb", "Bisaya", "Cebuano"),
        ("ch", "Chamorru", "Chamorro"),
        ("ce", "Нохчийн мотт", "Chechen"),
        ("ny", "Chichewa", "Chichewa"),
        ("zh-Hans", "中文 (简体)", "Chinese (Simplified)"),
        ("zh-Hant", "中文 (繁體)", "Chinese (Traditional)"),
        ("chk", "Fóósun Chuuk", "Chuukese"),
        ("cv", "Чăваш чĕлхи", "Chuvash"),
        ("co", "Corsu", "Corsican"),
        ("crh", "Къырымтатар тили", "Crimean Tatar (Cyrillic)"),
        ("crh-Latn", "Qırımtatar tili", "Crimean Tatar (Latin)"),
        ("hr", "Hrvatski", "Croatian"),
        ("cs", "Čeština", "Czech"),
        ("da", "Dansk", "Danish"),
        ("fa-AF", "دری", "Dari"),
        ("dv", "ދިވެހިބަސް", "Dhivehi"),
        ("din", "Thuɔŋjäŋ", "Dinka"),
        ("doi", "डोगरी", "Dogri"),
        ("dov", "ChiDombe", "Dombe"),
        ("nl", "Nederlands", "Dutch"),
        ("dyu", "Julakan", "Dyula"),
        ("dz", "རྫོང་ཁ་", "Dzongkha"),
        ("en", "English", "English"),
        ("eo", "Esperanto", "Esperanto"),
        ("et", "Eesti keel", "Estonian"),
        ("ee", "Eʋegbe", "Ewe"),
        ("fo", "Føroyskt mál", "Faroese"),
        ("fj", "Vosa Vakaviti", "Fijian"),
        ("tl", "Filipino", "Filipino"),
        ("fi", "Suomi", "Finnish"),
        ("fon", "Fɔ̀ngbè", "Fon"),
        ("fr", "Français", "French"),
        ("fr-CA", "Français (Canada)", "French (Canada)"),
        ("fy", "West-Frysk", "Frisian"),
        ("fur", "Furlan", "Friulian"),
        ("ff", "Fulfulde", "Fulani"),
        ("gaa", "Gã", "Ga"),
        ("gl", "Galego", "Galician"),
        ("ka", "ქართული", "Georgian"),
        ("de", "Deutsch", "German"),
        ("el", "Ελληνικά", "Greek"),
        ("gn", "Avañe'ẽ", "Guarani"),
        ("gu", "ગુજરાતી", "Gujarati"),
        ("ht", "Kreyòl ayisyen", "Haitian Creole"),
        ("cnh", "Laica", "Hakha Chin"),
        ("ha", "Hausa", "Hausa"),
        ("haw", "‘Ōlelo Hawai‘i", "Hawaiian"),
        ("iw", "עברית", "Hebrew"),
        ("hil", "Hiligaynon", "Hiligaynon"),
        ("hi", "हिन्दी", "Hindi"),
        ("hmn", "Hmoob", "Hmong"),
        ("hu", "Magyar", "Hungarian"),
        ("hrx", "Hunsrickisch", "Hunsrik"),
        ("iba", "Jaku Iban", "Iban"),
        ("is", "Íslenska", "Icelandic"),
        ("ig", "Igbo", "Igbo"),
        ("ilo", "Ilokano", "Ilocano"),
        ("id", "Bahasa Indonesia", "Indonesian"),
        ("iu-Latn", "Inuktitut", "Inuktut (Latin)"),
        ("iu", "ᐃᓄᒃᑎᑐᑦ", "Inuktut (Syllabics)"),
        ("ga", "Gaeilge", "Irish"),
        ("it", "Italiano", "Italian"),
        ("jam", "Patwa", "Jamaican Patois"),
        ("ja", "日本語", "Japanese"),
        ("jw", "Basa Jawa", "Javanese"),
        ("kac", "Jinghpaw", "Jingpo"),
        ("kl", "Kalaallisut", "Kalaallisut"),
        ("kn", "ಕನ್ನಡ", "Kannada"),
        ("kr", "Kanuri", "Kanuri"),
        ("pam", "Kapampángan", "Kapampangan"),
        ("kk", "Qazaq tılı", "Kazakh"),
        ("kha", "Khasi", "Khasi"),
        ("km", "ខ្មែរ", "Khmer"),
        ("cgg", "Kiga", "Kiga"),
        ("kg", "Kikongo", "Kikongo"),
        ("rw", "Ikinyarwanda", "Kinyarwanda"),
        ("ktu", "Kituba", "Kituba"),
        ("trp", "Kok Borok", "Kokborok"),
        ("kv", "Коми кыв", "Komi"),
        ("gom", "गोंयची कोंकणी", "Konkani"),
        ("ko", "한국어", "Korean"),
        ("kri", "Krio", "Krio"),
        ("ku", "Kurdî", "Kurdish (Kurmanji)"),
        ("ckb", "کوردیی ناوەندی", "Kurdish (Sorani)"),
        ("ky", "Кыргыз тили", "Kyrgyz"),
        ("lo", "ລາວ", "Lao"),
        ("ltg", "Latgaļu volūda", "Latgalian"),
        ("la", "Latina", "Latin"),
        ("lv", "Latviešu valoda", "Latvian"),
        ("lij", "Lìgure", "Ligurian"),
        ("li", "Limburgs", "Limburgish"),
        ("ln", "Lingála", "Lingala"),
        ("lt", "Lietuvių kalba", "Lithuanian"),
        ("lmo", "Lombard", "Lombard"),
        ("lg", "Luganda", "Luganda"),
        ("luo", "Dholuo", "Luo"),
        ("lb", "Lëtzebuergesch", "Luxembourgish"),
        ("mk", "Македонски", "Macedonian"),
        ("mad", "Basa Madura", "Madurese"),
        ("mai", "मैथिली", "Maithili"),
        ("mak", "Basa Mangkasara'", "Makassar"),
        ("mg", "Malagasy", "Malagasy"),
        ("ms", "Bahasa Melayu", "Malay"),
        ("ms-Arab", "بهاس ملايو", "Malay (Jawi)"),
        ("ml", "മലയാളം", "Malayalam"),
        ("mt", "Malti", "Maltese"),
        ("mam", "Ta yol Mam", "Mam"),
        ("gv", "Gaelg", "Manx"),
        ("mi", "Te reo Māori", "Maori"),
        ("mr", "मराठी", "Marathi"),
        ("mh", "Kajin Ṃajōḷ", "Marshallese"),
        ("mwr", "मारवाड़ी", "Marwadi"),
        ("mfe", "Morisien", "Mauritian Creole"),
        ("chm", "Олык марий", "Meadow Mari"),
        ("mni-Mtei", "ꯃꯤꯇꯩ ꯂꯣꯟ", "Meiteilon (Manipuri)"),
        ("min", "Bahaso Minangkabau", "Minang"),
        ("lus", "Mizo ṭawng", "Mizo"),
        ("mn", "Монгол хэл", "Mongolian"),
        ("my", "မြန်မာ", "Myanmar (Burmese)"),
        ("nhe", "Nahuatl", "Nahuatl (Eastern Huasteca)"),
        ("ndc-ZW", "Cindawu", "Ndau"),
        ("nr", "IsiNdebele", "Ndebele (South)"),
        ("new", "नेवाः भाय्", "Nepalbhasa (Newari)"),
        ("ne", "नेपाली", "Nepali"),
        ("bm-Nkoo", "ߓߡߊߣߊ߲ߞߊ߲", "NKo"),
        ("no", "Norsk", "Norwegian (Bokmål)"),
        ("nus", "Thok Naath", "Nuer"),
        ("oc", "Occitan", "Occitan"),
        ("or", "ଓଡ଼ିଆ", "Odia (Oriya)"),
        ("om", "Afaan Oromoo", "Oromo"),
        ("os", "Ирон æвзаг", "Ossetian"),
        ("pag", "Pangasinan", "Pangasinan"),
        ("pap", "Papiamento", "Papiamento"),
        ("ps", "پښتو", "Pashto"),
        ("fa", "فارسی", "Persian"),
        ("pl", "Polski", "Polish"),
        ("pt", "Português", "Portuguese"),
        ("pt-BR", "Português (Brasil)", "Portuguese (Brazil)"),
        ("pt-PT", "Português (Portugal)", "Portuguese (Portugal)"),
        ("pa", "ਪੰਜਾਬੀ", "Punjabi (Gurmukhi)"),
        ("pa-Arab", "پنجابی", "Punjabi (Shahmukhi)"),
        ("qu", "Runasimi", "Quechua"),
        ("kek", "Q'eqchi'", "Qʼeqchiʼ"),
        ("rom", "Romani chib", "Romani"),
        ("ro", "Română", "Romanian"),
        ("rn", "Ikirundi", "Rundi"),
        ("ru", "Русский", "Russian"),
        ("se", "Sámegiella", "Sami (North)"),
        ("sm", "Gagana Samoa", "Samoan"),
        ("sg", "Sängö", "Sango"),
        ("sa", "संस्कृतम्", "Sanskrit"),
        ("sat-Latn", "Sāntāṛī", "Santali (Latin)"),
        ("sat", "ᱥᱟᱱᱛᱟᱲᱤ", "Santali (Ol Chiki)"),
        ("gd", "Gàidhlig na h-Alba", "Scots Gaelic"),
        ("nso", "Sesotho sa Leboa", "Sepedi"),
        ("sr", "Српски", "Serbian"),
        ("st", "Sesotho", "Sesotho"),
        ("crs", "Kreol seselwa", "Seychellois Creole"),
        ("shn", "လိၵ်ႈတႆး", "Shan"),
        ("sn", "ChiShona", "Shona"),
        ("scn", "Sicilianu", "Sicilian"),
        ("szl", "Ślōnskŏ gŏdka", "Silesian"),
        ("sd", "سنڌي", "Sindhi"),
        ("si", "සිංහල", "Sinhala"),
        ("sk", "Slovenčina", "Slovak"),
        ("sl", "Slovenščina", "Slovenian"),
        ("so", "Soomaali", "Somali"),
        ("es", "Español", "Spanish"),
        ("su", "Basa Sunda", "Sundanese"),
        ("sus", "Sosoxui", "Susu"),
        ("sw", "Kiswahili", "Swahili"),
        ("ss", "Siswati", "Swati"),
        ("sv", "Svenska", "Swedish"),
        ("ty", "Reo tahiti", "Tahitian"),
        ("tg", "Забони тоҷикӣ", "Tajik"),
        ("ber-Latn", "Tamaziɣt", "Tamazight"),
        ("ber", "ⵜⴰⵎⴰⵣⵉⵖⵜ", "Tamazight (Tifinagh)"),
        ("ta", "தமிழ்", "Tamil"),
        ("tt", "Татар теле", "Tatar"),
        ("te", "తెలుగు", "Telugu"),
        ("tet", "Tetun", "Tetum"),
        ("th", "ภาษาไทย", "Thai"),
        ("bo", "བོད་ཡིག", "Tibetan"),
        ("ti", "ትግርኛ", "Tigrinya"),
        ("tiv", "Tiv", "Tiv"),
        ("tpi", "Tok Pisin", "Tok Pisin"),
        ("to", "Lea fakatonga", "Tongan"),
        ("lua", "Tshiluba", "Tshiluba"),
        ("ts", "Xitsonga", "Tsonga"),
        ("tn", "Setswana", "Tswana"),
        ("tcy", "ತುಳು", "Tulu"),
        ("tum", "chiTumbuka", "Tumbuka"),
        ("tr", "Türkçe", "Turkish"),
        ("tk", "Türkmençe", "Turkmen"),
        ("tyv", "Тыва дыл", "Tuvan"),
        ("ak", "Akan", "Twi"),
        ("udm", "Удмурт кыл", "Udmurt"),
        ("uk", "Українська", "Ukrainian"),
        ("ur", "اردو", "Urdu"),
        ("ug", "ئۇيغۇرچە", "Uyghur"),
        ("uz", "Ўзбек тили", "Uzbek"),
        ("ve", "Tshivenḓa", "Venda"),
        ("vec", "Vèneto", "Venetian"),
        ("vi", "Tiếng Việt", "Vietnamese"),
        ("war", "Waray-Waray", "Waray"),
        ("cy", "Cymraeg", "Welsh"),
        ("wo", "Wolof", "Wolof"),
        ("xh", "IsiXhosa", "Xhosa"),
        ("sah", "Саха тыла", "Yakut"),
        ("yi", "יידיש", "Yiddish"),
        ("yo", "Èdè Yorùbá", "Yoruba"),
        ("yua", "Màaya t'àan", "Yucatec Maya"),
        ("zap", "Diidxazá", "Zapotec"),
        ("zu", "IsiZulu", "Zulu"),
    ]

    /// Complete catalog used by source selection and language detection:
    /// all 250 codes (249 + the `pt` alias), in A-Z English order.
    static var codes: [String] {
        allLanguages.map(\.code)
    }

    /// All supported language codes and their localized display names.
    static var all: [(code: String, name: String)] {
        codes.map { code in
            (code: code, name: Locale.current.localizedString(forIdentifier: code) ?? code)
        }
    }

    /// Set of all supported language codes.
    static var codeSet: Set<String> {
        Set(codes)
    }

    /// Native name for a language code (e.g. `ja` → `日本語`).
    /// Falls back to the code itself for unknown identifiers.
    static func nativeName(for code: String) -> String {
        nativeNames[code] ?? code
    }

    /// Native names by code, derived from `allLanguages`.
    static let nativeNames: [String: String] = Dictionary(
        uniqueKeysWithValues: allLanguages.map { ($0.code, $0.nativeName) }
    )

    /// English full names for language codes, used when interpolating into LLM prompts.
    ///
    /// Small models (≤2B params) often fail to recognize BCP-47 codes like `zh-Hans`,
    /// so we expand to a stable English name. We hardcode the mapping rather than
    /// using `Locale.localizedString(forIdentifier:)` to avoid locale-dependent
    /// variations like "Chinese, Simplified" vs "Simplified Chinese".
    /// Derived from `allLanguages` (Manh 2026-11-19, 0.1.5: 20 → 250).
    static let englishNames: [String: String] = Dictionary(
        uniqueKeysWithValues: allLanguages.map { ($0.code, $0.englishName) }
    )

    /// Returns the English full name for a language code (e.g. `zh-Hans` → `Simplified Chinese`).
    /// Falls back to the code itself for unknown identifiers.
    static func englishName(for code: String) -> String {
        englishNames[code] ?? code
    }

    /// The popular languages as full entries, in `popularTargetCodes` order.
    static var popularLanguages: [(code: String, nativeName: String, englishName: String)] {
        let byCode = Dictionary(uniqueKeysWithValues: allLanguages.map { ($0.code, $0) })
        return popularTargetCodes.compactMap { byCode[$0] }
    }

    /// Every language EXCEPT the popular ones, still A-Z by English name —
    /// the "All languages" section of the dropdown (no duplicates).
    static var otherLanguages: [(code: String, nativeName: String, englishName: String)] {
        let popular = Set(popularTargetCodes)
        return allLanguages.filter { !popular.contains($0.code) }
    }

}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Defaults.Serializable {
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: String(localized: "System Default")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

// MARK: - Text Detection Mode

enum TextDetectionMode: String, CaseIterable, Defaults.Serializable {
    case conservative  // Tier 1 only (AX API)
    case standard      // Tier 1 + Tier 2 (AX + AppleScript)
    case full          // Tier 1 + Tier 2 + Tier 3 (AX + AppleScript + ⌘C simulation)
}

// MARK: - Result View Mode

enum ResultViewMode: String, Defaults.Serializable {
    case rendered
    case source
    case rich
}

enum SourceViewMode: String, Defaults.Serializable {
    case editor
    case rich
}

// MARK: - Menu Bar Icon Style

enum MenuBarIconStyle: String, CaseIterable, Defaults.Serializable {
    case filled
    case custom
}

enum MenuBarCustomIconSource: String, CaseIterable, Defaults.Serializable {
    case symbol
    case image
}

/// Constants describing the SF Symbols catalog used by the menu bar icon UI.
enum MenuBarIconCatalog {
    /// Default SF Symbol surfaced when the user first picks a custom symbol icon.
    /// Kept in sync with the `filled` style so switching to custom is non-disruptive.
    static let defaultSymbol = "character.bubble.fill"

    /// Curated SF Symbol presets exposed in Settings. Names must exist on macOS 14.
    static let presets: [String] = [
        "character.bubble.fill",
        "text.bubble.fill",
        "bubble.left.fill",
        "globe",
        "globe.americas.fill",
        "character.book.closed.fill",
        "text.viewfinder",
        "sparkles",
        "abc",
        "textformat",
        "character",
        "command",
    ]
}

/// What a click on the floating trigger icon does (TransPeek Phase 1).
/// Hover always opens the panel; click is a separate, faster action.
/// The Settings toggle ("Click icon for:") picks which of Speak / Fast
/// Read the plain click does, and Option+click does the other one.
/// There is NO Translate click action (removed 2026-11-20, Manh) —
/// Translate is hover-only. The old upstream `TriggerActivationMode`
/// (hover / click) was also removed 2026-11-20 — the icon is always
/// hover, and the upstream activation logic confused the flow.
enum TriggerClickAction: String, CaseIterable, Defaults.Serializable {
    case speak     // Speak the selected text immediately
    case read      // Open Fast Read (RSVP) with the selected text (default, Manh 2026-11-18)
}

/// How dictionary links are shown at the bottom of the float panel.
enum DictionaryDisplayMode: String, CaseIterable, Defaults.Serializable {
    case iconText // Icon + name
    case iconOnly // Icon only
}

/// What happens after screenshot OCR finishes.
enum OCRPostMode: String, CaseIterable, Defaults.Serializable {
    case panel    // Translate + show the float panel (default)
    case copyOnly // Copy the recognized text straight to the clipboard, no panel
}

// MARK: - Settings Tab

enum SettingsTab: String, Defaults.Serializable {
    case general
    case excludedApps
    case services
    case providerOrder
    case dictionary
    case ocr
    case audio
    case about
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let smartTranslation = Self("smartTranslation")
    static let translateSelection = Self("translateSelection", default: .init(.d, modifiers: .option))
    static let ocrScreenshot = Self("ocrScreenshot", default: .init(.s, modifiers: .option))
    static let silentOCR = Self("silentOCR")
    static let silentOCRTranslated = Self("silentOCRTranslated")
    static let screenshotCopy = Self("screenshotCopy")
    static let scanBarcodes = Self("scanBarcodes")
    static let inputTranslation = Self("inputTranslation", default: .init(.a, modifiers: .option))
    static let clipboardTranslation = Self("clipboardTranslation", default: .init(.v, modifiers: .option))
    /// Fast Read (RSVP) from selection/clipboard — the global shortcut is
    /// only a fallback entry point (Manh 2026-11-17), so it has no default
    /// key; the user assigns one in Settings if they want it.
    static let fastRead = Self("fastRead")
    static let swapLanguages: Self = {
        let name = Self("swapLanguages", default: .init(.t, modifiers: .option))
        // Clear legacy or default bindings that conflict with popup or global actions.
        if let current = KeyboardShortcuts.getShortcut(for: name),
           SwapLanguagesShortcut.isReserved(current) {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        KeyboardShortcuts.disable(name)
        SwapLanguagesShortcut.restoreGlobalRegistrations()
        return name
    }()
}

/// Keeps the swap shortcut popup-local even though the package recorder uses global names.
enum SwapLanguagesShortcut {
    static let didChangeNotification = Notification.Name("SwapLanguagesShortcutDidChange")

    private static let popupReservedNumberKeys: Set<KeyboardShortcuts.Key> = [
        .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
        .keypad1, .keypad2, .keypad3, .keypad4, .keypad5,
        .keypad6, .keypad7, .keypad8, .keypad9,
    ]

    /// `PopupPanel.sendEvent` runs before `NSTextView`, so preserve standard editing and navigation.
    private static let textEditingShortcuts: Set<KeyboardShortcuts.Shortcut> = [
        .init(.a, modifiers: .command),
        .init(.b, modifiers: .command),
        .init(.c, modifiers: .command),
        .init(.e, modifiers: .command),
        .init(.f, modifiers: .command),
        .init(.f, modifiers: [.command, .option]),
        .init(.g, modifiers: .command),
        .init(.g, modifiers: [.command, .shift]),
        .init(.j, modifiers: .command),
        .init(.i, modifiers: .command),
        .init(.u, modifiers: .command),
        .init(.v, modifiers: .command),
        .init(.v, modifiers: [.command, .option, .shift]),
        .init(.x, modifiers: .command),
        .init(.z, modifiers: .command),
        .init(.z, modifiers: [.command, .shift]),
        .init(.leftArrow, modifiers: .command),
        .init(.rightArrow, modifiers: .command),
        .init(.upArrow, modifiers: .command),
        .init(.downArrow, modifiers: .command),
        .init(.leftArrow, modifiers: [.command, .shift]),
        .init(.rightArrow, modifiers: [.command, .shift]),
        .init(.upArrow, modifiers: [.command, .shift]),
        .init(.downArrow, modifiers: [.command, .shift]),
        .init(.leftArrow, modifiers: .option),
        .init(.rightArrow, modifiers: .option),
        .init(.leftArrow, modifiers: [.option, .shift]),
        .init(.rightArrow, modifiers: [.option, .shift]),
        .init(.delete, modifiers: .option),
        .init(.deleteForward, modifiers: .option),
        .init(.delete, modifiers: [.option, .shift]),
        .init(.deleteForward, modifiers: [.option, .shift]),
        .init(.delete, modifiers: .command),
        .init(.deleteForward, modifiers: .command),
        .init(.delete, modifiers: [.command, .shift]),
        .init(.deleteForward, modifiers: [.command, .shift]),
    ]

    private static let globalShortcutNames: [KeyboardShortcuts.Name] = [
        .smartTranslation,
        .translateSelection,
        .ocrScreenshot,
        .silentOCR,
        .screenshotCopy,
        .scanBarcodes,
        .inputTranslation,
        .clipboardTranslation,
        .fastRead,
    ]

    static var current: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .swapLanguages)
    }

    static func recorderDidChange() {
        reconcileRegistrations()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func reconcileRegistrations() {
        KeyboardShortcuts.disable(.swapLanguages)
        restoreGlobalRegistrations()
    }

    /// `KeyboardShortcuts` unregisters by key combination rather than by name. Re-enable
    /// the app-wide shortcuts after disabling or reverting this popup-local binding so a
    /// rejected collision cannot leave an existing global shortcut inactive.
    static func restoreGlobalRegistrations() {
        KeyboardShortcuts.enable(globalShortcutNames)
    }

    static func matches(_ event: NSEvent) -> Bool {
        guard let current, let eventShortcut = KeyboardShortcuts.Shortcut(event: event) else {
            return false
        }
        return eventShortcut == current
    }

    static func isReserved(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        if shortcut.key == .return || shortcut.key == .keypadEnter || shortcut.key == .escape {
            return true
        }

        if shortcut.modifiers == .command,
           let key = shortcut.key,
           popupReservedNumberKeys.contains(key) {
            return true
        }

        if textEditingShortcuts.contains(shortcut) {
            return true
        }

        return globalShortcutNames
            .compactMap { KeyboardShortcuts.getShortcut(for: $0) }
            .contains(shortcut)
    }
}

// MARK: - User Defaults Keys

/// Where a focus / rest-eyes reminder shows (Manh 2026-11-20, focus
/// timer + panel decor — the "Run reminder in:" picker in the panel-left
/// Focus & Rest card). This applies ONLY to the reminder — Fast Read
/// has its OWN separate setting (`FastReadRunLocation`, the "Run
/// FastRead in:" picker in panel right, Manh 2026-11-20, 05:27: the
/// two features must not share one setting).
enum FocusReminderDestination: String, CaseIterable, Defaults.Serializable {
    /// The reminder opens a separate Rest window (the original design).
    case newWindow
    /// The reminder shows inside panel right, no separate window.
    case rightPanel

    /// Labels synced to the Fast Read names (Manh 2026-11-20, 17:28):
    /// "FastRead Lite" / "New FastRead Window" — same words as the
    /// "Run FastRead in:" picker, so the two pickers read as one
    /// vocabulary. NO "(recommended)" suffix here: that nudge belongs
    /// to Fast Read only, not to the reminder. Labels only — the
    /// setting key, values and default are unchanged.
    var displayName: String {
        switch self {
        case .newWindow: return "New FastRead Window"
        case .rightPanel: return "FastRead Lite"
        }
    }
}

/// Where Fast Read (RSVP) runs (Manh 2026-11-20, 05:27 — the "Run
/// FastRead in:" picker in panel right). Separate from the reminder
/// destination: Reminder and Fast Read are two different features and
/// must not share one setting. Applies GLOBALLY to every Fast Read
/// launch (panel button, float icon, menubar, shortcut): the chosen
/// location is the only place RSVP shows.
/// Case order = picker order (Manh 2026-11-20, 17:11): "FastRead Lite"
/// first, "New FastRead Window (recommended)" second. Order is display
/// only — the default is still `.newWindow` (set explicitly in the
/// Defaults key) and values are stored as Strings, so existing saved
/// values keep working.
enum FastReadRunLocation: String, CaseIterable, Defaults.Serializable {
    /// Fast Read runs inside panel right, no separate window.
    case rightPanel
    /// Fast Read opens the separate Window Read (default — the current
    /// behavior, so nothing changes until the user picks otherwise).
    case newWindow

    /// Labels (Manh 2026-11-20, 11:41): "FastRead" one word, matching
    /// the setting name; the picker appends " (recommended)" (lowercase)
    /// to the window option; "FastRead Lite" matches the panel-right
    /// section title "Fast Read Lite".
    var displayName: String {
        switch self {
        case .newWindow: return "New FastRead Window"
        case .rightPanel: return "FastRead Lite"
        }
    }
}

/// Fast Read (RSVP) window color scheme (Manh 2026-11-17, spec §14.3):
/// picked in the window's Settings button; persists across opens.
enum RSVPColorScheme: String, CaseIterable, Defaults.Serializable {
    /// Black text on a white page.
    case light
    /// White text on a black page.
    case dark

    var displayName: String {
        switch self {
        case .light: return "Black on White"
        case .dark: return "White on Black"
        }
    }
}

/// Fast Read reading style (Manh 2026-11-21): which way the text is
/// presented. Style 1 is the RSVP focus window; Style 2 is the "basic
/// reading" scrollable page. Picked in the Window Read / Lite Settings
/// popover; persists across opens. The two are independent of the Theme
/// (color scheme) — any style works with any theme.
enum ReadingStyle: String, CaseIterable, Defaults.Serializable {
    /// RSVP focus — one chunk centred, focus line fixed (the current design).
    case style1
    /// Basic reading — a scrollable page, focus line advances line by line.
    case style2

    /// Display names, not numbers (Manh 2026-11-21): the picker shows
    /// these names, never "Style 1" / "Style 2".
    var displayName: String {
        switch self {
        case .style1: return "RSVP Focus"
        case .style2: return "Basic Reading"
        }
    }
}

/// Fast Read (RSVP) — when the context around the focus word shows
/// (Manh 2026-11-18, from SwiftRead's `contextDisplayStyle`):
/// picked in the window's Settings button; persists across opens.
enum RSVPContextDisplayStyle: String, CaseIterable, Defaults.Serializable {
    /// Context shows even while playing.
    case always
    /// Context shows only while paused (the original behavior).
    case onPause
    /// Context never shows — focus line only, even when paused.
    case never

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .onPause: return "Only show when paused"
        case .never: return "Never"
        }
    }
}

extension Defaults.Keys {
    // Optional HTTP CONNECT proxy for Google Translate.
    static let googleProxyEnabled = Key<Bool>("provider_google_proxyEnabled", default: false)
    static let googleProxyHost = Key<String>("provider_google_proxyHost", default: "127.0.0.1")
    static let googleProxyPort = Key<String>("provider_google_proxyPort", default: "7890")

    static let targetLanguage = Key<String>("targetLanguage", default: "vi")
    static let favoriteTargetLanguages = Key<[String]>(
        "favoriteTargetLanguages",
        default: SupportedLanguages.defaultTargetCodes
    )
    static let sourceLanguage = Key<String>("sourceLanguage", default: "auto")

    // Enabled translation providers
    static let enabledProviders = Key<Set<String>>("enabledProviders", default: ["openai"])

    // Enabled providers that wait for an explicit action in the result card.
    // Storing the opt-out keeps automatic translation as the backward-compatible default.
    static let onDemandProviderIDs = Key<Set<String>>("onDemandProviderIDs", default: [])

    // User-defined display order for providers (ordered list of provider IDs)
    static let providerOrder = Key<[String]>("providerOrder", default: [])

    // Language detection
    static let detectionConfidenceThreshold = Key<Double>("detectionConfidenceThreshold", default: 0.3)

    // Clipboard grabber timeout
    static let clipboardTimeout = Key<Int>("clipboardTimeout", default: 200)

    // Auto-detect text selection
    static let isAutoDetectEnabled = Key<Bool>("isAutoDetectEnabled", default: true)
    // Block text detection on hover (Manh 2026-11-21): show the float
    // icon when hovering a block of text, without selecting it first.
    // Default ON — the hover icon auto-appears by default.
    static let isHoverBlockDetectionEnabled = Key<Bool>("transpeek_isHoverBlockDetectionEnabled", default: true)
    // Hover delay for block-text detection (Manh 2026-11-21): how long
    // the mouse must stay still over a text block before the icon
    // appears. Longer = the icon only shows on a deliberate pause, not
    // while sweeping the mouse across text. Tunable in Settings, next to
    // the block-text toggle. Default 400 ms.
    static let hoverBlockDelayMs = Key<Int>("transpeek_hoverBlockDelayMs", default: 400)
    static let textDetectionMode = Key<TextDetectionMode>("textDetectionMode", default: .full)
    static let excludedAppBundleIDs = Key<Set<String>>("excludedAppBundleIDs", default: [])

    // Appearance
    static let showInDock = Key<Bool>("showInDock", default: true)

    // Menu bar icon
    static let menuBarIconStyle = Key<MenuBarIconStyle>("menuBarIconStyle", default: .filled)
    static let menuBarCustomIconSource = Key<MenuBarCustomIconSource>("menuBarCustomIconSource", default: .symbol)
    static let menuBarCustomSymbolName = Key<String>("menuBarCustomSymbolName", default: MenuBarIconCatalog.defaultSymbol)
    static let menuBarCustomIconIsTemplate = Key<Bool>("menuBarCustomIconIsTemplate", default: true)
    // Bumped whenever the custom icon file is replaced so SwiftUI re-evaluates the cached image.
    static let menuBarCustomIconRevision = Key<Int>("menuBarCustomIconRevision", default: 0)

    // Onboarding
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)

    // Popup panel default size (Manh 2026-11-17, Windows parity):
    // default width 420 matches the Windows panel (420x450); the
    // previous 440 was the pre-#153 Windows default.
    static let popupDefaultWidth = Key<Int>("popupDefaultWidth", default: 420)
    static let popupDefaultHeight = Key<Int>("popupDefaultHeight", default: 450)
    static let popupInputHeight = Key<Int>("popupInputHeight", default: 48)
    /// Translate panel — whether the "How the icon works" intro card is
    /// collapsed (Manh 2026-11-18). Remembered, so once the reader knows
    /// the flow they can keep it collapsed and the shortcuts table is the
    /// main thing on show. Default false = expanded, so new readers see it.
    static let flowIntroCollapsed = Key<Bool>("transpeek_flowIntroCollapsed", default: false)
    /// Translate panel — whether the "Keyboard Shortcuts" card in panel
    /// left is collapsed (Manh 2026-11-18, round 9). Same pattern as
    /// `flowIntroCollapsed`: remembered, so both cards can stay collapsed
    /// and leave room for the future focus/tomato timer in panel left.
    /// Default false = expanded. Only panel left uses this — the "?"
    /// table in panel center is NOT collapsible (its header hides it).
    static let shortcutsCollapsed = Key<Bool>("transpeek_shortcutsCollapsed", default: false)
    static let popupFontSize = Key<Int>("popupFontSize", default: 14)
    // App interface text size (Settings window): 14 maps to the system
    // default Dynamic Type size (.large), so there is no visible change
    // at the default. Smaller values shrink, larger values grow.
    static let appTextSize = Key<Int>("appTextSize", default: 14)
    // Top bar of the popup panel: app name uses this size, slogan uses size - 1
    // (Windows parity 17/16/13, Manh 2026-11-17).
    static let popupTopBarFontSize = Key<Int>("popupTopBarFontSize", default: 17)
    static let popupFontName = Key<String>("popupFontName", default: "")

    // Markdown rendering of translation results
    static let renderMarkdownResults = Key<Bool>("renderMarkdownResults", default: true)
    static let resultViewMode = Key<ResultViewMode>("resultViewMode", default: .rendered)
    static let sourceViewMode = Key<SourceViewMode>("sourceViewMode", default: .editor)

    // Rich text capture (⌘C simulation keeps formatting and images)
    static let captureRichText = Key<Bool>("captureRichText", default: false)

    // Settings tab selection
    static let selectedSettingsTab = Key<SettingsTab>("selectedSettingsTab", default: .general)

    // Custom providers
    static let customProviders = Key<[CustomProviderDefinition]>("customProviders", default: [])

    // App language override
    static let appLanguage = Key<AppLanguage>("appLanguage", default: .system)

    // TransPeek Phase 1 — trigger icon click + hover delay
    // Default click is Fast Read (Manh 2026-11-18): the icon shows A+
    // by default, so the user can tell at a glance that a plain click
    // reads; Option+click speaks instead.
    static let triggerClickAction = Key<TriggerClickAction>("transpeek_triggerClickAction", default: .read)
    static let hoverDelayMs = Key<Int>("transpeek_hoverDelayMs", default: 500)
    static let autoHideDelaySec = Key<Int>("transpeek_autoHideDelaySec", default: 5)

    // Fast Read (RSVP) — reading speed, chunk size, text size (Manh 2026-11-17).
    // Defaults updated 2026-11-18 (round 7): WPM 500, focus font 80.
    static let rsvpWPM = Key<Int>("transpeek_rsvpWPM", default: RSVPEngine.defaultWPM)
    static let rsvpChunkSize = Key<Int>("transpeek_rsvpChunkSize", default: 1)
    static let rsvpFontSize = Key<Int>("transpeek_rsvpFontSize", default: 80)
    /// Context (around) text size as a fraction of the focus font size
    /// (Manh 2026-11-18, round 7): the top bar's "Context size" picker
    /// sets this as a percent. Default 0.40 (smaller than the old fixed
    /// 0.50), range 0.25–1.00.
    static let rsvpContextSizeRatio = Key<Double>("transpeek_rsvpContextSizeRatio", default: 0.40)
    static let rsvpColorScheme = Key<RSVPColorScheme>("transpeek_rsvpColorScheme", default: .light)
    static let rsvpContextDisplayStyle = Key<RSVPContextDisplayStyle>("transpeek_rsvpContextDisplayStyle", default: .onPause)
    /// Reading style (Manh 2026-11-21): Style 1 = RSVP focus (default),
    /// Style 2 = basic reading page. A mode preference like the color
    /// scheme, so "Reset to default" does NOT reset it.
    static let rsvpReadingStyle = Key<ReadingStyle>("transpeek_rsvpReadingStyle", default: .style1)
    /// Highlight the current line in Style 2 (Manh 2026-11-21): a toggle
    /// in Settings, default OFF. While TTS is playing the highlight
    /// turns itself on (computed in the view, not stored here).
    static let rsvpHighlightCurrentLine = Key<Bool>("transpeek_rsvpHighlightCurrentLine", default: false)
    /// Whether text starts reading automatically when it is sent in
    /// (Manh 2026-11-20): when ON (default), every time text arrives
    /// from the select-text icon the Fast Read window starts reading
    /// at once — no Space press needed. Toggled in the window's
    /// Settings popover.
    static let rsvpAutoPlay = Key<Bool>("transpeek_rsvpAutoPlay", default: true)
    /// TTS (speech) on/off for Fast Read playback (Manh 2026-11-21,
    /// CI314 fix): the speaker button toggles whether the RSVP
    /// read-along speaks. Default OFF — a reader who never touches
    /// the speaker keeps the silent WPM reading they already have.
    /// A mode preference like the color scheme, so "Reset to default"
    /// does NOT reset it.
    static let rsvpTTSEnabled = Key<Bool>("transpeek_rsvpTTSEnabled", default: false)

    // Focus timer + rest eyes (Manh 2026-11-20, focus timer + panel
    // decor — the Focus & Rest card in panel left). Pomodoro STANDARD
    // logic: Work 25 / Rest 5 by default, long break 15 after 4 focus
    // cycles. Rest eyes is the 20-20-20 rule: every 20 min, rest the
    // eyes for 20 s (fixed — no picker, the rule is the point).
    static let focusWorkMinutes = Key<Int>("transpeek_focusWorkMinutes", default: 25)
    static let focusRestMinutes = Key<Int>("transpeek_focusRestMinutes", default: 5)
    static let focusLongBreakMinutes = Key<Int>("transpeek_focusLongBreakMinutes", default: 15)
    static let focusReminderDestination = Key<FocusReminderDestination>("transpeek_focusReminderDestination", default: .newWindow)
    /// Continuous Pomodoro (Manh 2026-11-20, 07:12; default ON,
    /// Manh 2026-11-20, 07:25): when ON, the next session starts
    /// automatically after a rest / long break (Work → Rest →
    /// Work …, long break after 4 focus cycles), looping until the
    /// user turns it off or stops it. OFF = each session ends and
    /// waits for a manual start.
    static let focusRepeatAutomatically = Key<Bool>("transpeek_focusRepeatAutomatically", default: true)
    /// Auto start focus (Manh 2026-11-20, 09:47; default OFF): when
    /// ON, the focus timer starts on its own every time the app
    /// launches — as if the user pressed Start — so there is no need
    /// to open the panel and press Start. OFF = the timer waits for
    /// a manual start, as before. Toggled in the Focus & Rest card.
    static let focusAutoStart = Key<Bool>("transpeek_focusAutoStart", default: false)
    /// Where Fast Read runs (Manh 2026-11-20, 05:27): the "Run
    /// FastRead in:" picker in panel right. Default is the window, so
    /// current behavior is preserved until the user picks otherwise.
    static let fastReadRunLocation = Key<FastReadRunLocation>("transpeek_fastReadRunLocation", default: .newWindow)
    /// Whether the Focus & Rest card in panel left is collapsed
    /// (Manh 2026-11-20). Same pattern as `flowIntroCollapsed` /
    /// `shortcutsCollapsed`: remembered, so the card can stay collapsed
    /// and leave room for the shortcuts table.
    static let focusTimerCollapsed = Key<Bool>("transpeek_focusTimerCollapsed", default: false)

    // TransPeek Phase 1 — translation fallback (primary -> fallback -> free Apple/Google)
    static let primaryProviderID = Key<String>("transpeek_primaryProviderID", default: "")
    static let fallbackProviderID = Key<String>("transpeek_fallbackProviderID", default: "")

    // TransPeek Phase 1 — dictionary links (JSON array of DictionaryLink, see DictionaryLink.swift)
    static let dictionaryLinksJSON = Key<String>("transpeek_dictionaryLinksJSON", default: "")
    static let dictionaryDisplayMode = Key<DictionaryDisplayMode>("transpeek_dictionaryDisplayMode", default: .iconText)

    // TransPeek Phase 1 — OCR
    static let ocrPostMode = Key<OCRPostMode>("transpeek_ocrPostMode", default: .panel)
    static let ocrAutoCopyTranslation = Key<Bool>("transpeek_ocrAutoCopyTranslation", default: true)
    static let ocrLanguages = Key<[String]>("transpeek_ocrLanguages", default: ["vi-VN", "en-US"])

    // TransPeek Phase 1 — TTS voice choice per language (AVSpeechSynthesisVoice identifier, "" = system default)
    static let ttsVoiceEN = Key<String>("transpeek_ttsVoiceEN", default: "")
    static let ttsVoiceVI = Key<String>("transpeek_ttsVoiceVI", default: "")

    // TTS (Text-to-Speech)
    static let ttsProvider = Key<String>("tts_provider", default: "apple")
    static let ttsAccent = Key<TTSAccent>("tts_accent", default: .american)
    static let ttsSpeechRate = Key<Double>("tts_speechRate", default: 1.0)
    static let ttsAutoPlaySource = Key<Bool>("tts_autoPlaySource", default: false)
    static let ttsAutoPlayTarget = Key<Bool>("tts_autoPlayTarget", default: false)
    // "first" = first provider to complete; otherwise a specific provider ID
    static let ttsAutoPlayTargetProvider = Key<String>("tts_autoPlayTargetProvider", default: "first")
    static let ttsLanguageRates = Key<[String: Double]>("tts_languageRates", default: [:])
}

