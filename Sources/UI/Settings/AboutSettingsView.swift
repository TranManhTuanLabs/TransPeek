import SwiftUI

// Note: the app binary is signed in CI (see the "Sign app with
// self-signed certificate" step in .github/workflows/test.yml) with
// the self-signed "TransPeek Local 100Y" certificate. That stable
// signing identity is what makes the Accessibility / Screen Recording
// permissions persist across builds — an unsigned build gets a fresh
// cdhash every time and TCC treats it as a different app.
struct AboutSettingsView: View {
    let updaterController: UpdaterController?

    @State private var showDonateQR = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // Donate card: Resources/DonateCard.png — the full official BIDV
    // VietQR card (logos, QR, name, account, bank name; black rounded
    // corners fixed to white), bundled via Project.swift `resources:
    // ["Resources/**"]`. The account is the author's own; the QR inside
    // the card was verified to decode to BIDV 2600786466 before shipping.
    private var donateCardImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "DonateCard", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("TransPeek")
                .font(.title.bold())

            // Tagline: "Translate anywhere, Peek instantly!"
            // (SPEC v0.1; also the README tagline.)
            Text("Translate anywhere, Peek instantly!")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)

            // GitHub mark (the Octocat, drawn as GitHubMarkShape so it
            // scales crisply) + the org path, right under the app name
            // — not a text-style link like the ones at the bottom, and
            // not the generic </> symbol, which reads as "code" rather
            // than GitHub.
            Link(destination: URL(string: "https://github.com/TranManhTuanLabs")!) {
                HStack(spacing: 6) {
                    GitHubMarkShape()
                        .fill(.secondary)
                        .frame(width: 20, height: 20)
                    Text("Github.com/TranManhTuanLabs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("View TranManhTuanLabs on GitHub")

            Text("Version \(appVersion) (\(buildNumber))")
                .foregroundStyle(.secondary)

            // Build stamp: CI sets CFBundleVersion to the GitHub Actions
            // run number (see test.yml), so the About tab always shows
            // exactly which CI build this is — the marketing version
            // alone (0.1.0) is the same for every build, so it cannot
            // tell builds apart. Local builds keep the project default
            // ("1") and hide the line.
            if buildNumber != "1" {
                Text("Build CI #\(buildNumber)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text("Copyright © 2025-2026 TransPeek Licensed under AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Support: the app is free — a coffee via VietQR (BIDV) keeps
            // it improving. The QR stays behind a button so the About tab
            // stays compact; the account number can be copied directly.
            Divider()
                .padding(.horizontal, 40)

            Text("Support TransPeek")
                .font(.headline)

            Text("If this app is useful to you, you can support the project by buying me a coffee!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Nếu ứng dụng này hữu ích với bạn, bạn có thể ủng hộ dự án bằng một ly cà phê!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Account: 2600786466\nHolder: TRAN MANH TUAN\nBIDV (Bank for Investment and Development of VietNam)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    showDonateQR.toggle()
                } label: {
                    Label("Show QR Code", systemImage: "qrcode")
                }
                .popover(isPresented: $showDonateQR) {
                    VStack(spacing: 12) {
                        if let cardImage = donateCardImage {
                            Image(nsImage: cardImage)
                                .resizable()
                                .interpolation(.none)
                                .frame(width: 280, height: 342)
                        }
                    }
                    .padding(16)
                }

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("2600786466", forType: .string)
                } label: {
                    Label("Copy Account Number", systemImage: "doc.on.doc")
                }
            }

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

                Link(destination: URL(string: "mailto:tuanmanhtran.vn@gmail.com")!) {
                    Label("Email", systemImage: "envelope")
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
