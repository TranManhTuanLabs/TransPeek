import SwiftUI

struct AboutSettingsView: View {
    let updaterController: UpdaterController?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("TransPeek")
                .font(.title.bold())

            // GitHub mark (the Octocat, drawn as GitHubMarkShape so it
            // scales crisply) + the word "GitHub", right under the app
            // name — not a text-style link like the ones at the bottom,
            // and not the generic </> symbol, which reads as "code"
            // rather than GitHub.
            Link(destination: URL(string: "https://github.com/TranManhTuanLabs/TransPeek")!) {
                HStack(spacing: 6) {
                    GitHubMarkShape()
                        .fill(.secondary)
                        .frame(width: 20, height: 20)
                    Text("GitHub")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("View TransPeek on GitHub")

            Text("Version \(appVersion) (\(buildNumber))")
                .foregroundStyle(.secondary)

            // Build stamp: CI sets CFBundleVersion to the GitHub Actions
            // run number (see test.yml), so the About tab always shows
            // exactly which CI build this is — the marketing version
            // alone (0.21.0) is the same for every build, so it cannot
            // tell builds apart. Local builds keep the project default
            // ("1") and hide the line.
            if buildNumber != "1" {
                Text("Build CI #\(buildNumber)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text("Copyright © 2025-2026 TransPeek. Fork of MoePeek by cosZone, licensed under AGPL-3.0.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Licensed under AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let updaterController {
                @Bindable var updater = updaterController

                Divider()
                    .padding(.horizontal, 40)

                HStack(spacing: 16) {
                    Button("Check for Updates...") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)

                    Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/TranManhTuanLabs/TransPeek/issues")!) {
                    Label("Issue Feedback", systemImage: "ladybug")
                }
                .buttonStyle(.link)

                Link(destination: URL(string: "https://github.com/TranManhTuanLabs/TransPeek/discussions")!) {
                    Label("Community Discussions", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
