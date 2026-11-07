import AVFoundation
import Defaults
import Foundation
import SwiftUI

// MARK: - Edge Voice Selection (pure logic)

/// A resolved Edge voice: the neural voice name plus the locale its SSML
/// `xml:lang` must carry (e.g. `vi-VN-HoaiMyNeural` / `vi-VN`).
struct EdgeVoiceSelection: Equatable, Sendable {
    let name: String
    let locale: String
}

/// Pure voice resolution for Edge TTS, covered by Swift Testing.
/// `overrides` maps 2-letter language prefixes to a voice name the user
/// picked in Settings; empty string (or a missing key) means "Edge default".
enum EdgeTTSVoiceResolver {
    /// Default voice per language prefix. EN + VI are the v1 languages
    /// (SPEC §4.2); the rest are sensible neural defaults, overridable.
    static let defaultVoices: [String: EdgeVoiceSelection] = [
        "en": EdgeVoiceSelection(name: "en-US-AriaNeural", locale: "en-US"),
        "vi": EdgeVoiceSelection(name: "vi-VN-HoaiMyNeural", locale: "vi-VN"),
        "zh": EdgeVoiceSelection(name: "zh-CN-XiaoxiaoNeural", locale: "zh-CN"),
        "ja": EdgeVoiceSelection(name: "ja-JP-NanamiNeural", locale: "ja-JP"),
        "ko": EdgeVoiceSelection(name: "ko-KR-SunHiNeural", locale: "ko-KR"),
        "fr": EdgeVoiceSelection(name: "fr-FR-DeniseNeural", locale: "fr-FR"),
        "de": EdgeVoiceSelection(name: "de-DE-KatjaNeural", locale: "de-DE"),
        "es": EdgeVoiceSelection(name: "es-ES-ElviraNeural", locale: "es-ES"),
    ]

    /// Curated voice catalog for the Settings pickers (a slice of the 400+
    /// voices Edge exposes; the full list is fetched live by `probeVoicesList`).
    static let catalog: [EdgeVoiceSelection] = [
        EdgeVoiceSelection(name: "en-US-AriaNeural", locale: "en-US"),
        EdgeVoiceSelection(name: "en-US-GuyNeural", locale: "en-US"),
        EdgeVoiceSelection(name: "en-US-JennyNeural", locale: "en-US"),
        EdgeVoiceSelection(name: "en-GB-SoniaNeural", locale: "en-GB"),
        EdgeVoiceSelection(name: "en-GB-RyanNeural", locale: "en-GB"),
        EdgeVoiceSelection(name: "en-GB-LibbyNeural", locale: "en-GB"),
        EdgeVoiceSelection(name: "vi-VN-HoaiMyNeural", locale: "vi-VN"),
        EdgeVoiceSelection(name: "vi-VN-NamMinhNeural", locale: "vi-VN"),
        EdgeVoiceSelection(name: "zh-CN-XiaoxiaoNeural", locale: "zh-CN"),
        EdgeVoiceSelection(name: "zh-CN-YunjianNeural", locale: "zh-CN"),
        EdgeVoiceSelection(name: "ja-JP-NanamiNeural", locale: "ja-JP"),
        EdgeVoiceSelection(name: "ja-JP-KeitaNeural", locale: "ja-JP"),
        EdgeVoiceSelection(name: "ko-KR-SunHiNeural", locale: "ko-KR"),
        EdgeVoiceSelection(name: "ko-KR-InJoonNeural", locale: "ko-KR"),
        EdgeVoiceSelection(name: "fr-FR-DeniseNeural", locale: "fr-FR"),
        EdgeVoiceSelection(name: "fr-FR-HenriNeural", locale: "fr-FR"),
        EdgeVoiceSelection(name: "de-DE-KatjaNeural", locale: "de-DE"),
        EdgeVoiceSelection(name: "de-DE-ConradNeural", locale: "de-DE"),
        EdgeVoiceSelection(name: "es-ES-ElviraNeural", locale: "es-ES"),
        EdgeVoiceSelection(name: "es-ES-AlvaroNeural", locale: "es-ES"),
    ]

    /// Resolve the voice for a language code (`"en"`, `"en-US"`, `"vi"`, `"zh-Hans"`...).
    /// Precedence: user override for the 2-letter prefix -> British accent
    /// default for `en` -> per-language default -> US English default.
    static func voice(for language: String, accent: TTSAccent, overrides: [String: String]) -> EdgeVoiceSelection {
        let prefix = String(language.lowercased().prefix(2))
        if let override = overrides[prefix], !override.isEmpty,
           let known = catalog.first(where: { $0.name == override }) {
            return known
        }
        if prefix == "en", accent == .british {
            return EdgeVoiceSelection(name: "en-GB-SoniaNeural", locale: "en-GB")
        }
        return defaultVoices[prefix] ?? EdgeVoiceSelection(name: "en-US-AriaNeural", locale: "en-US")
    }

