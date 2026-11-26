import Foundation
import Observation

// MARK: - SpeechPlayer

/// Play/pause/resume player for ONE click-to-listen unit (Manh 2026-11-26,
/// SPEECH_PLAYER.md §1 — the new speaker law, replacing "click again =
/// stop"): one speaker button = Play/Pause toggle, no separate Stop
/// button. The same player drives the float icon speaker and the panel
/// speaker button (one voice at a time — a new play stops the old one,
/// even across surfaces), and the on-page chaining controller uses one
/// per block. The Read mode speaker (RSVP read-along toggle) is a
/// separate control and does NOT use this player.
/// @Observable so SwiftUI (the panel speaker button) redraws its glyph
/// from `state` + `currentText`; the per-word offset and the callbacks
/// are @ObservationIgnored (they change too often / never affect UI).
@MainActor @Observable
final class SpeechPlayer {
    /// Playback state (Manh 2026-11-26): idle = no session; playing =
    /// the voice is speaking; paused = stopped mid-unit, position kept
    /// for resume. A session is live while playing OR paused. While
    /// playing the speak indicator stays visible (so the user can
    /// pause); while paused it follows the normal hide law, and when it
    /// hides the session ends silently (no Esc, no Stop button — Manh
    /// 2026-11-26).
    enum State: Equatable {
        case idle
        case playing
        case paused
    }

    private let ttsCoordinator: TTSCoordinator

    /// Current state. Observers (icon glyph, panel button) read this to
    /// show play / pause / resume. Set only through play/pause/resume/
    /// stop and the task's end handling, so the state can never drift
    /// from what the voice is actually doing.
    private(set) var state: State = .idle {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }
    /// Fires on every state change (the icon and the panel button redraw
    /// their glyph from it).
    @ObservationIgnored var onStateChange: ((State) -> Void)?
    /// Fires for each word about to be spoken, with its range in the FULL
    /// unit text (the resume offset is added back, so the caller maps it
    /// against the whole unit, not just the remaining tail).
    @ObservationIgnored var onWordRange: ((NSRange) -> Void)?
    /// Fires when the unit finishes on its own (the caller advances to
    /// the next unit, or resets for a single unit). Never fires on pause,
    /// stop, or being cut short from outside.
    @ObservationIgnored var onEnded: (() -> Void)?
    /// Fires when the session ends WITHOUT finishing the unit — a stop
    /// (the indicator hid while paused, or a new play replaced this
    /// one) or being cut short from outside (another play started).
    /// Never fires on pause (the session is suspended, not ended).
    @ObservationIgnored var onStopped: (() -> Void)?

    /// The unit being played/paused (nil when idle). Compared by the
    /// caller to tell "this unit" from "a different unit" (new play
    /// replaces old play; clicking the same paused unit resumes it).
    private(set) var currentText: String?
    /// The language of the current unit (for the resume utterance).
    @ObservationIgnored private var currentLanguage: String?
    /// Resume offset (UTF-16) in the full unit text — where the next
    /// utterance starts. 0 at play; the last spoken word's location at
    /// pause. The word ranges the TTS reports are relative to the
    /// utterance string, so this offset is added back before forwarding.
    /// Ignored by observation (it changes per word — the UI never reads it).
    @ObservationIgnored private var currentOffset = 0
    /// Generation counter: bumped on play and stop, NOT on pause. A
    /// task captures the generation at start and ignores its result when
    /// it wakes to a different one (a newer play replaced this one) —
    /// so a stale task can never end a session it no longer owns.
    @ObservationIgnored private var generation = 0
    /// The in-flight playback task (nil when idle/paused).
    @ObservationIgnored private var playTask: Task<Void, Never>?

    init(ttsCoordinator: TTSCoordinator) {
        self.ttsCoordinator = ttsCoordinator
    }

    /// Whether a session is live (playing OR paused) — the speaker icon
    /// stays visible while this is true.
    var isActive: Bool { state != .idle }
    /// Whether the given text is the unit currently playing.
    func isPlaying(_ text: String) -> Bool { state == .playing && currentText == text }
    /// Whether the given text is the unit currently paused.
    func isPaused(_ text: String) -> Bool { state == .paused && currentText == text }

