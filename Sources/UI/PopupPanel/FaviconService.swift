import AppKit
import Foundation

/// Fetches and caches website favicons for dictionary links (SPEC §3.2).
///
/// Lookup order per host: `<host>/favicon.ico`, Google's s2 favicon service,
/// then DuckDuckGo's icon service. Results are cached in memory (published so
/// `DictionaryBarView` refreshes when a favicon lands) and on disk under
/// `Application Support/PeekTrans/Favicons/<host>.png`.
///
/// All network and disk work happens off the main actor; only the published
/// in-memory cache is touched on it. Failures are swallowed and reported as
/// `nil` — a missing favicon must never break the panel.
@MainActor
final class FaviconService: ObservableObject {
    static let shared = FaviconService()

    /// In-memory favicon cache, keyed by lowercase host.
    @Published private(set) var images: [String: NSImage] = [:]

    /// Hosts with a fetch currently in flight, so concurrent callers for the
    /// same host do not fire duplicate requests. The first caller publishes
    /// the result via `images`, so later callers see it on their next read.
    private var inFlightHosts: Set<String> = []

    private init() {}

    /// Returns the cached favicon for a link's host, if one has been loaded.
    /// Never triggers a fetch — use ``image(for:)`` for that.
    func cachedImage(for link: DictionaryLink) -> NSImage? {
        guard let host = link.host else { return nil }
        return images[host]
    }

    /// Returns the favicon for a link's host, fetching it (disk, then network)
    /// on first use. Never throws; returns `nil` when no favicon is available.
    func image(for link: DictionaryLink) async -> NSImage? {
        guard let host = link.host else { return nil }
        if let cached = images[host] { return cached }
        guard !inFlightHosts.contains(host) else { return nil }
        inFlightHosts.insert(host)
        defer { inFlightHosts.remove(host) }

        guard let data = await Self.fetchFaviconData(forHost: host) else { return nil }
        guard let image = NSImage(data: data) else {
            // Disk held bytes that no longer decode — drop them so the next
            // call retries the network instead of hitting the same bad file.
            Self.removeFromDisk(host: host)
            return nil
        }
        images[host] = image
        return image
    }

    // MARK: - Off-main-actor fetch + disk cache

    /// Disk first, then the network sources in order. Returns the raw favicon
    /// bytes (any image format `NSImage` understands), or `nil`.
    private nonisolated static func fetchFaviconData(forHost host: String) async -> Data? {
        if let diskData = loadFromDisk(host: host), !diskData.isEmpty {
            return diskData
        }

        let candidates: [URL] = [
            URL(string: "https://\(host)/favicon.ico"),
            URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32"),
            URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico"),
        ].compactMap { $0 }

        for url in candidates {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  !data.isEmpty,
                  // Filter out error pages / empty gifs served with a 200.
                  NSImage(data: data) != nil
            else { continue }
            saveToDisk(data, host: host)
            return data
        }
        return nil
    }

    // MARK: - Disk cache

    private nonisolated static var faviconsDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PeekTrans/Favicons", isDirectory: true)
    }

    private nonisolated static func diskURL(forHost host: String) -> URL? {
        faviconsDirectory?.appendingPathComponent("\(sanitizedFileName(host)).png")
    }

    /// Hosts are normally filename-safe, but sanitize anyway so a crafted
    /// template host can never escape the cache directory.
    private nonisolated static func sanitizedFileName(_ host: String) -> String {
        String(host.lowercased().map { character in
            character.isLetter || character.isNumber || character == "." || character == "-"
                ? character : "_"
        })
    }

    private nonisolated static func loadFromDisk(host: String) -> Data? {
        guard let url = diskURL(forHost: host) else { return nil }
        return try? Data(contentsOf: url)
    }

    private nonisolated static func removeFromDisk(host: String) {
        guard let url = diskURL(forHost: host) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Stores the favicon as PNG regardless of source format (`.ico` from the
    /// host, PNG from the s2/DDG services) so the on-disk cache has one known
    /// format. If PNG conversion fails the raw bytes are stored instead —
    /// `NSImage` still decodes them by sniffing the content.
    private nonisolated static func saveToDisk(_ data: Data, host: String) {
        guard let url = diskURL(forHost: host) else { return }
        var pngData: Data?
        if let image = NSImage(data: data),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            pngData = bitmap.representation(using: .png, properties: [:])
        }
        let bytes = pngData ?? data
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? bytes.write(to: url, options: [.atomic])
    }
}