    /// SSML for one synthesis request. `rate` is the app's 0.5–2.0 multiplier,
    /// rendered as an SSML prosody percent (`+25%`, `-10%`, `+0%`).
    static func ssml(text: String, voice: EdgeVoiceSelection, rate: Float) -> String {
        let percent = Int((rate - 1) * 100)
        let rateString = String(format: "%+d%%", percent)
        return """
            <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="\(voice.locale)"><voice name="\(voice.name)"><prosody rate="\(rateString)" pitch="+0Hz">\(escape(text))</prosody></voice></speak>
            """
    }

    /// XML-escape user text for SSML. Also strips control characters Edge rejects.
    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                // Drop C0 controls except tab / newline / carriage return.
                if scalar.value < 0x20, scalar != "\t", scalar != "\n", scalar != "\r" { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}

// MARK: - Edge TTS Provider

/// Microsoft Edge Read Aloud TTS (SPEC §4.3): 400+ neural voices, free, no
/// API key, via the unofficial `speech.platform.bing.com` WebSocket endpoint
/// (same protocol as the `edge-tts` client).
///
/// OPTIONAL provider only — never the default. The endpoint is unofficial:
/// it can 401/403, rate-limit, or change without notice, so every failure
/// throws a clear `TTSError.networkError` and `TTSCoordinator` falls back
/// to System TTS. Spike 2026-11-07 (see docs/M2-M3-TESTING.md): the voices
/// list endpoint answers and the service is alive, but the synthesis
/// WebSocket could not be verified from the Linux VM (sandbox TLS proxy
/// rejects the upgrade) — live stability is an owner Mac test item.
final class EdgeTTSProvider: TTSProvider, @unchecked Sendable {
    static let providerID = "edge"

    /// The public trusted-client token the Edge Read Aloud client uses.
    /// It is not a secret (it ships in the Edge browser) and it can rotate;
    /// if synthesis starts 401ing, this is the first thing to refresh.
    static let trustedClientToken = "6A5AA1D4EAFF4E9FB9E31F4164C5A9E"
    static let voicesListURL = URL(string: "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=\(trustedClientToken)")!

    let id = providerID
    let displayName = "Edge TTS (neural, free)"
    let iconSystemName = "waveform"
    /// Reachability is checked per-request, not up front: the endpoint can
    /// flap, and a cached "unavailable" would wrongly hide a working voice.
    /// `speak` throws on failure and the coordinator falls back to System.
    let isAvailable = true
    @MainActor var isConfigured: Bool { true }

    var needsNetwork: Bool { true }
    var needsAPIKey: Bool { false }
    var quality: TTSQuality { .neural }
    var supportedLanguages: [String] {
        Array(Set(EdgeTTSVoiceResolver.catalog.map { String($0.locale.prefix(2)).lowercased() })).sorted()
    }
    var status: String {
        String(localized: "Online service (unofficial endpoint — falls back to System on failure)")
    }

    /// Maximum wall time for one synthesis request before giving up.
    static let synthesisTimeout: TimeInterval = 30

    private var socketTask: URLSessionWebSocketTask?

    @MainActor func speak(
        _ text: String,
        language: String,
        accent: TTSAccent,
        rate: Float
    ) async throws {
        let voice = EdgeTTSVoiceResolver.voice(
            for: language,
            accent: accent,
            overrides: Defaults[.edgeVoiceByLanguage]
        )
        let ssml = EdgeTTSVoiceResolver.ssml(text: text, voice: voice, rate: rate)
        let audio = try await synthesize(ssml: ssml)
        guard !audio.isEmpty else {
            throw TTSError.playbackFailed(String(localized: "Edge TTS returned no audio"))
        }
        try await AudioPlayback.play(data: audio, rate: rate)
    }

    @MainActor func stop() {
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        AudioPlayback.stop()
    }

    @MainActor func makeSettingsView() -> AnyView {
        AnyView(EdgeTTSSettingsView())
    }

    // MARK: - Availability Probe (advisory only)

    /// Fetch the live voices list. `true` means the endpoint answered with
    /// a parseable list right now; `false` does NOT disable the provider —
    /// synthesis is the authoritative check and the fallback chain covers it.
    /// (Observed 2026-11-07: a bare REST fetch of this URL 401s without the
    /// full browser headers, while the `edge-tts` client lists voices fine.)
    static func probeVoicesList() async -> Bool {
        var request = URLRequest(url: voicesListURL)
        request.setValue(Self.edgeUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data),
                  let list = json as? [[String: Any]], !list.isEmpty
            else { return false }
            return true
        } catch {
            return false
        }
    }

    // MARK: - WebSocket Synthesis

