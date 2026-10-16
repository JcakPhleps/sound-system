import SwiftUI

/// A compact menu in the header for switching themes.
struct ThemePickerView: View {
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
            HStack(spacing: 6) {
                if theme.chrome == .glass {
                    Image(systemName: "paintpalette").font(.system(size: 10))
                }
                Text(theme.text(theme.name))
                    .font(theme.font(10, .semibold))
                    .tracking(theme.tracking)
            }
            .foregroundStyle(theme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
