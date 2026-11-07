import Foundation

/// Pure TTS fallback ordering (SPEC §4.3), kept free of AVFoundation /
/// `Defaults` so Swift Testing can cover it without a Mac audio stack.
///
/// Chain: chosen engine -> EdgeTTS (if online) -> System -> dictionary audio
/// (single word only) -> clear error. Never silent-fails: the coordinator
/// reports the last error when every step failed.
enum TTSPlaybackStep: Equatable, Sendable {
    /// Speak with the registered provider with this id.
    case provider(String)
    /// Play a dictionary pronunciation clip; only valid for a single word.
    case dictionaryAudio
}

enum TTSFallbackChain {
    static let edgeProviderID = EdgeTTSProvider.providerID
    static let systemProviderID = AppleTTSProvider.providerID

    /// Ordered steps for a speak request.
    /// - Parameters:
    ///   - chosenID: id of the provider the user picked in Settings.
    ///   - availableIDs: ids of the providers in the registry.
    /// - Returns: `[chosen, edge?, system?, .dictionaryAudio]`, de-duplicated,
    ///   with only providers that actually exist in the registry.
    static func steps(chosenID: String, availableIDs: [String]) -> [TTSPlaybackStep] {
        var steps: [TTSPlaybackStep] = []
        var seen = Set<String>()
        func addProvider(_ id: String) {
            guard availableIDs.contains(id), !seen.contains(id) else { return }
            seen.insert(id)
            steps.append(.provider(id))
        }
        addProvider(chosenID)
        addProvider(edgeProviderID)
        addProvider(systemProviderID)
        steps.append(.dictionaryAudio)
        return steps
    }
}
