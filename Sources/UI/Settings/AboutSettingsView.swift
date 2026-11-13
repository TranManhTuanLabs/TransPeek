import SwiftUI

// Note: the app binary is signed in CI (see the "Sign app with
// self-signed certificate" step in .github/workflows/test.yml) with
// the self-signed "TransPeek Self-Signed 100Years" certificate. That
// stable signing identity is what makes the Accessibility / Screen
// Recording permissions persist across builds — an unsigned build gets
// a fresh cdhash every time and TCC treats it as a different app.
struct AboutSettingsView: View {
    let updaterController: UpdaterController?

    @State private var showDonateQR = false
    @State private var accountNumberCopied = false

    // Slogan size: 17pt at the default Dynamic Type size, scaling with
    // the Text Size setting (SettingsView sets .dynamicTypeSize from
    // appTextSize). @ScaledMetric is the way to make a specific point
    // size follow Dynamic Type — Font.system(size:) has no relativeTo
    // parameter. At the default Text Size (14 = .large) this is 17pt,
    // the +2 the user asked for; dragging Text Size up/down scales it.
    @ScaledMetric(relativeTo: .subheadline) private var sloganSize: CGFloat = 17

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
            // (SPEC v0.1; also the README tagline.) 17pt at the default
            // Text Size, scaling with the Text Size setting via
            // sloganSize (@ScaledMetric above).
            Text("Translate anywhere, Peek instantly!")
                .font(.system(size: sloganSize))
                .italic()
                .foregroundStyle(.secondary)

            // GitHub mark (the Octocat, drawn as GitHubMarkShape so it
            // scales crisply) + the org path, right under the app name
            // — not a text-style link like the ones at the bottom, and
            // not the generic </> symbol, which reads as "code" rather
            // than GitHub. The cat stays black (primary: black in light
            // mode, white in dark mode) and the text stays blue, but
            // both are inside the same Link so the whole row is
            // clickable — the colors are independent, they do not have
            // to be all blue or all black.
            Link(destination: URL(string: "https://github.com/TranManhTuanLabs")!) {
                HStack(spacing: 6) {
                    GitHubMarkShape()
                        .fill(.primary)
                        .frame(width: 20, height: 20)
                    Text("Github.com/TranManhTuanLabs")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.link)
            .help("View TranManhTuanLabs on GitHub")

            // Release line: version + CI build in one line, linked to the
            // Releases page so users can see every release. CI sets
            // CFBundleVersion to the GitHub Actions run number (see
            // test.yml), so this always shows exactly which CI build it
            // is — the marketing version alone (0.1.1) is the same for
            // every build. Local builds keep the project default ("1")
            // and show no build number, since there is no CI build.
            // Plain style (not blue) — the repo link above is the blue
            // one that signals "clickable".
            Link(destination: URL(string: "https://github.com/TranManhTuanLabs/TransPeek/releases")!) {
                Text(buildNumber == "1"
                    ? "Release \(appVersion)"
                    : "Release \(appVersion) (Build CI #\(buildNumber))")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("View all TransPeek releases on GitHub")

            Text("Copyright © 2025-2026 TransPeek Licensed under AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Updater — above Support (moved up 2026-11-13: checking for
            // updates is used more often than the donate section).
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

            // Support: the app is free — a coffee via VietQR (BIDV) keeps
            // it improving. The QR stays behind a button so the About tab
            // stays compact; the account number can be copied directly.
            Divider()
                .padding(.horizontal, 40)

            Text("Support TransPeek")
                .font(.headline)

            // Only the Support text scrolls — the two buttons below stay
            // fixed so they are always reachable, even when the text is
            // taller than the visible area. The Support text uses the
            // default body font (like the Release line and the main
            // Settings text), not a fixed subheadline — so it scales
            // with the Text Size setting, and the system font supports
            // Vietnamese diacritics.
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    // The two bilingual sentences sit close together
                    // (2pt apart), with the account block 8pt below.
                    VStack(spacing: 2) {
                        Text("If this app is useful to you, you can support the project by buying me a coffee!")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Nếu ứng dụng này hữu ích với bạn, bạn có thể ủng hộ dự án bằng một ly cà phê!")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("Account: 2600786466\nHolder: TRAN MANH TUAN\nBIDV (Bank for Investment and Development of Vietnam)")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            }

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
                    accountNumberCopied = true
                    // Back to the normal label after 2 seconds.
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        accountNumberCopied = false
                    }
                } label: {
                    if accountNumberCopied {
                        Label("Copied", systemImage: "checkmark")
                    } else {
                        Label("Copy Account Number", systemImage: "doc.on.doc")
                    }
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
