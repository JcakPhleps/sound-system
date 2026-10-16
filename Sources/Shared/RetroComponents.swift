import SwiftUI

// MARK: - Scrolling display text

struct VFDMarquee: View {
    @Environment(\.theme) private var theme
    let text: String
    let width: CGFloat
    var size: CGFloat = 20

    private var charWidth: CGFloat { size * theme.displayAdvanceFactor }

    var body: some View {
        let full = theme.text(text)
        let textWidth = CGFloat(full.count) * charWidth

        Group {
            if textWidth <= width {
                Text(full).frame(width: width, alignment: .leading)
            } else {
                TimelineView(.animation) { context in
                    let gap: CGFloat = 48
                    let period = Double(textWidth + gap)
                    let x = (context.date.timeIntervalSinceReferenceDate * 34.0)
                        .truncatingRemainder(dividingBy: period)
                    HStack(spacing: gap) { Text(full); Text(full) }
                        .offset(x: -CGFloat(x))
                        .frame(width: width, height: size * 1.3, alignment: .leading)
                        .clipped()
                }
            }
        }
        .font(theme.displayFont(size, .bold))
        .tracking(theme.chrome == .pixel ? 2 : 0.5)
        .foregroundStyle(theme.accent)
        .themedGlow(theme, radius: 6)
    }
}

// MARK: - Spectrum meter

struct SpectrumMeter: View {
    @Environment(\.theme) private var theme
    var active: Bool
    /// Real per-band levels (10 values, 0…1) when available; nil → idle animation.
    var levels: () -> [Float]? = { nil }
    var bars: Int = 10          // one column per EQ frequency band
    var segments: Int = 8
    var barWidth: CGFloat = 5
    var segHeight: CGFloat = 4
    var segSpacing: CGFloat = 2
    var barSpacing: CGFloat = 3

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let real = levels()
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<bars, id: \.self) { i in
                    let level: Double = {
                        if let real, i < real.count { return Double(real[i]) }
                        return active ? barLevel(i, t) : 0.05
                    }()
                    VStack(spacing: segSpacing) {
                        ForEach((0..<segments).reversed(), id: \.self) { s in
                            let lit = Double(s) / Double(segments) < level
                            RoundedRectangle(cornerRadius: 1)
                                .fill(lit ? theme.accent : theme.unlit)
                                .frame(width: barWidth, height: segHeight)
                                .shadow(color: lit && theme.usesGlow ? theme.accent.opacity(0.8) : .clear,
                                        radius: lit && theme.usesGlow ? 2 : 0)
                        }
                    }
                }
            }
        }
    }

    private func barLevel(_ i: Int, _ t: TimeInterval) -> Double {
        let f = Double(i)
        let a = (sin(t * 6.1 + f * 0.9) * 0.5 + 0.5) * 0.6
        let b = (sin(t * 11.3 + f * 1.7) * 0.5 + 0.5) * 0.4
        return min(max(a + b, 0.05), 1)
    }
}

// MARK: - Theme-aware icon

/// Renders an SF Symbol on glass themes and a plain-text glyph on pixel themes,
/// so SF Symbols only ever appear on Default/Graphite.
struct ThemedIcon: View {
    @Environment(\.theme) private var theme
    let sf: String
    let glyph: String
    var size: CGFloat = 15
    var weight: Font.Weight = .semibold

    var body: some View {
        if theme.chrome == .glass {
            Image(systemName: sf).font(.system(size: size, weight: weight))
        } else if !glyph.isEmpty {
            Text(glyph).font(theme.font(size, weight))
        }
    }
}

// MARK: - Selector cell