    /// Play a unit from the start (Manh 2026-11-26: new play replaces
    /// old play — a different unit while playing/paused stops the old
    /// one first). One voice at a time: `stop()` below cancels any
    /// in-flight speech (this player's or another surface's) before the
    /// new utterance starts.
    func play(text: String, language: String) {
        // Stop anything currently speaking (this player's old unit, a
        // panel speak, an auto-play) — one voice at a time, and the
        // old session's task must not fire onEnded afterwards.
        stop()
        currentText = text
        currentLanguage = language
        currentOffset = 0
        state = .playing
        startTask()
    }

    /// Pause mid-unit (Manh 2026-11-26): stop the voice but KEEP the
    /// position (the last spoken word's offset) and the highlight — the
    /// user sees where they stopped, and resume continues from there.
    /// No timeout: the paused session lives indefinitely until resume or
    /// stop. Only valid while playing; a no-op otherwise.
    func pause() {
        guard state == .playing else { return }
        // Stop the voice (the in-flight speakContinuous returns false)
        // but do NOT clear the unit/offset — resume needs them. The
        // generation is NOT bumped: the waking task sees state == .paused
        // and returns without ending the session.
        state = .paused
        ttsCoordinator.stop()
    }

    /// Resume a paused unit from the kept position (Manh 2026-11-26:
    /// not from the start). Only valid while paused; a no-op otherwise.
    /// Speaks the remaining tail of the unit; the word ranges are offset
    /// back to the full unit text so the highlight keeps tracking.
    func resume() {
        guard state == .paused, let text = currentText, let language = currentLanguage else { return }
        state = .playing
        // Bump the generation so the old (paused) task, when it wakes,
        // sees a stale generation and returns without touching state.
        generation += 1
        startTask()
    }

    /// Stop the session entirely (the indicator hid while paused, or a
    /// new play replacing this one): the voice stops, the position is
    /// forgotten, the highlight is removed by the caller (onStopped),
    /// and the indicator hides. No-op when already idle. The in-flight
    /// task, when it wakes, sees the bumped generation and returns
    /// without firing anything.
    func stop() {
        guard state != .idle || playTask != nil || currentText != nil else { return }
        generation += 1
        playTask?.cancel()
        playTask = nil
        currentText = nil
        currentLanguage = nil
        currentOffset = 0
        // Stop the voice first so the in-flight speakContinuous returns
        // false (its generation check then discards it), then flip the
        // state — observers see a clean idle, never a half-stopped play.
        ttsCoordinator.stop()
        state = .idle
        onStopped?()
    }

    /// Start the playback task for the current unit from currentOffset.
    /// Captures the generation so a stale wake-up is ignored.
    private func startTask() {
        let generationAtStart = generation
        let text = currentText ?? ""
        let language = currentLanguage ?? "en"
        let offset = currentOffset
        // The tail from the resume offset (the whole unit at play). The
        // TTS reports word ranges relative to THIS string, so the offset
        // is added back in the callback to map them to the full unit.
        let tail = (text as NSString).substring(from: min(offset, (text as NSString).length))
        playTask = Task { [weak self] in
            guard let self else { return }
            let finished = await self.ttsCoordinator.speakContinuous(
                tail,
                language: language,
                onWordRange: { [weak self] range in
                    guard let self else { return }
                    // The word's location in the FULL unit text (the
                    // tail's offset added back) — the resume position
                    // and the highlight both map against the whole unit.
                    let fullRange = NSRange(location: range.location + offset, length: range.length)
                    self.currentOffset = fullRange.location
                    self.onWordRange?(fullRange)
                }
            )
            // A newer play/stop bumped the generation — this task no
            // longer owns the session; return without touching state.
            guard self.generation == generationAtStart else { return }
            self.playTask = nil
            if finished {
                // The unit ended on its own: reset the position and end
                // the session (the caller advances or resets via onEnded).
                self.currentText = nil
                self.currentLanguage = nil
                self.currentOffset = 0
                self.state = .idle
                self.onEnded?()
            } else if self.state == .paused {
                // Paused while speaking: the session is suspended, not
                // ended — return without clearing anything (the offset
                // and highlight stay for resume).
                return
            } else {
                // Cut short from outside (another play started, an
                // auto-play spoke) while still marked playing: the
                // session is over — end it so the icon/overlay clear.
                self.currentText = nil
                self.currentLanguage = nil
                self.currentOffset = 0
                self.state = .idle
                self.onStopped?()
            }
        }
    }
}
