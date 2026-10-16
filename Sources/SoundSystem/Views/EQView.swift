import SwiftUI

struct EQView: View {
    @Environment(\.theme) private var theme
    @Environment(EQController.self) private var eq

    var body: some View {
        MetalPanel(title: "Graphic Equalizer") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    RetroSelectButton(title: "EQ", systemImage: "power", isOn: eq.isEnabled) {
                        eq.setEnabled(!eq.isEnabled)
                    }
                    .frame(width: 90)

                    ForEach(EQPreset.all) { preset in
                        RetroSelectButton(
                            title: preset.name,
                            systemImage: nil,
                            isOn: eq.selectedPresetName == preset.name
                        ) {
                            eq.apply(preset)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(eqBandFrequencies.enumerated()), id: \.offset) { index, freq in
                        RetroFader(
                            value: Binding(
                                get: { eq.gains[index] },
                                set: { eq.setGain($0, at: index) }
                            ),
                            label: freqLabel(freq)
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .opacity(eq.isEnabled ? 1 : 0.45)
                .disabled(!eq.isEnabled)

                if let error = eq.engineError {
                    Text(theme.text("EQ engine: \(error)"))
                        .font(theme.font(8, .semibold))
                        .tracking(theme.tracking)
                        .foregroundStyle(theme.alarm)
                } else if eq.isEnabled {
                    Text(theme.text("System-wide EQ active — all audio"))
                        .font(theme.font(8, .semibold))
                        .tracking(theme.tracking)
                        .foregroundStyle(theme.accentSecondary)
                }
            }
        }
    }

    private func freqLabel(_ freq: Double) -> String {
        freq >= 1000 ? "\(Int(freq / 1000))K" : "\(Int(freq))"
    }
}
