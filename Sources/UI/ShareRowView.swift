import SwiftUI

/// A row of share buttons — one per platform (Facebook, Threads, X,
/// Reddit, LinkedIn, Mail) — the same row as the Fast Read completion
/// window (Manh 2026-11-18) and the About tab (Manh 2026-11-19).
/// Each opens its share URL in the browser (Mail opens the mail app).
/// The link shared is always the TransPeek repo; `text` is the message
/// shared with it — the real stats of the finished read in the
/// completion window, the app tagline in About.
///
/// The three adaptive colors are the view's "text" / "page background"
/// / "secondary text" colors, so the Threads / X / Mail icons adapt to
/// the surrounding color scheme: in the Fast Read window they follow
/// the reading color scheme (White on Black / Black on White); in a
/// normal view the defaults (.primary / .background / .secondary)
/// follow the system appearance.
struct ShareRowView: View {
    let text: String
    let textColor: Color
    let pageColor: Color
    let secondaryColor: Color

    init(
        text: String,
        textColor: Color = .primary,
        pageColor: Color = .background,
        secondaryColor: Color = .secondary
    ) {
        self.text = text
        self.textColor = textColor
        self.pageColor = pageColor
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(RSVPSharePlatform.allCases, id: \.self) { platform in
                Button {
                    if let url = platform.shareURL(text: text) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    shareIcon(for: platform)
                }
                .buttonStyle(.plain)
                .help("Share on \(platform.displayName)")
            }
        }
    }

    /// A circular badge with the platform's letter (SF Symbols has no
    /// brand icons). Brand colors where they read on both schemes;
    /// Threads and X use the adaptive text/page colors because a black
    /// circle would vanish on the dark scheme.
    private func shareIcon(for platform: RSVPSharePlatform) -> some View {
        Group {
            switch platform {
            case .facebook:
                Text("f")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.09, green: 0.47, blue: 0.95))
                    .clipShape(Circle())
            case .threads:
                Text("@")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(pageColor)
                    .frame(width: 28, height: 28)
                    .background(textColor)
                    .clipShape(Circle())
            case .x:
                Text("X")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(pageColor)
                    .frame(width: 28, height: 28)
                    .background(textColor)
                    .clipShape(Circle())
            case .reddit:
                Text("R")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 1.0, green: 0.27, blue: 0.0))
                    .clipShape(Circle())
            case .linkedIn:
                Text("in")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.04, green: 0.4, blue: 0.76))
                    .clipShape(Circle())
            case .mail:
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(textColor)
                    .frame(width: 28, height: 28)
                    .background(secondaryColor.opacity(0.2))
                    .clipShape(Circle())
            }
        }
    }
}
