import SwiftUI

struct PermissionsView: View {
    @Environment(\.theme) private var theme
    @Environment(PermissionsManager.self) private var permissions

    var body: some View {
        HStack(spacing: 14) {
            lamp("Music", status: permissions.musicStatus)
            lamp("Spotify", status: permissions.spotifyStatus)
            Spacer()
            Button(theme.text("Automation Settings")) { permissions.openAutomationSettings() }
                .buttonStyle(.plain)
                .font(theme.font(9, .semibold))
                .tracking(theme.tracking)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 6)
        .onAppear { permissions.refresh() }
    }

    private func lamp(_ name: String, status: PermissionStatus) -> some View {
        HStack(spacing: 5) {
            LED(on: status == .granted, color: color(for: status), size: 6)
            Text(theme.text(name))
                .font(theme.font(9, .semibold))
                .tracking(theme.tracking)
                .foregroundStyle(theme.textDim)
        }
    }

    private func color(for status: PermissionStatus) -> Color {
        switch status {
        case .granted: return theme.accentSecondary
        case .denied: return theme.alarm
        default: return theme.accent
        }
    }
}
