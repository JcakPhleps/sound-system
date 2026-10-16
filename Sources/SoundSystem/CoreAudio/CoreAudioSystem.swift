import CoreAudio
import Foundation

/// An error surfaced from a Core Audio HAL call.
struct CoreAudioError: Error, CustomStringConvertible {
    let status: OSStatus
    let context: String
    var description: String { "CoreAudio \(context) failed: OSStatus \(status)" }
}

/// A retained property-listener registration. Holding the *exact* block
/// instance is required — `AudioObjectRemovePropertyListenerBlock` only
/// unregisters when handed back the identical block it was given.
final class ListenerToken: @unchecked Sendable {
    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress
    let queue: DispatchQueue
    let block: AudioObjectPropertyListenerBlock

    init(objectID: AudioObjectID,
         address: AudioObjectPropertyAddress,
         queue: DispatchQueue,
         block: @escaping AudioObjectPropertyListenerBlock) {
        self.objectID = objectID
        self.address = address
        self.queue = queue
        self.block = block
    }
}

/// Thin, nonisolated wrappers over the Core Audio HAL property API. Every call
/// here is a plain C function that is safe to invoke from any thread/actor.
enum CoreAudioSystem {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func hasProperty(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Bool {
        var a = addr
        return AudioObjectHasProperty(objectID, &a)
    }

    static func isSettable(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Bool {
        var a = addr
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(objectID, &a, &settable) == noErr else { return false }
        return settable.boolValue
    }

    // Concrete scalar readers. These are intentionally non-generic: on the
    // Xcode-16 / Swift-6 toolchain, reading these HAL properties through a
    // generic `value<T>` mis-specializes under `try?` and returns nil / wrong
    // sizes. Concrete `inout` reads are reliable.

    static func readAudioObjectID(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> AudioObjectID? {
        var a = addr
        var v: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr ? v : nil
    }

    static func readUInt32(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> UInt32? {
        var a = addr
        var v: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr ? v : nil
    }

    static func readFloat32(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Float32? {
        var a = addr
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr ? v : nil
    }

    static func readDouble(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Double? {
        var a = addr
        var v: Double = 0
        var size = UInt32(MemoryLayout<Double>.size)
        return AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr ? v : nil
    }

    /// Read a variable-length array property (device lists, sample rates, …).
    static func array<T>(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) throws -> [T] {
        var a = addr
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &a, 0, nil, &dataSize)
        guard status == noErr else { throw CoreAudioError(status: status, context: "get array size") }
        let count = Int(dataSize) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        let buffer = UnsafeMutableBufferPointer<T>.allocate(capacity: count)
        defer { buffer.deallocate() }
        status = AudioObjectGetPropertyData(objectID, &a, 0, nil, &dataSize, buffer.baseAddress!)
        guard status == noErr else { throw CoreAudioError(status: status, context: "get array") }
        return Array(buffer)
    }

    /// Read a `CFString` property (device names, UIDs). These come back +1
    /// retained, so consume the reference with `takeRetainedValue`.
    static func string(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) throws -> String {
        var a = addr
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &name)
        guard status == noErr, let name else {
            throw CoreAudioError(status: status, context: "get string")
        }
        return name.takeRetainedValue() as String
    }

    /// Read the raw byte size of a property's data (used for stream configs).
    static func dataSize(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress) throws -> UInt32 {
        var a = addr
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(objectID, &a, 0, nil, &size)
        guard status == noErr else { throw CoreAudioError(status: status, context: "get data size") }
        return size
    }

    /// Write a single fixed-size value.
    static func setValue<T>(_ objectID: AudioObjectID, _ addr: AudioObjectPropertyAddress, _ value: T) throws {
        var a = addr
        var v = value
        let size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafePointer(to: &v) { ptr in
            AudioObjectSetPropertyData(objectID, &a, 0, nil, size, ptr)
        }
        guard status == noErr else { throw CoreAudioError(status: status, context: "set value") }
    }

    /// Register a property listener. The handler runs on `queue`; it is handed
    /// no payload because callers simply re-read the property they care about.
    static func addListener(
        _ objectID: AudioObjectID,
        _ addr: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        handler: @escaping @Sendable () -> Void
    ) -> ListenerToken? {
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        var a = addr
        let status = AudioObjectAddPropertyListenerBlock(objectID, &a, queue, block)
        guard status == noErr else { return nil }
        return ListenerToken(objectID: objectID, address: addr, queue: queue, block: block)
    }

    static func removeListener(_ token: ListenerToken) {
        var a = token.address
        AudioObjectRemovePropertyListenerBlock(token.objectID, &a, token.queue, token.block)
    }
}