    private static let edgeUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0"

    /// Run one synthesis request and return the concatenated MP3 bytes.
    /// Throws `TTSError.networkError` on any transport/protocol failure so
    /// the caller can fall back; never returns partial audio silently.
    private func synthesize(ssml: String) async throws -> Data {
        let requestID = UUID().uuidString
        let connectionID = UUID().uuidString
        var request = URLRequest(url: URL(string:
            "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(Self.trustedClientToken)&ConnectionId=\(connectionID)")!)
        request.setValue(Self.edgeUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("chrome-extension://jdiccldimpdkmpapecpafklhmnfohhcm", forHTTPHeaderField: "Origin")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let task = URLSession.shared.webSocketTask(with: request)
        socketTask = task
        task.resume()
        defer {
            task.cancel(with: .normalClosure, reason: nil)
            if socketTask === task { socketTask = nil }
        }

        // Watchdog: a stalled handshake or a server that never ends the turn
        // must not hang the speak request forever.
        let watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.synthesisTimeout))
            await MainActor.run { self?.socketTask?.cancel(with: .goingAway, reason: nil) }
        }
        defer { watchdog.cancel() }

        do {
            try await send(.string(Self.configMessage()), on: task)
            try await send(.string(Self.ssmlMessage(ssml: ssml, requestID: requestID)), on: task)
        } catch {
            throw TTSError.networkError(Self.describe(error))
        }

        var audio = Data()
        while true {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw TTSError.networkError(Self.describe(error))
            }
            switch message {
            case let .string(text):
                if text.contains("Path:turn.end") { return audio }
                if text.contains("Path:turn.start") { continue }
                // `Path:response` / error payloads: keep listening until turn.end;
                // a 401/403 surfaces as a closed socket, handled by receive() above.
                continue
            case let .data(data):
                if let chunk = Self.audioChunk(from: data) { audio.append(chunk) }
            @unknown default:
                continue
            }
        }
    }

    /// `send` with a completion handler, wrapped for async use — the async
    /// `send(_:)` overload is newer than the async `receive()` and is not
    /// relied on here, so this compiles against the macOS 15 SDK either way.
    private func send(_ message: URLSessionWebSocketTask.Message, on task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(message) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// `speech.config` message: 24kHz 48kbit MP3, word boundaries on.
    /// Note the lone `\r` line: each header line already ends in `\r`, and
    /// the line break adds `\n`, so the blank separator line must itself be
    /// `\r` to produce the protocol's `\r\n\r\n` header/body separator.
    private static func configMessage() -> String {
        """
        Path: speech.config\r
        X-Timestamp: \(rfc1123Date())\r
        Content-Type: application/json\r
        \r
        {"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}
        """
    }

    private static func ssmlMessage(ssml: String, requestID: String) -> String {
        """
        X-RequestId: \(requestID)\r
        Content-Type: application/ssml+xml\r
        X-Timestamp: \(rfc1123Date())\r
        Path: ssml\r
        \r
        \(ssml)
        """
    }

    /// Binary frames are `Path:audio\r\n<headers>\r\n\r\n<mp3 bytes>`.
    /// Returns the MP3 bytes, or nil for non-audio frames.
    static func audioChunk(from data: Data) -> Data? {
        guard let separator = "\r\n\r\n".data(using: .utf8),
              let range = data.range(of: separator)
        else { return nil }
        let header = data.prefix(upTo: range.lowerBound)
        guard let headerString = String(data: header, encoding: .utf8),
              headerString.contains("Path:audio")
        else { return nil }
        return data.suffix(from: range.upperBound)
    }

    private static func rfc1123Date() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: Date())
    }

    private static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return String(localized: "Edge TTS is offline (\(urlError.localizedDescription))")
            case .cancelled:
                return String(localized: "Edge TTS request was cancelled")
            default:
                return String(localized: "Edge TTS network error: \(urlError.localizedDescription)")
            }
        }
        return String(localized: "Edge TTS error: \(error.localizedDescription)")
    }
}

// MARK: - Edge Settings View

private struct EdgeTTSSettingsView: View {
    @State private var probeResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                String(localized: "Free neural voices, no API key. Unofficial Microsoft endpoint — it can 403 or rate-limit; TransPeek then falls back to System TTS automatically."),
                systemImage: "info.circle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    probeResult = nil
                    Task {
                        let ok = await EdgeTTSProvider.probeVoicesList()
                        probeResult = ok
                            ? String(localized: "Edge endpoint reachable — voices list loaded.")
                            : String(localized: "Edge endpoint did not answer — synthesis will fall back to System TTS if it fails.")
                    }
                } label: {
                    Label("Check connection", systemImage: "network")
                }
                .controlSize(.small)

                if let probeResult {
                    Text(probeResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
