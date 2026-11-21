import SwiftUI

/// Style 2 ("basic reading") page — a scrollable reading page, not RSVP
/// chunks. The whole text is shown at once and the reader scrolls freely;
/// Play advances a focus line one line at a time (the line is Style 2's
/// focus, the way the centred chunk is Style 1's). The current line is
/// highlighted only when the "Highlight current line" toggle is on, or
/// automatically while TTS is reading this text, so the spoken line stays
/// visible. Shared by the Window Read and the Fast Read Lite panel — the
/// only difference is the horizontal padding.
struct Style2ReadingPage: View {
    @ObservedObject var viewModel: RSVPViewModel
    @Environment(\.ttsCoordinator) private var ttsCoordinator
    /// Horizontal padding (Window 32, Lite 12) — matches each surface's
    /// book page, so the page lines up with the Style 1 text.
    var horizontalPadding: CGFloat = 32

    /// The line highlight is on when the toggle is on, or automatically
    /// while TTS is reading this text (so the spoken line stays visible
    /// without the reader having to turn the toggle on first).
    private var isHighlightVisible: Bool {
        viewModel.highlightCurrentLine || (ttsCoordinator?.isPlaying(viewModel.text) ?? false)
    }

    /// Reading colors for the chosen scheme (same mapping as the Style 1
    /// book page, so the two styles never disagree on text color).
    private var readingForeground: Color {
        viewModel.colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.style2Lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            // Body size is the focus-size control scaled
                            // down (0.4×, the same ratio as the Style 1
                            // around text) — the "Focus size" picker is
                            // the font zoom for this page, so the default
                            // 80 reads as a comfortable 32pt body.
                            .font(.system(size: viewModel.fontSize * 0.4))
                            .foregroundStyle(readingForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // The focused line gets a soft highlight when
                            // highlighting is on; other lines stay plain.
                            .background(
                                isHighlightVisible && index == viewModel.style2CurrentLineIndex
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear
                            )
                            .id(index)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 16)
            }
            // Keep the focused line in view as Play advances it.
            .onChange(of: viewModel.style2CurrentLineIndex) { _, newIndex in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
