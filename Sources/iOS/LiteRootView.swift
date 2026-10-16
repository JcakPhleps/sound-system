import SwiftUI

struct LiteRootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LiteAudioEngine.self) private var engine

    var body: some View {
        let theme = themeManager.current
        content(theme)
            .environment(\.theme, theme)
            .preferredColorScheme(theme.prefersDark ? .dark : .light)
            .onAppear { engine.start() }
    }

    private func content(_ theme: Theme) -> some View {
        VStack(spacing: 16) {
            header(theme)
            displayHero(theme)
            outputPanel
            inputPanel
            Spacer(minLength: 0)
            footer(theme)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: theme.backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private func header(_ theme: Theme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(theme.text("Conductor"))
                .font(theme.font(20, .bold))
                .tracking(theme.chrome == .pixel ? 4 : 1)
                .foregroundStyle(theme.accent)
                .themedGlow(theme, radius: 6)
            Text(theme.text("Lite"))
                .font(theme.font(20, .bold))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            LiteThemeMenu()
        }
    }

    // MARK: - Display hero

    private func displayHero(_ theme: Theme) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tag(theme, engine.isRunning ? "▶ LISTENING" : "▪ IDLE")
                Spacer()
                tag(theme, "OUT · \(engine.outputName)")
            }
            .font(theme.displayFont(10, .semibold))
            .foregroundStyle(theme.accent)

            GeometryReader { geo in
                VFDMarquee(text: "Conductor Lite — reacting to your room", width: geo.size.width, size: 18)
            }
            .frame(height: 26)

            SpectrumMeter(
                active: true,   // idle animation when not listening, real levels when running
                levels: { engine.isRunning ? engine.levels : nil },
                bars: 10, segments: 18,
                barWidth: 12, segHeight: 7, segSpacing: 3, barSpacing: 10
            )
            .frame(height: 230, alignment: .bottom)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                ForEach(eqBandFrequencies, id: \.self) { freq in
                    Text(freqLabel(freq))
                        .font(theme.displayFont(8))
                        .foregroundStyle(theme.textDim)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.chrome == .glass ? 16 : 6)
                .fill(theme.displayBackground)
                .overlay(RoundedRectangle(cornerRadius: theme.chrome == .glass ? 16 : 6)
                    .stroke(theme.accent.opacity(0.18), lineWidth: 1))
        )
    }

    private func tag(_ theme: Theme, _ text: String) -> some View {
        Text(theme.text(text)).themedGlow(theme, radius: 3)
    }

    // MARK: - Output / Input

    private var outputPanel: some View {
        MetalPanel(title: "Output") {
            HStack {
                Text(themeName(engine.outputName))
                    .lineLimit(1)
                Spacer()
                RoutePicker(tint: themeManager.current.accent)
                    .frame(width: 40, height: 40)
            }
            .modifier(BodyText())
        }
    }

    private var inputPanel: some View {
        MetalPanel(title: "Input") {
            HStack {
                Text(themeName(engine.inputName))
                    .lineLimit(1)
                Spacer()
                Menu {
                    ForEach(engine.availableInputs(), id: \.uid) { port in
                        Button(port.portName) { engine.selectInput(port) }
                    }
                } label: {
                    ThemedIcon(sf: "mic.fill", glyph: "[o]", size: 15)
                        .foregroundStyle(themeManager.current.accent)
                }
            }
            .modifier(BodyText())
        }
    }

    private func themeName(_ s: String) -> String { themeManager.current.text(s) }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ theme: Theme) -> some View {
        if engine.permission == .denied {
            Text(theme.text("Enable microphone access in Settings so the display reacts to sound."))
                .font(theme.font(10, .semibold))
                .foregroundStyle(theme.alarm)
                .multilineTextAlignment(.center)
        } else {
            Text(theme.text("Play music out loud — the display reacts to your room."))
                .font(theme.font(9))
                .foregroundStyle(theme.textDim)
        }
    }

    private func freqLabel(_ freq: Double) -> String {
        freq >= 1000 ? "\(Int(freq / 1000))K" : "\(Int(freq))"
    }
}

/// Applies the theme's body font/color to plain rows.
private struct BodyText: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content.font(theme.font(13, .semibold)).foregroundStyle(theme.textSecondary)
    }
}

private struct LiteThemeMenu: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) private var manager

    var body: some View {
        Menu {
            ForEach(manager.all) { option in
                Button {
                    manager.select(option)
                } label: {
                    if option.id == manager.current.id {
                        Label(option.name, systemImage: "checkmark")
                    } else {
                        Text(option.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if theme.chrome == .glass { Image(systemName: "paintpalette").font(.system(size: 11)) }
                Text(theme.text(theme.name))
                    .font(theme.font(11, .semibold))
                    .tracking(theme.tracking)
            }
            .foregroundStyle(theme.textSecondary)
        }
    }
}
