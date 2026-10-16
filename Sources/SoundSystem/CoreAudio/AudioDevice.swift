import CoreAudio
import Foundation

/// A snapshot of a Core Audio output device.
struct AudioDevice: Identifiable, Hashable, Sendable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let transport: Transport
    let hasVolumeControl: Bool

    enum Transport: Sendable {
        case builtIn, usb, bluetooth, hdmi, displayPort, airplay, virtual, aggregate, thunderbolt, other

        init(rawValue: UInt32) {
            switch rawValue {
            case kAudioDeviceTransportTypeBuiltIn: self = .builtIn
            case kAudioDeviceTransportTypeUSB: self = .usb
            case kAudioDeviceTransportTypeBluetooth,
                 kAudioDeviceTransportTypeBluetoothLE: self = .bluetooth
            case kAudioDeviceTransportTypeHDMI: self = .hdmi
            case kAudioDeviceTransportTypeDisplayPort: self = .displayPort
            case kAudioDeviceTransportTypeAirPlay: self = .airplay
            case kAudioDeviceTransportTypeVirtual: self = .virtual
            case kAudioDeviceTransportTypeAggregate: self = .aggregate
            case kAudioDeviceTransportTypeThunderbolt: self = .thunderbolt
            default: self = .other
            }
        }

        /// SF Symbol used to badge the device in the picker.
        var symbolName: String {
            switch self {
            case .builtIn: return "laptopcomputer"
            case .usb: return "cable.connector"
            case .bluetooth: return "wave.3.right"
            case .hdmi, .displayPort: return "tv"
            case .airplay: return "airplayaudio"
            case .virtual, .aggregate: return "square.stack.3d.up"
            case .thunderbolt: return "bolt"
            case .other: return "hifispeaker"
            }
        }

        var label: String {
            switch self {
            case .builtIn: return "Built-in"
            case .usb: return "USB"
            case .bluetooth: return "Bluetooth"
            case .hdmi: return "HDMI"
            case .displayPort: return "DisplayPort"
            case .airplay: return "AirPlay"
            case .virtual: return "Virtual"
            case .aggregate: return "Aggregate"
            case .thunderbolt: return "Thunderbolt"
            case .other: return "Audio"
            }
        }
    }
}

extension AudioDevice {
    /// Build an `AudioDevice` for `deviceID` if it exposes an output stream;
    /// returns `nil` for input-only devices.
    static func makeOutput(_ deviceID: AudioObjectID) -> AudioDevice? {
        guard outputChannelCount(deviceID) > 0 else { return nil }

        let uid = (try? CoreAudioSystem.string(
            deviceID,
            CoreAudioSystem.address(kAudioDevicePropertyDeviceUID))) ?? "unknown-\(deviceID)"
        let name = (try? CoreAudioSystem.string(
            deviceID,
            CoreAudioSystem.address(kAudioObjectPropertyName))) ?? "Unknown Device"
        let transportRaw = CoreAudioSystem.readUInt32(
            deviceID, CoreAudioSystem.address(kAudioDevicePropertyTransportType)) ?? 0

        return AudioDevice(
            id: deviceID,
            uid: uid,
            name: name,
            transport: Transport(rawValue: transportRaw),
            hasVolumeControl: hasOutputVolumeControl(deviceID)
        )
    }

    /// Total output channels across the device's output streams.
    private static func outputChannelCount(_ deviceID: AudioObjectID) -> Int {
        let addr = CoreAudioSystem.address(
            kAudioDevicePropertyStreamConfiguration,
            scope: kAudioObjectPropertyScopeOutput)
        guard let byteSize = try? CoreAudioSystem.dataSize(deviceID, addr), byteSize > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        var a = addr
        var size = byteSize
        guard AudioObjectGetPropertyData(deviceID, &a, 0, nil, &size, raw) == noErr else { return 0 }
        let listPtr = raw.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(listPtr)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    /// True if either a main or per-channel output volume scalar is settable.
    private static func hasOutputVolumeControl(_ deviceID: AudioObjectID) -> Bool {
        let scope = kAudioObjectPropertyScopeOutput
        let main = CoreAudioSystem.address(
            kAudioDevicePropertyVolumeScalar, scope: scope,
            element: kAudioObjectPropertyElementMain)
        if CoreAudioSystem.hasProperty(deviceID, main),
           CoreAudioSystem.isSettable(deviceID, main) {
            return true
        }
        for channel: AudioObjectPropertyElement in [1, 2] {
            let addr = CoreAudioSystem.address(
                kAudioDevicePropertyVolumeScalar, scope: scope, element: channel)
            if CoreAudioSystem.hasProperty(deviceID, addr),
               CoreAudioSystem.isSettable(deviceID, addr) {
                return true
            }
        }
        return false
    }
}
