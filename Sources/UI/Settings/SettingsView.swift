import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry
    let ttsRegistry: TTSProviderRegistry
    let ttsCoordinator: TTSCoordinator
    let updaterController: UpdaterController?

    @Default(.selectedSettingsTab) private var selectedTab

    /// Sections in the order they appear in the top bar.
    private let tabs: [SettingsTab] = [
        .general, .excludedApps, .services, .providerOrder,
        .dictionary, .ocr, .audio, .about,
    ]

    private var tabHeight: CGFloat {
        switch selectedTab {
        case .general: return 840
        case .excludedApps: return 480
        case .services: return 580
        case .providerOrder: return 520
        case .dictionary: return 520
        case .ocr: return 520
        case .audio: return 520
        case .about: return 420
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Apple-style top tab bar: the sections spread horizontally
            // across the top as a segmented control, instead of the
            // TabView sidebar list that hid sections on the side.
            Picker("", selection: $selectedTab) {
                ForEach(tabs, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.top, .horizontal], 12)

            Divider()
                .padding(.top, 8)

            // Content of the selected section. Each section is a Form
            // (or List) that scrolls, so a shorter window never hides
            // content at the bottom.
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .excludedApps:
                    ExcludedAppsSettingsView()
                case .services:
                    ServiceSettingsView(registry: registry)
                case .providerOrder:
                    ProviderOrderSettingsView(registry: registry)
                case .dictionary:
                    Form {
                        DictionarySettingsView()
                    }
                case .ocr:
                    OCRSettingsView()
                case .audio:
                    TTSSettingsView(registry: ttsRegistry, translationRegistry: registry, coordinator: ttsCoordinator)
                case .about:
                    AboutSettingsView(updaterController: updaterController)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The window is resizable (see SettingsWindowController): the
        // 420 floor lets it shrink below a section's ideal height, and
        // the scrolling Form/List content takes over instead of clipping
        // the bottom of the window off-screen.
        .frame(minWidth: 720, idealWidth: 720, minHeight: 420, idealHeight: tabHeight)
    }
}

// MARK: - Tab metadata (same titles/icons as the old TabView items)

private extension SettingsTab {
    var title: String {
        switch self {
        case .general: return "General"
        case .excludedApps: return "Excluded Apps"
        case .services: return "Services"
        case .providerOrder: return "Order"
        case .dictionary: return "Dictionary"
        case .ocr: return "OCR"
        case .audio: return "Audio"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .excludedApps: return "xmark.app"
        case .services: return "globe"
        case .providerOrder: return "list.number"
        case .dictionary: return "book"
        case .ocr: return "text.viewfinder"
        case .audio: return "speaker.wave.2"
        case .about: return "info.circle"
        }
    }
}
