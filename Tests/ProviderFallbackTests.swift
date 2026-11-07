import SwiftUI
import Testing
@testable import MoePeek

/// TransPeek Phase 1: `orderedSlots(primaryID:fallbackID:)` reorders the
/// enabled slots so the primary provider comes first, the fallback second,
/// and the rest keep their existing order. Pure ordering logic — it does not
/// change which providers translate (the coordinator still runs all enabled
/// providers in parallel).
@Suite
@MainActor
struct ProviderFallbackTests {
    @Test func putsPrimaryFirstFallbackSecondAndPreservesRestOrder() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("openai"), stub("apple"), stub("deepl")],
            enabled: ["google", "openai", "apple", "deepl"],
            order: ["google", "openai", "apple", "deepl"]
        )

        let ordered = registry.orderedSlots(primaryID: "deepl", fallbackID: "apple")

        #expect(ordered.map(\.id) == ["deepl", "apple", "google", "openai"])
    }

    @Test func ignoresUnknownIDs() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("openai"), stub("apple")],
            enabled: ["google", "openai", "apple"],
            order: ["google", "openai", "apple"]
        )

        let ordered = registry.orderedSlots(primaryID: "no-such-provider", fallbackID: "also-unknown")

        #expect(ordered.map(\.id) == ["google", "openai", "apple"])
    }

    @Test func returnsEnabledSlotsUnchangedWhenBothIDsAreEmpty() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("openai"), stub("apple")],
            enabled: ["google", "openai", "apple"],
            order: ["apple", "openai", "google"]
        )

        let ordered = registry.orderedSlots(primaryID: "", fallbackID: "")

        #expect(ordered.map(\.id) == registry.enabledSlots.map(\.id))
        #expect(ordered.map(\.id) == ["apple", "openai", "google"])
    }

    @Test func ignoresPrimaryWhenNotEnabledAndPutsFallbackFirst() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("openai"), stub("apple")],
            enabled: ["google", "openai"],
            order: ["google", "openai"]
        )

        let ordered = registry.orderedSlots(primaryID: "apple", fallbackID: "openai")

        #expect(ordered.map(\.id) == ["openai", "google"])
    }

    @Test func doesNotDuplicateWhenPrimaryAndFallbackAreTheSame() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("openai"), stub("apple")],
            enabled: ["google", "openai", "apple"],
            order: ["google", "openai", "apple"]
        )

        let ordered = registry.orderedSlots(primaryID: "openai", fallbackID: "openai")

        #expect(ordered.map(\.id) == ["openai", "google", "apple"])
    }

    @Test func movesAllModelSlotsOfPrimaryProviderTogether() {
        let registry = makeRegistry(
            providers: [stub("google"), stub("multi", models: ["model-a", "model-b"]), stub("apple")],
            enabled: ["google", "multi", "apple"],
            order: ["google", "multi", "apple"]
        )

        let ordered = registry.orderedSlots(primaryID: "multi", fallbackID: "apple")

        // Slots keep the provider's activeModels order; both move together
        // ahead of the fallback because they share configurationID "multi".
        #expect(ordered.map(\.id) == ["multi:model-a", "multi:model-b", "apple", "google"])
    }

    // MARK: - Helpers

    private func makeRegistry(
        providers: [any TranslationProvider],
        enabled: Set<String>,
        order: [String]
    ) -> TranslationProviderRegistry {
        TranslationProviderRegistry(
            providers: providers,
            enabledProviderIDs: { enabled },
            providerOrder: { order },
            onDemandProviderIDs: { [] }
        )
    }

    private func stub(_ id: String, models: [String] = []) -> any TranslationProvider {
        StubProvider(id: id, models: models)
    }
}

private struct StubProvider: TranslationProvider {
    let id: String
    var models: [String] = []

    var displayName: String { id }
    let iconSystemName = "character.bubble"
    let isAvailable = true
    // Stub never streams real content (translateStream finishes immediately),
    // so it reports no streaming support like the other test stubs.
    let supportsStreaming = false
    var activeModels: [String] { models }
    @MainActor var isConfigured: Bool { true }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    @MainActor func makeSettingsView() -> AnyView {
        AnyView(EmptyView())
    }
}
