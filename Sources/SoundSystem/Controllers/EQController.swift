import Observation
import CoreAudio
import SwiftUI

/// A named set of band gains (dB), –12…+12.
struct EQPreset: Identifiable, Hashable, Sendable {
    let name: String
    let gains: [Double]
    var id: String { name }

    static let flat = EQPreset(name: "Flat", gains: Array(repeating: 0, count: 10))
    static let bass = EQPreset(name: "Bass", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0])
    static let vocal = EQPreset(name: "Vocal", gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1])
    static let treble = EQPreset(name: "Treble", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6])
    static let loudness = EQPreset(name: "Loudness", gains: [6, 4, 2, 0, -1, -1, 0, 2, 4, 6])
    static let dj = EQPreset(name: "DJ", gains: [5, 4, 1, 0, -1, 0, 1, 2, 3, 4])

    static let all: [EQPreset] = [.flat, .bass, .vocal, .treble, .loudness, .dj]
}

/// Drives the system-wide EQ. Owns the real-time `ProcessTapEngine`; enabling
/// starts routing all audio through the equalizer and out to the current output
/// device. The view layer is unchanged from the Phase-1 facade.
@MainActor
@Observable
final class EQController {
    private(set) var isEnabled = false
    private(set) var gains: [Double] = Array(repeating: 0, count: 10)
    private(set) var selectedPresetName: String = EQPreset.flat.name
    private(set) var engineError: String?

    let isEngineReady = true

    /// Supplies the current physical output device to route processed audio to.
    var physicalDeviceProvider: (() -> AudioObjectID)?

    @ObservationIgnored private let engine = ProcessTapEngine()

    func setEnabled(_ enabled: Bool) {
        if enabled {
            startEngine()
        } else {
            engine.stop()
            isEnabled = false
            engineError = nil
        }
    }

    func setGain(_ gain: Double, at index: Int) {
        guard gains.indices.contains(index) else { return }
        gains[index] = min(max(gain, -12), 12)
        selectedPresetName = matchingPresetName() ?? "Custom"
        engine.updateGains(gains)
    }

    func apply(_ preset: EQPreset) {
        gains = preset.gains
        selectedPresetName = preset.name
        engine.updateGains(gains)
    }

    /// Restart the engine on the new output device when it changes mid-playback.
    func handleDefaultDeviceChanged() {
        guard isEnabled else { return }
        engine.stop()
        startEngine()
    }

    func shutdown() {
        engine.stop()
    }

    /// Live per-band spectrum (10 values, 0…1) when the engine is running.
    func spectrumLevels() -> [Float]? { engine.spectrumSnapshot() }

    private func startEngine() {
        let device = physicalDeviceProvider?() ?? 0
        if engine.start(physicalDeviceID: device, gains: gains) {
            isEnabled = true
            engineError = nil
        } else {
            isEnabled = false
            engineError = engine.lastError ?? "Could not start EQ engine"
        }
    }

    private func matchingPresetName() -> String? {
        EQPreset.all.first { $0.gains == gains }?.name
    }
}
