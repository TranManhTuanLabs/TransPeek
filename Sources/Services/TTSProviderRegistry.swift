import Defaults
import Foundation
import Observation

/// Container for all registered TTS providers. Single-selection model:
/// only one provider is active at a time, stored in Defaults.
@MainActor @Observable
final class TTSProviderRegistry {
    private(set) var providers: [any TTSProvider]

    init(providers: [any TTSProvider]) {
        precondition(!providers.isEmpty, "TTSProviderRegistry requires at least one provider")
        self.providers = providers
    }

    /// The currently selected TTS provider.
    var activeProvider: any TTSProvider {
        provider(withID: Defaults[.ttsProvider]) ?? providers[0]
    }

    func provider(withID id: String) -> (any TTSProvider)? {
        providers.first { $0.id == id }
    }

    static func builtIn() -> TTSProviderRegistry {
        TTSProviderRegistry(providers: [
            AppleTTSProvider(),
            // Edge is optional and never the default (SPEC §4.3 / §5 M2+M3):
            // it sits in the fallback chain after the chosen engine.
            EdgeTTSProvider(),
        ])
    }
}
