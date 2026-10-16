import SwiftUI

struct SpatialMapView: View {
    @Environment(\.theme) private var theme
    @Environment(SpatialController.self) private var spatial
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            header
            roomCanvas
            legend
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 560)
        .background(
            LinearGradient(colors: theme.backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .preferredColorScheme(theme.prefersDark ? .dark : .light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(theme.text("Spatial Map"))
                .font(theme.font(20, .bold))
                .foregroundStyle(theme.accent)
                .themedGlow(theme, radius: 6)
            Spacer()
            RetroSelectButton(title: "Demo", systemImage: "sparkles",
                              isOn: spatial.demoMode) { spatial.demoMode.toggle() }
                .frame(width: 110)
            Button(theme.text("Reset")) { spatial.resetLayout() }
                .buttonStyle(RetroButtonStyle(minWidth: 66))
            Button(theme.text("Done")) { dismiss() }
                .buttonStyle(RetroButtonStyle(tint: theme.accent, minWidth: 66))
        }
    }

    private var roomCanvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                roomBackground(size)
                rangeRings(size)
                listener(size)
                if spatial.nodes.isEmpty {
                    Text(theme.text(spatial.demoMode ? "" : "No Signal — connect speakers or turn on Demo"))
                        .font(theme.font(12))
                        .foregroundStyle(theme.textDim)
                }
                ForEach(spatial.nodes) { node in
                    SpeakerPuck(node: node, roomSize: size) { spatial.move(node.id, to: $0) }
                }
            }
            .coordinateSpace(name: "room")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func roomBackground(_ size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius)
            .fill(theme.displayBackground.opacity(theme.chrome == .glass ? 0.5 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.accent.opacity(0.25), lineWidth: 1))
            .overlay(GridOverlay(spacing: 34).stroke(theme.accent.opacity(0.06), lineWidth: 1))
    }

    private func rangeRings(_ size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = min(size.width, size.height) / 2
        return ZStack {
            ForEach(1..<4) { i in
                Circle()
                    .stroke(theme.accent.opacity(0.12), lineWidth: 1)
                    .frame(width: maxR * CGFloat(i) / 3 * 2, height: maxR * CGFloat(i) / 3 * 2)
                    .position(center)
            }
        }
    }

    private func listener(_ size: CGSize) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "figure.seated.side")
                .font(.system(size: 22))
            Text(theme.text("You"))
                .font(theme.font(9, .semibold))
        }
        .foregroundStyle(theme.textSecondary)
        .position(x: size.width / 2, y: size.height / 2)
    }

    private var legend: some View {
        Text(theme.text("Drag each speaker to where it sits in your room. Demo mode fakes a 5.1 set."))
            .font(theme.font(10))
            .foregroundStyle(theme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpeakerPuck: View {
    @Environment(\.theme) private var theme
    let node: SpeakerNode
    let roomSize: CGSize
    let onMove: (CGPoint) -> Void

    var body: some View {
        let center = CGPoint(x: node.position.x * roomSize.width,
                             y: node.position.y * roomSize.height)
        ZStack {
            if node.isDemo {
                TimelineView(.animation) { context in
                    let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
                    Circle()
                        .stroke(theme.accent.opacity(0.35 * (1 - phase)), lineWidth: 2)
                        .frame(width: 44 + 26 * phase, height: 44 + 26 * phase)
                }
            }
            Circle()
                .fill(theme.accent.opacity(0.18))
                .overlay(Circle().stroke(theme.accent, lineWidth: 2))
                .frame(width: 46, height: 46)
                .themedGlow(theme, radius: 6)
            VStack(spacing: 1) {
                ThemedIcon(sf: "hifispeaker.fill", glyph: "[]", size: 15)
                Text(theme.text(node.label))
                    .font(theme.font(8, .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(theme.accent)
        }
        .position(center)
        .gesture(
            DragGesture(coordinateSpace: .named("room"))
                .onChanged { value in
                    onMove(CGPoint(x: value.location.x / roomSize.width,
                                   y: value.location.y / roomSize.height))
                }
        )
    }
}

/// A light grid drawn inside the room for spatial reference.
private struct GridOverlay: Shape {
    let spacing: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)); x += spacing }
        var y = rect.minY
        while y <= rect.maxY { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)); y += spacing }
        return path
    }
}
