import Foundation

/// Where a finished read can be shared to (Manh 2026-11-18, from
/// testing v0.1.3.226): when the completion line appears, a row of
/// share buttons shows next to it — one per platform.
///
/// The link shared is always the TransPeek repo (never `u=undefined`,
/// which is how SwiftRead's Facebook share link is broken). The text
/// shared is option A (Manh's pick): the real stats of the finished
/// read — "I just read X words in Y with TransPeek Fast Read — read
/// 2–3x faster and improve your learning experience!"
///
/// Pre-fill differs by platform: X / Threads / Reddit / Mail take the
/// text; Facebook and LinkedIn take only the link. Facebook removed
/// the `quote` parameter from sharer.php (it is silently ignored —
/// the preview comes from the page's Open Graph tags and the user
/// types their own caption), so there is no `quote` here on purpose
/// (Manh 2026-11-18).
enum RSVPSharePlatform: String, CaseIterable {
    case facebook
    case threads
    case x
    case reddit
    case linkedIn
    case mail

    /// Short name shown in the tooltip.
    var displayName: String {
        switch self {
        case .facebook: return "Facebook"
        case .threads: return "Threads"
        case .x: return "X"
        case .reddit: return "Reddit"
        case .linkedIn: return "LinkedIn"
        case .mail: return "Mail"
        }
    }

    /// The repo URL shared with every post (the `u=` / `url=` value).
    static let sharedURL = "https://github.com/TranManhTuanLabs/TransPeek"

    /// Build the share URL for this platform. Returns nil only if the
    /// URL cannot be built (it always can for these fixed templates).
    /// Uses URLComponents so the text is percent-encoded correctly.
    func shareURL(text: String) -> URL? {
        switch self {
        case .facebook:
            // Link only: sharer.php takes `u` and ignores `quote`
            // (removed by Facebook — the preview comes from the repo
            // page's Open Graph tags, the user types their own text).
            var components = URLComponents(string: "https://www.facebook.com/sharer/sharer.php")
            components?.queryItems = [
                URLQueryItem(name: "u", value: Self.sharedURL),
            ]
            return components?.url
        case .threads:
            // Threads has no `url=` param on its intent — the link goes
            // at the end of the text.
            var components = URLComponents(string: "https://www.threads.net/intent/post")
            components?.queryItems = [
                URLQueryItem(name: "text", value: "\(text) \(Self.sharedURL)"),
            ]
            return components?.url
        case .x:
            var components = URLComponents(string: "https://twitter.com/intent/tweet")
            components?.queryItems = [
                URLQueryItem(name: "text", value: text),
                URLQueryItem(name: "url", value: Self.sharedURL),
            ]
            return components?.url
        case .reddit:
            var components = URLComponents(string: "https://www.reddit.com/submit")
            components?.queryItems = [
                URLQueryItem(name: "url", value: Self.sharedURL),
                URLQueryItem(name: "title", value: text),
            ]
            return components?.url
        case .linkedIn:
            // LinkedIn's share-offsite takes only the URL, no text.
            var components = URLComponents(string: "https://www.linkedin.com/sharing/share-offsite/")
            components?.queryItems = [
                URLQueryItem(name: "url", value: Self.sharedURL),
            ]
            return components?.url
        case .mail:
            var components = URLComponents(string: "mailto:")
            components?.queryItems = [
                URLQueryItem(name: "subject", value: "TransPeek"),
                URLQueryItem(name: "body", value: "\(text)\n\n\(Self.sharedURL)"),
            ]
            return components?.url
        }
    }
}
