import AppKit
import CoreGraphics
import Defaults
import Foundation
import os

// MARK: - Language Data Manager (on-demand download)

/// Owns Tesseract `*.traineddata` files (SPEC §3.3, M2+M3).
///
/// Languages are downloaded on demand into
/// `~/Library/Application Support/TransPeek/tessdata/` — never bundled with
/// the app, so the ~5MB app size is preserved. `tessdata_best` (most
/// accurate) is the source; `vie` + `eng` are the v1 languages.
enum TesseractLanguageDataManager {
    /// `tessdata_best` raw files, e.g. `.../vie.traineddata`.
    static func downloadURL(for code: String) -> URL {
        URL(string: "https://github.com/tesseract-ocr/tessdata_best/raw/main/\(code).traineddata")!
    }

    /// Directory for downloaded language files (created on first download).
    static var tessdataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TransPeek/tessdata", isDirectory: true)
    }

    /// Tesseract data directories the CLI searches, in preference order:
    /// our download dir first, then the Homebrew install's own tessdata.
    static var tessdataSearchPaths: [URL] {
        var paths = [tessdataDirectory]
        for base in ["/opt/homebrew/share/tessdata", "/usr/local/share/tessdata", "/opt/local/share/tessdata"] {
            paths.append(URL(fileURLWithPath: base, isDirectory: true))
        }
        return paths
    }

    /// Installed language codes (`"vie"`, `"eng"`, ...) across all search paths.
    static func installedCodes() -> [String] {
        var codes = Set<String>()
        for dir in tessdataSearchPaths {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for file in files where file.pathExtension == "traineddata" {
                codes.insert(file.deletingPathExtension().lastPathComponent)
            }
        }
        return codes.sorted()
    }

    static func isInstalled(_ code: String) -> Bool {
        installedCodes().contains(code)
    }

    /// Make sure every requested language file is visible in our tessdata
    /// dir: download dir files are used as-is; files that only exist in a
    /// Homebrew/MacPorts tessdata dir are symlinked in (Tesseract accepts a
    /// single `--tessdata-dir`, so everything must be reachable from one place).
    static func ensureLanguageLinks(for codes: [String]) {
        let dir = tessdataDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let brewDirs = tessdataSearchPaths.dropFirst()
        for code in codes {
            let link = dir.appendingPathComponent("\(code).traineddata")
            guard !FileManager.default.fileExists(atPath: link.path) else { continue }
            for brewDir in brewDirs {
                let source = brewDir.appendingPathComponent("\(code).traineddata")
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
                break
            }
        }
    }
    static func download(code: String) async throws {
        let url = downloadURL(for: code)
        let dir = tessdataDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("\(code).traineddata")
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OCRError.engineFailed(String(localized: "Could not download \(code) language data"))
        }
        // Move atomically; a previous download is replaced.
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    // MARK: - BCP 47 <-> Tesseract codes (pure mapping)

    /// BCP 47 -> Tesseract code. Unknown codes return nil (caller drops them).
    static func tessCode(forBCP47 code: String) -> String? {
        switch code {
        case "vi-VN", "vi": return "vie"
        case "en-US", "en-GB", "en": return "eng"
        case "zh-Hans": return "chi_sim"
        case "zh-Hant": return "chi_tra"
        case "ja-JP", "ja": return "jpn"
        case "ko-KR", "ko": return "kor"
        case "fr-FR", "fr": return "fra"
        case "de-DE", "de": return "deu"
        case "es-ES", "es": return "spa"
        case "pt-BR", "pt": return "por"
        case "ru-RU", "ru": return "rus"
        case "ar-SA", "ar": return "ara"
        case "it-IT", "it": return "ita"
        case "th-TH", "th": return "tha"
        default: return nil
        }
    }

    /// Tesseract code -> BCP 47 for display / `supportedLanguages`.
    static func bcp47(forTessCode code: String) -> String {
        switch code {
        case "vie": return "vi-VN"
        case "eng": return "en-US"
        case "chi_sim": return "zh-Hans"
        case "chi_tra": return "zh-Hant"
        case "jpn": return "ja-JP"
        case "kor": return "ko-KR"
        case "fra": return "fr-FR"
        case "deu": return "de-DE"
        case "spa": return "es-ES"
        case "por": return "pt-BR"
        case "rus": return "ru-RU"
        case "ara": return "ar-SA"
        case "ita": return "it-IT"
        case "tha": return "th-TH"
        default: return code
        }
    }
}

// MARK: - Tesseract OCR Provider (fallback only)

