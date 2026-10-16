import SwiftUI

/// A small indicator light / pixel block.
struct LED: View {
    @Environment(\.theme) private var theme
    var on: Bool
    var color: Color? = nil
    var size: CGFloat = 8

    var body: some View {
        let c = color ?? theme.accent
        let shape = theme.chrome == .glass ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 1))
        return shape
            .fill(on ? c : c.opacity(0.14))
            .frame(width: size, height: size)
            .shadow(color: on && theme.usesGlow ? c.opacity(0.9) : .clear, radius: on && theme.usesGlow ? 4 : 0)
    }
}

/// A framed module: flat glowing card in pixel chrome, translucent material in
/// glass chrome.
struct MetalPanel<Content: View>: View {
    @Environment(\.theme) private var theme
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius)
        let stack = VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(theme.chrome == .pixel ? "[ \(theme.text(title)) ]" : theme.text(title))
                    .font(theme.font(theme.chrome == .pixel ? 10 : 11, .semibold))
                    .tracking(theme.tracking + (theme.chrome == .pixel ? 1 : 0))
                    .foregroundStyle(theme.textSecondary)
                    .themedGlow(theme, radius: 3)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)

        if theme.chrome == .glass {
            stack.liquidGlass(cornerRadius: theme.cornerRadius, fallbackFill: theme.panelFill)
        } else {
            stack.background(shape.fill(theme.panelFill).overlay(shape.stroke(theme.panelStroke, lineWidth: 1)))
        }
    }
}

/// A chunky push-button that adapts to the theme's chrome.
struct RetroButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var minWidth: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, tint: tint, minWidth: minWidth)
    }

    struct ButtonBody: View {
        @Environment(\.theme) private var theme
        let configuration: ButtonStyleConfiguration
        let tint: Color?
        let minWidth: CGFloat

        var body: some View {
            let color = tint ?? theme.accent
            let pressed = configuration.isPressed
            let radius: CGFloat = theme.chrome == .glass ? 10 : 4
            let base = configuration.label
                .font(theme.font(15, .semibold))
                .foregroundStyle((theme.chrome == .glass && pressed) ? Color.white : color)
                .themedGlow(theme, color, radius: pressed ? 8 : 3)
                .frame(minWidth: minWidth, minHeight: 40)
                .padding(.horizontal, 10)

            Group {
                if theme.chrome == .glass {
                    base.liquidGlass(
                        cornerRadius: radius,
                        tint: pressed ? color.opacity(0.6) : nil,
                        interactive: true,
                        fallbackFill: pressed ? color.opacity(0.18) : Color.white.opacity(0.04))
                } else {
                    let shape = RoundedRectangle(cornerRadius: radius)
                    base.background(
                        shape.fill(pressed ? color.opacity(0.22) : color.opacity(0.08))
                            .overlay(shape.stroke(pressed ? color : theme.panelStroke, lineWidth: 1)))
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
        }
    }
}