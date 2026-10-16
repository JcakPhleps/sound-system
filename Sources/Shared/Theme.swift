import Observation
import SwiftUI

/// How a theme renders its surfaces. `.pixel` = flat dark panels with glowing
/// pixel text (retro). `.glass` = translucent material panels with soft type
/// (modern Apple).
enum Chrome: Sendable { case pixel, glass }

enum FontKind: Sendable { case pixel, standard, rounded, mono, serif }

/// A complete visual theme: palette + type + surface style tokens. Components
/// read the current theme from the environment and adapt to it.
struct Theme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let blurb: String
    let chrome: Chrome

    // Palette
    let backgroundColors: [Color]     // gradient (single element = solid)
    let panelFill: Color              // pixel chrome panel background
    let panelStroke: Color
    let accent: Color                 // primary lit / active / glow
    let accentSecondary: Color        // secondary "on" state (e.g. output)
    let alarm: Color                  // mute / errors
    let textPrimary: Color
    let textSecondary: Color
    let textDim: Color
    let displayBackground: Color      // the VFD "screen"

    // Type & surface
    let fontKind: FontKind
    let displayAdvanceFactor: CGFloat // char advance ÷ point size, for marquee
    let uppercase: Bool
    let tracking: CGFloat
    let cornerRadius: CGFloat
    let usesGlow: Bool
    let glowRadius: CGFloat
    let prefersDark: Bool

    // Unlit meter/dot color.
    var unlit: Color { accent.opacity(0.16) }

    func text(_ s: String) -> String { uppercase ? s.uppercased() : s }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch fontKind {
        case .pixel:    return .custom("VT323", size: size * 1.35)
        case .standard: return .system(size: size, weight: weight)          // San Francisco
        case .rounded:  return .system(size: size * 1.04, weight: weight, design: .rounded)
        case .mono:     return .system(size: size, weight: weight, design: .monospaced)
        case .serif:    return .system(size: size * 1.04, weight: weight, design: .serif)
        }
    }

    /// Monospaced readout font used on the "screen" regardless of UI font.
    func displayFont(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        switch fontKind {
        case .pixel: return .custom("VT323", size: size * 1.35)
        default:     return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.nineties }

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies a phosphor-style glow when the theme calls for it.
    func themedGlow(_ theme: Theme, _ color: Color? = nil, radius: CGFloat? = nil) -> some View {
        shadow(color: theme.usesGlow ? (color ?? theme.accent).opacity(0.7) : .clear,
               radius: theme.usesGlow ? (radius ?? theme.glowRadius) : 0)
    }

    /// Real Liquid Glass surface on macOS 26+, with a translucent-material
    /// fallback on older systems. Used by `.glass` chrome themes.
    @ViewBuilder
    func liquidGlass(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackFill: Color
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(macOS 26, iOS 26, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(
                shape.fill(.ultraThinMaterial)
                    .overlay(shape.fill(fallbackFill))
                    .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
        }
    }
}

@available(macOS 26, iOS 26, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

// MARK: - Manager

@MainActor
@Observable
final class ThemeManager {
    var current: Theme {
        didSet { UserDefaults.standard.set(current.id, forKey: Self.key) }
    }
    let all = Theme.all
    private static let key = "themeID"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = Theme.all.first { $0.id == saved } ?? .nineties
    }

    func select(_ theme: Theme) { current = theme }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

// MARK: - Built-in themes

extension Theme {
    static let nineties = Theme(
        id: "nineties", name: "90s Hi-Fi",
        blurb: "Pioneer-blue vacuum-fluorescent receiver.",
        chrome: .pixel,
        backgroundColors: [Color(hex: 0x040710), Color(hex: 0x02040A)],
        panelFill: Color(hex: 0x050B14), panelStroke: Color(hex: 0x61BCFF).opacity(0.18),
        accent: Color(hex: 0x61BCFF), accentSecondary: Color(hex: 0x61BCFF),
        alarm: Color(hex: 0xFF5148),
        textPrimary: Color(hex: 0x61BCFF), textSecondary: Color(hex: 0x61BCFF).opacity(0.55),
        textDim: Color(hex: 0x61BCFF).opacity(0.30),
        displayBackground: Color(hex: 0x030812),
        fontKind: .pixel, displayAdvanceFactor: 0.70,
        uppercase: true, tracking: 2, cornerRadius: 4,
        usesGlow: true, glowRadius: 5, prefersDark: true)

    static let amber = Theme(
        id: "amber", name: "Amber CRT",
        blurb: "Warm amber terminal glow.",
        chrome: .pixel,
        backgroundColors: [Color(hex: 0x120C03), Color(hex: 0x080500)],
        panelFill: Color(hex: 0x140D02), panelStroke: Color(hex: 0xFFB000).opacity(0.20),
        accent: Color(hex: 0xFFB000), accentSecondary: Color(hex: 0xFFD35C),
        alarm: Color(hex: 0xFF5148),
        textPrimary: Color(hex: 0xFFB000), textSecondary: Color(hex: 0xFFB000).opacity(0.55),
        textDim: Color(hex: 0xFFB000).opacity(0.28),
        displayBackground: Color(hex: 0x0F0900),
        fontKind: .pixel, displayAdvanceFactor: 0.70,
        uppercase: true, tracking: 2, cornerRadius: 4,
        usesGlow: true, glowRadius: 5, prefersDark: true)

    static let phosphor = Theme(
        id: "phosphor", name: "Green Phosphor",
        blurb: "Classic green CRT terminal.",
        chrome: .pixel,
        backgroundColors: [Color(hex: 0x02120A), Color(hex: 0x000A05)],
        panelFill: Color(hex: 0x03130B), panelStroke: Color(hex: 0x33FF66).opacity(0.18),
        accent: Color(hex: 0x33FF66), accentSecondary: Color(hex: 0x8BFFA9),
        alarm: Color(hex: 0xFF5148),
        textPrimary: Color(hex: 0x33FF66), textSecondary: Color(hex: 0x33FF66).opacity(0.5),
        textDim: Color(hex: 0x33FF66).opacity(0.28),
        displayBackground: Color(hex: 0x010E07),
        fontKind: .pixel, displayAdvanceFactor: 0.70,
        uppercase: true, tracking: 2, cornerRadius: 4,
        usesGlow: true, glowRadius: 5, prefersDark: true)

    static let vaporwave = Theme(
        id: "vaporwave", name: "Vaporwave",
        blurb: "Neon magenta & cyan pixels.",
        chrome: .pixel,
        backgroundColors: [Color(hex: 0x1A0B2E), Color(hex: 0x0B0518)],
        panelFill: Color(hex: 0x180A2A), panelStroke: Color(hex: 0xFF71CE).opacity(0.24),
        accent: Color(hex: 0xFF71CE), accentSecondary: Color(hex: 0x05D9E8),
        alarm: Color(hex: 0xFF5148),
        textPrimary: Color(hex: 0xFF9CE0), textSecondary: Color(hex: 0x05D9E8).opacity(0.7),
        textDim: Color(hex: 0xFF71CE).opacity(0.30),
        displayBackground: Color(hex: 0x120720),
        fontKind: .pixel, displayAdvanceFactor: 0.70,
        uppercase: true, tracking: 2, cornerRadius: 4,
        usesGlow: true, glowRadius: 6, prefersDark: true)

    static let modern = Theme(
        id: "modern", name: "Default",
        blurb: "Modern Apple glass, light.",
        chrome: .glass,
        backgroundColors: [Color(hex: 0xF2F2F7), Color(hex: 0xE4E4EC)],
        panelFill: Color.white.opacity(0.6), panelStroke: Color.white.opacity(0.7),
        accent: Color(hex: 0x0A84FF), accentSecondary: Color(hex: 0x30D158),
        alarm: Color(hex: 0xFF3B30),
        textPrimary: Color(hex: 0x1C1C1E), textSecondary: Color(hex: 0x3C3C43).opacity(0.7),
        textDim: Color(hex: 0x3C3C43).opacity(0.35),
        displayBackground: Color(hex: 0x0E1013),
        fontKind: .standard, displayAdvanceFactor: 0.60,
        uppercase: false, tracking: 0, cornerRadius: 16,
        usesGlow: false, glowRadius: 0, prefersDark: false)

    static let graphite = Theme(
        id: "graphite", name: "Graphite",
        blurb: "Modern glass, dark.",
        chrome: .glass,
        backgroundColors: [Color(hex: 0x1C1C1E), Color(hex: 0x0E0E10)],
        panelFill: Color.white.opacity(0.06), panelStroke: Color.white.opacity(0.12),
        accent: Color(hex: 0x0A84FF), accentSecondary: Color(hex: 0x30D158),
        alarm: Color(hex: 0xFF453A),
        textPrimary: Color.white, textSecondary: Color.white.opacity(0.65),
        textDim: Color.white.opacity(0.32),
        displayBackground: Color(hex: 0x0A0A0C),
        fontKind: .standard, displayAdvanceFactor: 0.60,
        uppercase: false, tracking: 0, cornerRadius: 16,
        usesGlow: false, glowRadius: 0, prefersDark: true)

    static let all: [Theme] = [.nineties, .modern, .graphite, .amber, .phosphor, .vaporwave]
}