/// Tesseract OCR via the Homebrew `tesseract` CLI (SPEC §3.3, M2+M3).
///
/// Engine choice, decided by the 2026-11-07 spike (see docs/M2-M3-TESTING.md):
/// * SwiftyTesseract was NOT added as an SPM dependency — its repo is
///   archived ("no longer maintained"), its author recommends Vision, it
///   pulls a ~219MB binary xcframework, and it has a known App Store
///   Connect submission quirk. Wiring it in later is a one-line
///   `Package.swift` + `Project.swift` change if the owner wants it.
/// * The Homebrew CLI is the maintained Tesseract 5.5.x on Apple Silicon
///   (`brew install tesseract tesseract-lang`), needs no build-time
///   dependency, and keeps the app bundle at ~5MB.
/// * The dpScreenOCR app itself was NOT ported (Qt, Windows+Linux only) —
///   only its engine + on-demand language-download workflow was reused.
///
/// DISABLED by default and fallback-only: Vision stays the primary engine.
/// The owner must compare Vision vs Tesseract on real Vietnamese photos on
/// a Mac before Tesseract is ever considered for primary use.
struct TesseractOCRProvider: OcrProvider {
    let id = OcrProviderID.tesseract.rawValue
    let displayName = String(localized: "Tesseract (fallback)")
    /// No network at recognition time; language downloads need it once.
    let needsNetwork = false
    let needsAPIKey = false

    /// BCP 47 codes with language data installed on this Mac.
    var supportedLanguages: [String] {
        TesseractLanguageDataManager.installedCodes().map {
            TesseractLanguageDataManager.bcp47(forTessCode: $0)
        }
    }

    var status: String {
        guard Self.isEngineAvailable else {
            return String(localized: "Not installed — run: brew install tesseract tesseract-lang")
        }
        let installed = TesseractLanguageDataManager.installedCodes()
        if installed.isEmpty {
            return String(localized: "Installed, no languages downloaded yet")
        }
        return String(localized: "Ready (\(installed.joined(separator: ", ")))")
    }

    /// Known Homebrew / MacPorts / system install locations.
    static let cliSearchPaths = [
        "/opt/homebrew/bin/tesseract", // Apple Silicon Homebrew
        "/usr/local/bin/tesseract", // Intel Homebrew
        "/opt/local/bin/tesseract", // MacPorts
        "/usr/bin/tesseract",
    ]

    /// The `tesseract` binary, if one is installed.
    static var cliURL: URL? {
        cliSearchPaths
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var isEngineAvailable: Bool { cliURL != nil }

    /// Languages to pass to `tesseract -l`, from the user's OCR language
    /// setting, filtered to data actually installed on this Mac.
    /// Falls back to `eng` when nothing requested is installed.
    static func effectiveLanguages(
        requested: [String],
        installed: [String]
    ) -> [String] {
        let installedSet = Set(installed)
        let codes = requested.compactMap { TesseractLanguageDataManager.tessCode(forBCP47: $0) }
            .filter { installedSet.contains($0) }
        if codes.isEmpty { return ["eng"] }
        // De-duplicate, keep request order.
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    func recognizeText(in cgImage: CGImage) async throws -> String {
        guard let cli = Self.cliURL else {
            throw OCRError.tesseractNotInstalled
        }
        let languages = Self.effectiveLanguages(
            requested: Defaults[.ocrLanguages],
            installed: TesseractLanguageDataManager.installedCodes()
        )
        // Tesseract needs every requested language installed; if even the
        // fallback `eng` is missing, say so instead of failing cryptically.
        let installed = TesseractLanguageDataManager.installedCodes()
        guard languages.allSatisfy({ installed.contains($0) }) else {
            throw OCRError.tesseractNotInstalled
        }
        TesseractLanguageDataManager.ensureLanguageLinks(for: languages)

        let pngData: Data = try autoreleasepool {
            guard let rep = NSBitmapImageRep(cgImage: cgImage),
                  let data = rep.representation(using: .png, properties: [:])
            else { throw OCRError.captureReadFailed }
            return data
        }

        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("transpeek_tess_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try pngData.write(to: tmpURL)

        let (status, stdout, stderr) = try await runProcess(
            executable: cli,
            arguments: [
                tmpURL.path, "stdout",
                "--tessdata-dir", TesseractLanguageDataManager.tessdataDirectory.path,
                "-l", languages.joined(separator: "+"),
                "--psm", "3",
            ]
        )
        let text = String(data: stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if status != 0 {
            let detail = String(data: stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw OCRError.engineFailed(detail.isEmpty ? "tesseract exited with status \(status)" : detail)
        }
        if text.isEmpty {
            throw OCRError.noTextRecognized
        }
        return text
    }

    /// Run a process to completion, capturing stdout/stderr. Cancellation
    /// terminates the child process (mirrors `ScreenCaptureOCR`'s pattern).
    private func runProcess(
        executable: URL,
        arguments: [String]
    ) async throws -> (Int32, Data, Data) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, Data, Data), Error>) in
                let resumed = OSAllocatedUnfairLock(initialState: false)
                func claimOnce() -> Bool {
                    resumed.withLock { val in
                        if val { return false }
                        val = true
                        return true
                    }
                }
                process.terminationHandler = { proc in
                    guard claimOnce() else { return }
                    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let err = errPipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: (proc.terminationStatus, out, err))
                }
                do {
                    try process.run()
                } catch {
                    guard claimOnce() else { return }
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
