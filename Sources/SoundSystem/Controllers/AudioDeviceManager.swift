import CoreAudio
import Observation
import SwiftUI

/// Enumerates output devices, tracks/sets the system default output, and keeps
/// the list live as devices are plugged/unplugged or the default changes
/// elsewhere (e.g. from System Settings or the menu bar).
@MainActor
@Observable
final class AudioDeviceManager {
    private(set) var devices: [AudioDevice] = []
    private(set) var currentDefaultDeviceID: AudioObjectID = 0

    /// Notified (on the main actor) whenever the system default output changes,
    /// so dependents like `VolumeController` can rebind.
    var onDefaultDeviceChanged: ((AudioObjectID) -> Void)?

    var currentDefaultDevice: AudioDevice? {
        devices.first { $0.id == currentDefaultDeviceID }
    }

    private let listenerQueue = DispatchQueue(label: "com.jackphelps.soundsystem.device-listeners")
    private var deviceListToken: ListenerToken?
    private var defaultDeviceToken: ListenerToken?

    private static let devicesAddress = CoreAudioSystem.address(kAudioHardwarePropertyDevices)
    private static let defaultOutputAddress = CoreAudioSystem.address(kAudioHardwarePropertyDefaultOutputDevice)

    func start() {
        refreshDevices()
        refreshDefaultDevice()

        deviceListToken = CoreAudioSystem.addListener(
            CoreAudioSystem.systemObject, Self.devicesAddress, queue: listenerQueue
        ) { [weak self] in
            Task { @MainActor in self?.refreshDevices() }
        }

        defaultDeviceToken = CoreAudioSystem.addListener(
            CoreAudioSystem.systemObject, Self.defaultOutputAddress, queue: listenerQueue
        ) { [weak self] in
            Task { @MainActor in self?.refreshDefaultDevice() }
        }
    }

    func stop() {
        if let deviceListToken { CoreAudioSystem.removeListener(deviceListToken) }
        if let defaultDeviceToken { CoreAudioSystem.removeListener(defaultDeviceToken) }
        deviceListToken = nil
        defaultDeviceToken = nil
    }

    /// Make `device` the system default output. All app audio follows this.
    func selectDevice(_ device: AudioDevice) {
        do {
            try CoreAudioSystem.setValue(
                CoreAudioSystem.systemObject,
                Self.defaultOutputAddress,
                device.id)
            refreshDefaultDevice()
        } catch {
            NSLog("Sound System: failed to set default output device: \(error)")
        }
    }

    private func refreshDevices() {
        let ids: [AudioObjectID] = (try? CoreAudioSystem.array(
            CoreAudioSystem.systemObject, Self.devicesAddress)) ?? []
        let outputs = ids.compactMap(AudioDevice.makeOutput)
        // Sort by transport (built-in first) then name for a stable list.
        devices = outputs.sorted { lhs, rhs in
            if lhs.transport == rhs.transport { return lhs.name < rhs.name }
            return lhs.transport.sortRank < rhs.transport.sortRank
        }
    }

    private func refreshDefaultDevice() {
        let id = CoreAudioSystem.readAudioObjectID(
            CoreAudioSystem.systemObject, Self.defaultOutputAddress) ?? 0
        guard id != currentDefaultDeviceID else { return }
        currentDefaultDeviceID = id
        onDefaultDeviceChanged?(id)
    }
}

private extension AudioDevice.Transport {
    var sortRank: Int {
        switch self {
        case .builtIn: return 0
        case .usb, .thunderbolt: return 1
        case .bluetooth, .airplay: return 2
        case .hdmi, .displayPort: return 3
        default: return 4
        }
    }
}
