import SwiftUI

struct RootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PermissionsManager.self) private var permissions
    @Environment(SpatialController.self) private var spatial
    @Environment(TransportController.self) private var transport
    @State private var showSpatial = false
    @State private var showSongs = false

    var body: some View {
        let theme = themeManager.current
        content(theme)
            .environment(\.theme, theme)
            .preferredColorScheme(theme.prefersDark ? .dark : .light)
            .sheet(isPresented: $showSpatial) {
                SpatialMapView()
                    .environment(\.theme, theme)
                    .environment(spatial)
            }
            .sheet(isPresented: $showSongs) {
                SongSelectionView()
                    .environment(\.theme, theme)
                    .environment(transport)
            }
    }

    private func content(_ theme: Theme) -> some View {
        VStack(spacing: 18) {
            brandHeader(theme)
            VFDDisplayView()

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 14) {
                    SourcePickerView()
                    OutputDevicePicker()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    VolumeSliderView()
                    TransportView()
                }
                .frame(maxWidth: .infinity)
            }

            EQView()
            Spacer(minLength: 0)
            PermissionsView()
        }
        .padding(28)
        .frame(maxWidth: 1180, maxHeight: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: theme.backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .onAppear {
            permissions.refresh()
            enterFullScreen()
        }
    }

    private func brandHeader(_ theme: Theme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(theme.text("Conductor Pro"))
                .font(theme.font(22, .bold))
                .tracking(theme.chrome == .pixel ? 6 : 1)
                .foregroundStyle(theme.accent)
                .themedGlow(theme, radius: 8)
            Text(theme.text("Stereo Receiver"))
                .font(theme.font(10))
                .tracking(theme.tracking + 1)
                .foregroundStyle(theme.textDim)
            Spacer()
            Button { showSongs = true } label: {
                HStack(spacing: 5) {
                    ThemedIcon(sf: "music.note.list", glyph: "[#]", size: 11)
                    Text(theme.text("Songs"))
                        .font(theme.font(10, .semibold))
                        .tracking(theme.tracking)
                }
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            Button { showSpatial = true } label: {
                HStack(spacing: 5) {
                    ThemedIcon(sf: "hifispeaker.2.fill", glyph: "[o]", size: 11)
                    Text(theme.text("Spatial"))
                        .font(theme.font(10, .semibold))
                        .tracking(theme.tracking)
                }
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            ThemePickerView()
            Text("SX-01")
                .font(theme.displayFont(11, .semibold))
                .foregroundStyle(theme.textDim)
            HStack(spacing: 6) {
                LED(on: true, color: theme.accentSecondary, size: 8)
                Text(theme.text("Power"))
                    .font(theme.font(9, .semibold))
                    .tracking(theme.tracking)
                    .foregroundStyle(theme.textDim)
            }
        }
        .padding(.horizontal, 4)
    }

    private func enterFullScreen() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { return }
            window.collectionBehavior.insert(.fullScreenPrimary)
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}
