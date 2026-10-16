import SwiftUI

struct SongSelectionView: View {
    @Environment(\.theme) private var theme
    @Environment(TransportController.self) private var transport
    @Environment(\.dismiss) private var dismiss

    private var player: LocalPlayer { transport.localPlayer }

    var body: some View {
        VStack(spacing: 16) {
            header
            statusLine
            playlist
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 460)
        .background(
            LinearGradient(colors: theme.backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .preferredColorScheme(theme.prefersDark ? .dark : .light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(theme.text("USB · Songs"))
                .font(theme.font(20, .bold))
                .foregroundStyle(theme.accent)
                .themedGlow(theme, radius: 6)
            Spacer()
            Button(theme.text("Add Songs")) {
                let urls = LocalPlayer.pickAudioFiles()
                if !urls.isEmpty {
                    transport.setSource(.usb)
                    player.add(urls)
                }
            }
            .buttonStyle(RetroButtonStyle(tint: theme.accent, minWidth: 90))
            Button(theme.text("Done")) { dismiss() }
                .buttonStyle(RetroButtonStyle(minWidth: 66))
        }
    }

    private var statusLine: some View {
        let connected = LocalPlayer.usbConnected
        return HStack(spacing: 8) {
            LED(on: connected, color: connected ? theme.accentSecondary : theme.textDim, size: 7)
            Text(theme.text(connected ? "USB connected" : "No signal — no USB detected (you can still add files)"))
                .font(theme.font(10, .semibold))
                .tracking(theme.tracking)
                .foregroundStyle(theme.textDim)
            Spacer()
        }
    }

    @ViewBuilder
    private var playlist: some View {
        if player.playlist.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                ThemedIcon(sf: "music.note.list", glyph: "( )", size: 30)
                    .foregroundStyle(theme.textDim)
                Text(theme.text("No songs yet — Add Songs to build a playlist"))
                    .font(theme.font(11))
                    .foregroundStyle(theme.textDim)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(player.playlist.enumerated()), id: \.offset) { index, url in
                        RetroSelectButton(
                            title: url.deletingPathExtension().lastPathComponent,
                            systemImage: (index == player.currentIndex && player.isPlaying) ? "speaker.wave.2.fill" : "music.note",
                            isOn: index == player.currentIndex
                        ) {
                            transport.setSource(.usb)
                            player.playIndex(index)
                        }
                    }
                }
            }
        }
    }
}
