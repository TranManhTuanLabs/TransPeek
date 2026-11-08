import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry
    let ttsRegistry: TTSProviderRegistry
    let ttsCoordinator: TTSCoordinator
    let updaterController: UpdaterController?

    @Default(.selectedSettingsTab) private var selectedTab

    /// The tab the mouse is currently hovering, for a subtle hover tint.
    @State private var hoveredTab: SettingsTab?

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
            // Top tab bar: one tab per section, spread horizontally
            // across the top. Clicking a tab opens its section.
            HStack(spacing: 4) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedTab == tab
                                    ? Color.accentColor.opacity(0.18)
                                    : hoveredTab == tab
                                        ? Color.secondary.opacity(0.08)
                                        : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            hoveredTab = tab
                        } else if hoveredTab == tab {
                            hoveredTab = nil
                        }
                    }
                }
            }
            .padding([.top, .horizontal], 12)

            Divider()
                .padding(.top, 8)

            // Content of the selected section. The Dictionary and OCR
            // tabs are wrapped in a ScrollView so their content can
            // always be scrolled to the bottom (the link list grows as
            // links are added); the other sections are Forms/Lists that
            // scroll on their own.
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
                    ScrollView {
                        Form {
                            DictionarySettingsView()
                        }
                        // Same grouped look as the General tab: the plain
                        // form style stretches label + field across the
                        // whole window, which is what made this tab look
                        // bare and off-center.
                        .formStyle(.grouped)
                        .padding()
                    }
                case .ocr:
                    ScrollView {
                        OCRSettingsView()
                    }
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
