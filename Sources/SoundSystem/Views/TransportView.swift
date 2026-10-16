import SwiftUI

struct TransportView: View {
    @Environment(\.theme) private var theme
    @Environment(TransportController.self) private var transport

    var body: some View {
        MetalPanel(title: "Transport") {
            HStack(spacing: 8) {
                Button { transport.perform(.previous) } label: {
                    ThemedIcon(sf: "backward.fill", glyph: "|<")
                }
                .buttonStyle(RetroButtonStyle())

                Button { transport.perform(.playPause) } label: {
                    ThemedIcon(sf: transport.isPlaying ? "pause.fill" : "play.fill",
                               glyph: transport.isPlaying ? "||" : ">", size: 17)
                }
                .buttonStyle(RetroButtonStyle(tint: theme.accent, minWidth: 60))

                Button { transport.perform(.next) } label: {
                    ThemedIcon(sf: "forward.fill", glyph: ">|")
                }
                .buttonStyle(RetroButtonStyle())
            }
        }
    }
}
