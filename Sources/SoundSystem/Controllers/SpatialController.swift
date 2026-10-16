import Foundation
import Observation

/// A speaker placed in the virtual room. `position` is normalized (0…1) within
/// the room rectangle; (0.5, 0.5) is the listener.
struct SpeakerNode: Identifiable, Sendable {
    let id: String
    let label: String
    var position: CGPoint
    let isDemo: Bool
    let channel: String?
}

/// Maps connected output speakers (or a demo surround set) to positions in a
/// virtual room the user can arrange — like dragging displays in System Settings.
@MainActor
@Observable
final class SpatialController {
    private(set) var nodes: [SpeakerNode] = []
    var demoMode = false { didSet { rebuild() } }

    private weak var deviceManager: AudioDeviceManager?

    func configure(deviceManager: AudioDeviceManager) {
        self.deviceManager = deviceManager
        rebuild()
    }

    func rebuild() {
        nodes = demoMode ? Self.demoNodes() : realNodes()
        loadPositions()
    }

    func move(_ id: String, to pos: CGPoint) {
        guard let i = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[i].position = CGPoint(x: pos.x.clamped(0.04, 0.96), y: pos.y.clamped(0.04, 0.96))
        savePositions()
    }

    func resetLayout() {
        let defaults = demoMode ? Self.demoNodes() : realNodes()
        nodes = defaults
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Node sources

    private func realNodes() -> [SpeakerNode] {
        let devices = deviceManager?.devices ?? []
        guard !devices.isEmpty else { return [] }
        // Fan the real devices out along the front of the room by default.
        return devices.enumerated().map { index, device in
            let t = devices.count == 1 ? 0.5 : Double(index) / Double(devices.count - 1)
            return SpeakerNode(
                id: device.uid, label: device.name,
                position: CGPoint(x: 0.2 + t * 0.6, y: 0.22),
                isDemo: false, channel: nil)
        }
    }

    private static func demoNodes() -> [SpeakerNode] {
        // Standard 5.1 layout around a centered listener.
        let layout: [(String, CGFloat, CGFloat)] = [
            ("FL", 0.20, 0.22), ("C", 0.50, 0.12), ("FR", 0.80, 0.22),
            ("SL", 0.12, 0.76), ("SR", 0.88, 0.76), ("LFE", 0.36, 0.14),
        ]
        return layout.map {
            SpeakerNode(id: "demo-\($0.0)", label: $0.0,
                        position: CGPoint(x: $0.1, y: $0.2), isDemo: true, channel: $0.0)
        }
    }

    // MARK: - Persistence

    private var storageKey: String { demoMode ? "spatial.demo" : "spatial.real" }

    private func savePositions() {
        let dict = Dictionary(uniqueKeysWithValues:
            nodes.map { ($0.id, [Double($0.position.x), Double($0.position.y)]) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadPositions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data) else { return }
        for i in nodes.indices {
            if let p = dict[nodes[i].id], p.count == 2 {
                nodes[i].position = CGPoint(x: p[0], y: p[1])
            }
        }
    }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(Swift.max(self, lo), hi) }
}
