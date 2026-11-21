import Foundation

/// Owns Tesseract `*.traineddata` files (port of the Windows
/// `TesseractLanguageDataManager`, Manh 2026-11-20).
///
/// Languages download on demand from tessdata_best (most accurate) into
/// `~/Library/Application Support/TransPeek/tessdata`. Since 2026-11-20
/// (Manh) eng + vie are BUNDLED with the app as tessdata_best (~27 MB
/// total, app grows from ~15 MB to ~43 MB) so OCR works out of the box
/// with the best accuracy — the provider copies a bundled file into the
/// local dir on first use, no download. Extra languages still download
/// on demand to the local dir (from tessdata_best, like Windows).
///
/// The manager is generic: every operation takes a Tesseract language
/// code (`eng`, `vie`, `chi_sim`, ...), so the full 8-language OCR list
/// works — adding a language is just adding its code to the list, no
/// new logic.
enum TesseractLanguageDataManager {
    /// tessdata_best raw file URL, e.g. .../vie.traineddata.
    static func downloadURL(for code: String) -> URL {
        URL(string: "https://github.com/tesseract-ocr/tessdata_best/raw/main/\(code).traineddata")!
    }

    /// Local tessdata dir the engine reads from.
    static var tessdataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TransPeek/tessdata")
    }

    /// Language data bundled with the app: the tessdata folder in the
    /// app bundle (`Resources/tessdata`). The engine never reads from
    /// here directly — a bundled file is copied into
    /// `tessdataDirectory` on first use (see `ensureLanguageAvailable`),
    /// so the engine always has one directory to read from.
    /// In a test run `Bundle.main` is the test host/runner, not the
    /// bundle holding the resources — the test target's tessdata lands
    /// in the test bundle instead. So check `Bundle.main` first, then
    /// every other loaded bundle, and return the first directory that
    /// actually holds `.traineddata` files: a `tessdata` subfolder, or
    /// the bundle's Resources root (the files may be copied flat
    /// instead of keeping the subfolder).
    static var bundledTessdataDirectory: URL? {
        let fileManager = FileManager.default
        let bundles = [Bundle.main] + Bundle.allBundles.filter { $0 != Bundle.main }
        for bundle in bundles {
            guard let resources = bundle.resourceURL else { continue }
            // Preferred: a "tessdata" subfolder.
            let tessdata = resources.appendingPathComponent("tessdata")
            if fileManager.fileExists(atPath: tessdata.path) {
                return tessdata
            }
            // Fallback: files copied flat into the Resources root.
            if fileManager.fileExists(atPath: resources.appendingPathComponent("eng.traineddata").path) {
                return resources
            }
        }
        return nil
    }

    /// Language codes bundled with the app (tessdata in the bundle).
    /// Empty when the app was built without the bundle.
    static func bundledCodes() -> [String] {
        guard let dir = bundledTessdataDirectory else { return [] }
        return codes(in: dir)
    }

    /// Language codes usable right now: bundled with the app OR
    /// already in the local tessdata dir. For status display only —
    /// the engine reads from `tessdataDirectory`, and a bundled file
    /// is copied there on first use.
    static func availableCodes() -> [String] {
        Array(Set(bundledCodes()).union(installedCodes())).sorted()
    }

    /// Installed language codes (`vie`, `eng`, ...) in the tessdata dir.
    static func installedCodes() -> [String] {
        codes(in: tessdataDirectory)
    }

    /// Whether a language file is already in the tessdata dir.
    static func isInstalled(_ code: String) -> Bool {
        installedCodes().contains(code)
    }

    /// Language codes present in a directory (`*.traineddata` files).
    /// A directory that cannot be listed means "nothing there".
    private static func codes(in directory: URL) -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return files
            .filter { $0.pathExtension == "traineddata" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Atomically move a temp file into place as `destination`.
    /// `replaceItemAt` only works when the destination already exists,
    /// so a first-time install (no previous file) uses a plain move.
    private static func atomicMove(temp: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: destination)
        }
    }

    /// Make one language file available in the tessdata dir (atomic
    /// replace of any previous file). Prefers the copy bundled with
    /// the app (eng + vie, no network — OCR works out of the box)
    /// and downloads from tessdata_best only when the app does not
    /// bundle that language.
    static func ensureLanguageAvailable(_ code: String) async throws {
        try FileManager.default.createDirectory(
            at: tessdataDirectory, withIntermediateDirectories: true
        )
        let destination = tessdataDirectory.appendingPathComponent("\(code).traineddata")
        if let bundled = bundledTessdataDirectory?
            .appendingPathComponent("\(code).traineddata"),
           FileManager.default.fileExists(atPath: bundled.path) {
            // Bundled with the app: copy locally instead of
            // downloading — same atomic replace, no network.
            let temp = destination.appendingPathExtension("download")
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: bundled, to: temp)
            try atomicMove(temp: temp, to: destination)
            return
        }
        try await downloadLanguage(code)
    }

    /// Download one language file from tessdata_best into the tessdata
    /// dir (atomic replace via a `.download` temp file).
    static func downloadLanguage(_ code: String) async throws {
        try FileManager.default.createDirectory(
            at: tessdataDirectory, withIntermediateDirectories: true
        )
        let destination = tessdataDirectory.appendingPathComponent("\(code).traineddata")
        let temp = destination.appendingPathExtension("download")
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(from: downloadURL(for: code))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TesseractLanguageError.downloadFailed(
                code, "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            )
        }
        try data.write(to: temp, options: .atomic)
        try atomicMove(temp: temp, to: destination)
        try verifyDownloaded(code)
    }

    /// Download several languages, one at a time. A single file failing
    /// (network, bad response, too small to be real data) does not stop
    /// the rest — its error is collected in `failed`. Each downloaded
    /// file is verified (exists and is not suspiciously small) before it
    /// counts as downloaded.
    static func downloadMany(_ codes: [String]) async -> (downloaded: [String], failed: [(code: String, error: String)]) {
        var downloaded: [String] = []
        var failed: [(code: String, error: String)] = []
        for code in codes {
            do {
                try await ensureLanguageAvailable(code)
                try verifyDownloaded(code)
                downloaded.append(code)
            } catch {
                failed.append((code: code, error: error.localizedDescription))
            }
        }
        return (downloaded, failed)
    }

    /// A downloaded language file must exist and hold real data. A file
    /// under 1 KB is not a traineddata model (a truncated download or
    /// an error page saved as a file) — delete it and fail so the next
    /// attempt retries instead of leaving junk behind.
    private static func verifyDownloaded(_ code: String) throws {
        let path = tessdataDirectory.appendingPathComponent("\(code).traineddata")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int, size >= 1024 else {
            try? FileManager.default.removeItem(at: path)
            throw TesseractLanguageError.incompleteDownload(code)
        }
    }

    /// Tesseract codes for the requested BCP 47 languages that are not
    /// installed yet. Defaults to `["eng"]` when nothing maps (so the
    /// caller always has at least one language to ensure).
    static func missingCodes(for languages: [String]) -> [String] {
        var codes = Array(Set(languages.compactMap { tessCode(forBCP47: $0) }))
        if codes.isEmpty { codes = ["eng"] }
        return codes.filter { !isInstalled($0) }
    }

    /// BCP 47 -> Tesseract code. Unknown codes return nil (caller drops them).
    static func tessCode(forBCP47 code: String) -> String? {
        switch code {
        case "vi-VN", "vi": "vie"
        case "en-US", "en-GB", "en": "eng"
        case "zh-Hans": "chi_sim"
        case "zh-Hant": "chi_tra"
        case "ja-JP", "ja": "jpn"
        case "ko-KR", "ko": "kor"
        case "fr-FR", "fr": "fra"
        case "de-DE", "de": "deu"
        case "es-ES", "es": "spa"
        case "pt-BR", "pt": "por"
        case "ru-RU", "ru": "rus"
        case "ar-SA", "ar": "ara"
        case "it-IT", "it": "ita"
        case "th-TH", "th": "tha"
        case "nl-NL", "nl": "nld"
        case "sv-SE", "sv": "swe"
        case "da-DK", "da": "dan"
        case "fi-FI", "fi": "fin"
        case "nb-NO", "nb", "nn-NO", "nn", "no": "nor"
        case "pl-PL", "pl": "pol"
        case "cs-CZ", "cs": "ces"
        case "hu-HU", "hu": "hun"
        case "ro-RO", "ro": "ron"
        case "bg-BG", "bg": "bul"
        case "el-GR", "el": "ell"
        case "he-IL", "he": "heb"
        case "hi-IN", "hi": "hin"
        case "id-ID", "id": "ind"
        case "ms-MY", "ms": "msa"
        case "tr-TR", "tr": "tur"
        case "uk-UA", "uk": "ukr"
        default: nil
        }
    }

    /// Tesseract code -> BCP 47, for display / supportedLanguages.
    static func bcp47(forTessCode code: String) -> String {
        switch code {
        case "vie": "vi-VN"
        case "eng": "en-US"
        case "chi_sim": "zh-Hans"
        case "chi_tra": "zh-Hant"
        case "jpn": "ja-JP"
        case "kor": "ko-KR"
        case "fra": "fr-FR"
        case "deu": "de-DE"
        case "spa": "es-ES"
        case "por": "pt-BR"
        case "rus": "ru-RU"
        case "ara": "ar-SA"
        case "ita": "it-IT"
        case "tha": "th-TH"
        default: code
        }
    }
}

/// Errors from the Tesseract language data manager.
enum TesseractLanguageError: LocalizedError {
    case downloadFailed(String, String)
    case incompleteDownload(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let code, let reason):
            String(localized: "Could not download \(code) language data (\(reason)).")
        case .incompleteDownload(let code):
            String(localized: "Downloaded \(code) language data looks incomplete (file too small).")
        }
    }
}
