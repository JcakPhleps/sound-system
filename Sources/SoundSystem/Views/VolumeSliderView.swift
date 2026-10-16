import SwiftUI

struct VolumeSliderView: View {
    @Environment(\.theme) private var theme
    @Environment(VolumeController.self) private var volume

    var body: some View {
        MetalPanel(title: "Master Volume") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(volume.isMuted ? theme.text("Mute") : "\(Int((volume.volume * 100).rounded()))")
                        .font(theme.displayFont(40, .bold))
                        .foregroundStyle(volume.isMuted ? theme.alarm : theme.accent)
                        .themedGlow(theme, volume.isMuted ? theme.alarm : theme.accent, radius: 8)
                        .monospacedDigit()
                    Text(volume.isMuted ? "" : theme.text("db"))
                        .font(theme.font(14, .semibold))
                        .foregroundStyle(theme.textDim)
                    Spacer()
                    Button { volume.toggleMute() } label: {
                        ThemedIcon(sf: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                   glyph: volume.isMuted ? "X" : "<)")
                    }
                    .buttonStyle(RetroButtonStyle(tint: volume.isMuted ? theme.alarm : theme.accent, minWidth: 44))
                }

                MatrixBar(
                    value: Binding(get: { volume.volume }, set: { volume.setVolume($0) }),
                    enabled: volume.isAvailable
                )

                if !volume.isAvailable {
                    Text(theme.text("No software volume on this output"))
                        .font(theme.font(8, .semibold))
                        .tracking(theme.tracking)
                        .foregroundStyle(theme.textDim)
                }
            }
        }
    }
}
