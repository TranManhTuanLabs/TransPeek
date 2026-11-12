import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry
    let ttsRegistry: TTSProviderRegistry
    let ttsCoordinator: TTSCoordinator
    let updaterController: UpdaterController?

    @Default(.selectedSettingsTab) private var selectedTab
    @Default(.appTextSize) private var appTextSize

    /// Maps the Text Size slider (12–24, default 14) to a Dynamic Type
    /// size. 14 is the system default (.large), so there is no visible
    /// change at the default; smaller values shrink, larger values grow.
    /// Applied to the whole Settings window via the dynamicTypeSize
    /// environment so every text-style font (.body, .caption, .headline,
    /// ...) scales. Fonts that need a specific size (e.g. the About
    /// slogan, 17pt) use `.system(size: 17, relativeTo: .subheadline)`
    /// so they keep their size at the default but still scale with this
    /// setting. Note: the environment key is `.dynamicTypeSize`, not
    /// `.sizeCategory` — the latter takes a ContentSizeCategory, and
    /// passing a DynamicTypeSize to it does not compile (Tests #146).
    private var sizeCategory: DynamicTypeSize {
        switch appTextSize {
        case ...12: return .small
        case 13: return .medium
        case 14: return .large
        case 15: return .xLarge
        case 16: return .xxLarge
        case 17: return .xxxLarge
        case 18: return .accessibility1
        case 19: return .accessibility2
        case 20: return .accessibility3
        case 21: return .accessibility4
        default: return .accessibility5
        }
    }

    /// The tab the mouse is currently hovering, for a subtle hover tint.
    @State private var hoveredTab: SettingsTab?

    /// Sections in the order they appear in the top bar.
    private let tabs: [SettingsTab] = [
        .general, .excludedApps, .services, .providerOrder,
        .dictionary, .ocr, .audio, .about,
    ]

    private var tabHeight: CGFloat {
        switch selectedTab {
        case .general: return 860
        case .excludedApps: return 500
        case .services: return 600
        case .providerOrder: return 540
        case .dictionary: return 540
        case .ocr: return 540
        case .audio: return 540
        case .about: return 440
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top tab bar, favorites-bar style: one tab per section,
            // spread evenly across the full width of the window, each
            // tab centered in its share — like a browser's favorites
            // bar. This replaces the native toolbar (run #65), whose
            // icons came out small and whose labels collapsed to
            // icon-only when the window was narrow. The window title
            // stays hidden (see SettingsWindowController), so the bar
            // is the whole top of the window.
            HStack(spacing: 4) {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(tab)
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
        .environment(\.dynamicTypeSize, sizeCategory)
    }

    /// One section tab: icon on top, title underneath, centered in
    /// its equal share of the bar. The icon is .imageScale(.large)
    /// so it reads at a glance instead of the small native-toolbar
    /// size; hovering shows the section name as a tooltip. Kept as
    /// a helper so the type checker sees a small expression
    /// (inlining the whole Button inside a builder made it give up,
    /// run #57).
    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.title3)
                    .imageScale(.large)
                Text(tab.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(tabBackground(for: tab), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .onHover { hovering in
            if hovering {
                hoveredTab = tab
            } else if hoveredTab == tab {
                hoveredTab = nil
            }
        }
    }

    /// Background tint for a tab: selected gets the accent tint, a
    /// hovered (but unselected) tab gets a faint secondary tint.
    private func tabBackground(for tab: SettingsTab) -> Color {
        if selectedTab == tab {
            return Color.accentColor.opacity(0.18)
        }
        if hoveredTab == tab {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
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
