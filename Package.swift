// swift-tools-version: 6.0
@preconcurrency import PackageDescription

let package = Package(
    name: "TransPeek",
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "2.3.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.5.0"),
        // Tesseract OCR engine (fallback when Vision can't do it, Manh
        // 2026-11-20): community XCFramework via SPM binary target
        // (Tesseract 5.5.x, arm64, statically built with Leptonica).
        // Tessdata is NOT included — language files are bundled /
        // downloaded separately (see TesseractLanguageDataManager).
        .package(url: "https://github.com/lexiaoyao20/tesseract-Apple.git", from: "5.5.1"),
    ]
)
