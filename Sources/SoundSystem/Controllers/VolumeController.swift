import CoreAudio
import Observation
import SwiftUI

/// Reads and writes output volume/mute for the currently bound device, and
/// keeps its published state in sync when volume is changed elsewhere (hardware
/// keys, menu bar, System Settings).
@MainActor
@Observable
final class VolumeController {
    private(set) var volume: Double = 0        // 0...1
    private(set) var isMuted: Bool = false
    /// False when the bound device exposes no settable volume (slider disabled).
    private(set) var isAvailable: Bool = false

    private var deviceID: AudioObjectID = 0
    /// Which elements carry the volume scalar: `[main]` or per-channel `[1, 2]`.
    private var volumeElements: [AudioObjectPropertyElement] = []
    private var muteSupported = false

    private let listenerQueue = DispatchQueue(label: "com.jackphelps.soundsystem.volume-listeners")
    private var tokens: [ListenerToken] = []

    private static let scope = kAudioObjectPropertyScopeOutput

    func bind(to deviceID: AudioObjectID) {
        unbind()
        guard deviceID != 0 else { return }
        self.deviceID = deviceID
        resolveCapabilities()
        readVolume()
        readMute()
        installListeners()
    }

    func unbind() {
        for token in tokens { CoreAudioSystem.removeListener(token) }
        tokens.removeAll()
        deviceID = 0
        volumeElements = []
        muteSupported = false
        isAvailable = false
    }

    func setVolume(_ newValue: Double) {
        let clamped = min(max(newValue, 0), 1)
        volume = clamped
        guard isAvailable else { return }
        let value = Float32(clamped)
        for element in volumeElements {
            let addr = CoreAudioSystem.address(
                kAudioDevicePropertyVolumeScalar, scope: Self.scope, element: element)
            try? CoreAudioSystem.setValue(deviceID, addr, value)
        }
    }

    func toggleMute() { setMuted(!isMuted) }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        guard muteSupported else { return }
        let addr = CoreAudioSystem.address(
            kAudioDevicePropertyMute, scope: Self.scope, element: kAudioObjectPropertyElementMain)
        try? CoreAudioSystem.setValue(deviceID, addr, UInt32(muted ? 1 : 0))
    }

    // MARK: - Capability resolution

    private func resolveCapabilities() {
        let main = CoreAudioSystem.address(
            kAudioDevicePropertyVolumeScalar, scope: Self.scope, element: kAudioObjectPropertyElementMain)
        if CoreAudioSystem.hasProperty(deviceID, main), CoreAudioSystem.isSettable(deviceID, main) {
            volumeElements = [kAudioObjectPropertyElementMain]
        } else {
            volumeElements = [1, 2].filter { channel in
                let addr = CoreAudioSystem.address(
                    kAudioDevicePropertyVolumeScalar, scope: Self.scope, element: channel)
                return CoreAudioSystem.hasProperty(deviceID, addr) && CoreAudioSystem.isSettable(deviceID, addr)
            }
        }
        isAvailable = !volumeElements.isEmpty

        let muteAddr = CoreAudioSystem.address(
            kAudioDevicePropertyMute, scope: Self.scope, element: kAudioObjectPropertyElementMain)
        muteSupported = CoreAudioSystem.hasProperty(deviceID, muteAddr)
    }

    // MARK: - Reads

    private func readVolume() {
        guard !volumeElements.isEmpty else { return }
        var total: Float32 = 0
        var counted = 0
        for element in volumeElements {
            let addr = CoreAudioSystem.address(
                kAudioDevicePropertyVolumeScalar, scope: Self.scope, element: element)
            if let v = CoreAudioSystem.readFloat32(deviceID, addr) {
                total += v
                counted += 1
            }
        }
        if counted > 0 { volume = Double(total / Float32(counted)) }
    }

    private func readMute() {
        guard muteSupported else { return }
        let addr = CoreAudioSystem.address(
            kAudioDevicePropertyMute, scope: Self.scope, element: kAudioObjectPropertyElementMain)
        if let raw = CoreAudioSystem.readUInt32(deviceID, addr) {
            isMuted = raw != 0
        }
    }

    // MARK: - Listeners

    private func installListeners() {
        for element in volumeElements {
            let addr = CoreAudioSystem.address(
                kAudioDevicePropertyVolumeScalar, scope: Self.scope, element: element)
            if let token = CoreAudioSystem.addListener(deviceID, addr, queue: listenerQueue, handler: { [weak self] in
                Task { @MainActor in self?.readVolume() }
            }) {
                tokens.append(token)
            }
        }
        if muteSupported {
            let addr = CoreAudioSystem.address(
                kAudioDevicePropertyMute, scope: Self.scope, element: kAudioObjectPropertyElementMain)
            if let token = CoreAudioSystem.addListener(deviceID, addr, queue: listenerQueue, handler: { [weak self] in
                Task { @MainActor in self?.readMute() }
            }) {
                tokens.append(token)
            }
        }
    }
}
