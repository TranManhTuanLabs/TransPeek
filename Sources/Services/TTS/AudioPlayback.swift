import AVFoundation
import Foundation

/// Shared MP3 playback for URL-based TTS providers (Edge TTS, dictionary audio).
/// One player at a time: starting a new clip stops the previous one, and
/// `stop()` is what `TTSCoordinator.stop()` calls for non-`TTSProvider` steps.
/// All state is `@MainActor`-isolated; callers run on the main actor already.
@MainActor
enum AudioPlayback {
    private static var player: AVAudioPlayer?

    /// Play MP3 `data` to completion (or until cancelled / `stop()` is called).
    /// Throws `CancellationError` when the surrounding task is cancelled.
    static func play(data: Data, rate: Float) async throws {
        stop()
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(data: data)
        } catch {
            throw TTSError.playbackFailed(error.localizedDescription)
        }
        player.enableRate = true
        player.rate = min(max(rate, 0.5), 2.0)
        self.player = player
        guard player.play() else {
            self.player = nil
            throw TTSError.playbackFailed(String(localized: "Audio playback failed to start"))
        }
        while player.isPlaying {
            try await Task.sleep(for: .milliseconds(100))
            try Task.checkCancellation()
        }
        self.player = nil
    }

    static func stop() {
        player?.stop()
        player = nil
    }
}