struct RetroSelectButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let systemImage: String?
    let isOn: Bool
    var ledColor: Color? = nil
    let action: () -> Void

    var body: some View {
        let color = ledColor ?? theme.accent
        Button(action: action) {
            HStack(spacing: 8) {
                if theme.chrome == .pixel {
                    Text(isOn ? ">" : " ").font(theme.font(10, .bold))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(isOn ? 1 : 0)
                }
                // SF Symbol glyphs only appear on glass themes.
                if theme.chrome == .glass, let systemImage {
                    Image(systemName: systemImage).font(.system(size: 10))
                }
                Text(theme.text(title))
                    .font(theme.font(11, .semibold))
                    .tracking(theme.tracking)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            // On a tinted-glass selection, accent-on-accent is unreadable — use
            // a high-contrast foreground when selected.
            .foregroundStyle(isOn ? (theme.chrome == .glass ? Color.white : color) : theme.textDim)
            .themedGlow(theme, isOn ? color : .clear, radius: isOn ? 4 : 0)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .modifier(SelectSurface(isOn: isOn, color: color))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Selector-cell background: Liquid Glass in glass chrome, flat in pixel chrome.
private struct SelectSurface: ViewModifier {
    @Environment(\.theme) private var theme
    let isOn: Bool
    let color: Color

    func body(content: Content) -> some View {
        if theme.chrome == .glass {
            content.liquidGlass(
                cornerRadius: 9,
                tint: isOn ? color : nil,
                fallbackFill: isOn ? color.opacity(0.16) : Color.white.opacity(0.05))
        } else {
            let shape = RoundedRectangle(cornerRadius: 3)
            content.background(
                shape.fill(isOn ? color.opacity(0.12) : Color.clear)
                    .overlay(shape.stroke(isOn ? color.opacity(0.6) : theme.panelStroke, lineWidth: 1)))
        }
    }
}

// MARK: - Horizontal dot bar (volume)

struct MatrixBar: View {
    @Environment(\.theme) private var theme
    @Binding var value: Double          // 0...1
    var segments: Int = 28
    var height: CGFloat = 34
    var enabled: Bool = true

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<segments, id: \.self) { i in
                    let lit = Double(i) / Double(segments - 1) <= value
                    RoundedRectangle(cornerRadius: theme.chrome == .glass ? 2.5 : 1)
                        .fill(lit ? theme.accent : theme.unlit)
                        .shadow(color: lit && theme.usesGlow ? theme.accent.opacity(0.8) : .clear,
                                radius: lit && theme.usesGlow ? 3 : 0)
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                guard enabled else { return }
                value = min(max(g.location.x / geo.size.width, 0), 1)
            })
        }
        .frame(height: height)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Vertical dot column (EQ band)

struct RetroFader: View {
    @Environment(\.theme) private var theme
    @Binding var value: Double          // -12...12
    let label: String
    var height: CGFloat = 150
    var segments: Int = 13

    private let range = 24.0

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                VStack(spacing: 3) {
                    ForEach(0..<segments, id: \.self) { i in segment(at: i) }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let frac = 1 - min(max(g.location.y / geo.size.height, 0), 1)
                    value = (frac * range - 12).rounded()
                })
            }
            .frame(width: 26, height: height)

            Text(label)
                .font(theme.displayFont(8, .semibold))
                .foregroundStyle(theme.textDim)
                .fixedSize()
        }
    }

    private func segment(at i: Int) -> some View {
        let centre = segments / 2
        let capIndex = Int((1 - (value + 12) / range) * Double(segments - 1) + 0.5)
        let inFill = (i >= min(capIndex, centre) && i <= max(capIndex, centre))
        let isCap = i == capIndex
        let isCentre = i == centre

        let color: Color
        if isCap { color = theme.accent }
        else if inFill { color = theme.accent.opacity(0.5) }
        else if isCentre { color = theme.textSecondary }
        else { color = theme.unlit }

        return RoundedRectangle(cornerRadius: theme.chrome == .glass ? 2 : 1)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 8)
            .shadow(color: isCap && theme.usesGlow ? theme.accent.opacity(0.9) : .clear,
                    radius: isCap && theme.usesGlow ? 4 : 0)
    }
}
