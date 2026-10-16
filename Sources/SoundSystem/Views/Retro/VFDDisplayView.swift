import SwiftUI

/// The display panel: now-playing marquee, status indicators, and a live
/// spectrum meter on a dark "screen" that stays dark across all themes.
struct VFDDisplayView: View {
    @Environment(\.theme) private var theme
    @Environment(TransportController.self) private var transport
    @Environment(VolumeController.self) private var volume
    @Environment(AudioDeviceManager.self) private var deviceManager
    @Environment(EQController.self) private var eq

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusRow
            GeometryReader { geo in
                VFDMarquee(text: titleText, width: geo.size.width, size: 22)
            }
            .frame(height: 30)
            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: theme.chrome == .glass ? 12 : 6)
                .fill(theme.displayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.chrome == .glass ? 12 : 6)
                        .stroke(Color.black, lineWidth: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.chrome == .glass ? 12 : 6)
                        .stroke(theme.accent.opacity(0.12), lineWidth: 1)
                        .padding(2)
                )
        )
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            tag(transport.currentSource.displayName)
            tag(stateLabel)
            Spacer()
            tag(eq.isEnabled ? "EQ ON" : "EQ")
            tag(outputLabel)
            tag(volumeLabel)
        }
        .font(theme.displayFont(10, .semibold))
        .foregroundStyle(theme.accent)
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            Text(theme.text(artistText))
                .font(theme.displayFont(11))
                .foregroundStyle(theme.accent.opacity(0.85))
                .themedGlow(theme, radius: 3)
                .lineLimit(1)
            Spacer()
            SpectrumMeter(active: transport.isPlaying, levels: { eq.spectrumLevels() })
        }
    }

    private func tag(_ text: String) -> some View {
        Text(theme.text(text))
            .tracking(theme.chrome == .pixel ? 1 : 0.5)
            .themedGlow(theme, radius: 3)
    }

    private var titleText: String {
        if let np = transport.nowPlaying, !np.title.isEmpty { return np.title }
        return "No Signal — Conductor Pro SX-01"
    }

    private var artistText: String { transport.nowPlaying?.artist ?? "" }

    private var stateLabel: String {
        guard let np = transport.nowPlaying else { return "▪ STOP" }
        return np.isPlaying ? "▶ PLAY" : "❙❙ PAUSE"
    }

    private var outputLabel: String {
        String((deviceManager.currentDefaultDevice?.name ?? "—").prefix(14))
    }

    private var volumeLabel: String {
        volume.isMuted ? "MUTE" : "VOL \(Int((volume.volume * 100).rounded()))"
    }
}
