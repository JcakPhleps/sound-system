import AVFoundation
import CoreAudio
import Foundation

/// Real-time system-wide EQ via a Core Audio process tap.
///
/// Flow: a global stereo tap captures all system audio and mutes the normal
/// output (`.mutedWhenTapped`); a private aggregate device pairs the physical
/// output (clock master) with that tap; a single IOProc reads the tapped audio,
/// runs it through `BiquadEQ`, and writes it to the speakers — all in one clock
/// domain. Our own process is excluded from the tap to avoid a feedback loop.
///
/// Process taps are torn down automatically when this process exits, so a crash
/// cannot leave the Mac muted — no restore-on-launch bookkeeping needed.
final class ProcessTapEngine: @unchecked Sendable {
    private(set) var isRunning = false
    private(set) var lastError: String?

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?

    private var eq: BiquadEQ?
    private var analyzer: SpectrumAnalyzer?
    private let scratchCapacity = 16_384
    private let scratch: UnsafeMutablePointer<Float>
    private let mono: UnsafeMutablePointer<Float>

    private var currentGains: [Double] = Array(repeating: 0, count: 10)

    init() {
        scratch = .allocate(capacity: scratchCapacity)
        scratch.initialize(repeating: 0, count: scratchCapacity)
        mono = .allocate(capacity: scratchCapacity)
        mono.initialize(repeating: 0, count: scratchCapacity)
    }

    deinit {
        stop()
        scratch.deallocate()
        mono.deallocate()
    }

    /// Current per-band spectrum levels (10 values, 0…1), or nil if not running.
    func spectrumSnapshot() -> [Float]? { isRunning ? analyzer?.snapshot() : nil }

    /// Start processing, routing all audio through the EQ to `physicalDeviceID`.
    @discardableResult
    func start(physicalDeviceID: AudioObjectID, gains: [Double]) -> Bool {
        guard !isRunning else { return true }
        currentGains = gains
        lastError = nil

        guard physicalDeviceID != 0,
              let physUID = try? CoreAudioSystem.string(
                physicalDeviceID, CoreAudioSystem.address(kAudioDevicePropertyDeviceUID)) else {
            return fail("No physical output device")
        }

        // 1. Global tap that mutes the original path; exclude ourselves.
        let description = CATapDescription(
            stereoGlobalTapButExcludeProcesses: currentProcessObjectID().map { [$0] } ?? [])
        description.name = "Conductor Pro EQ"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        let tapUID = description.uuid.uuidString

        var newTapID: AudioObjectID = 0
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr, newTapID != 0 else { return fail("create tap failed (\(status))") }
        tapID = newTapID

        // 2. Private aggregate: physical device (master) + the tap.
        // Unique per run so a leftover aggregate from a killed process can't
        // collide (which returns kAudioHardwareIllegalOperationError).
        let aggUID = "com.jackphelps.conductorpro.aggregate." + tapUID
        let dict: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Conductor Pro EQ",
            kAudioAggregateDeviceUIDKey: aggUID,
            kAudioAggregateDeviceMainSubDeviceKey: physUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: physUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapUID,
            ]],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        var newAggID: AudioObjectID = 0
        status = AudioHardwareCreateAggregateDevice(dict as CFDictionary, &newAggID)
        guard status == noErr, newAggID != 0 else { return fail("create aggregate failed (\(status))") }
        aggregateID = newAggID

        // 3. EQ configured for the aggregate's sample rate.
        let sr = CoreAudioSystem.readDouble(
            aggregateID, CoreAudioSystem.address(kAudioDevicePropertyNominalSampleRate)) ?? 48_000
        let equalizer = BiquadEQ(sampleRate: sr > 0 ? sr : 48_000, channels: 2)
        equalizer.updateGains(currentGains)
        eq = equalizer
        let spectrum = SpectrumAnalyzer(sampleRate: sr > 0 ? sr : 48_000)
        analyzer = spectrum

        // 4. Real-time IOProc: tap input -> EQ -> physical output.
        let eqRef = equalizer
        let scratchRef = scratch
        let monoRef = mono
        let analyzerRef = spectrum
        let cap = scratchCapacity
        var newProcID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&newProcID, aggregateID, nil) {
            _, inInputData, _, outOutputData, _ in
            Self.render(input: inInputData, output: outOutputData,
                        eq: eqRef, scratch: scratchRef, mono: monoRef, cap: cap, analyzer: analyzerRef)
        }
        guard status == noErr, let newProcID else { return fail("create IOProc failed (\(status))") }
        ioProcID = newProcID

        // 5. Go.
        status = AudioDeviceStart(aggregateID, newProcID)
        guard status == noErr else { return fail("device start failed (\(status))") }

        isRunning = true
        return true
    }

    func stop() {
        if aggregateID != 0, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != 0 { AudioHardwareDestroyAggregateDevice(aggregateID); aggregateID = 0 }
        if tapID != 0 { AudioHardwareDestroyProcessTap(tapID); tapID = 0 }
        eq = nil
        analyzer = nil
        isRunning = false
    }

    /// Push new band gains to the live filter (main thread).
    func updateGains(_ gains: [Double]) {
        currentGains = gains
        eq?.updateGains(gains)
    }

    // MARK: - Render (real-time thread)

    private static func render(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>,
        eq: BiquadEQ,
        scratch: UnsafeMutablePointer<Float>,
        mono: UnsafeMutablePointer<Float>,
        cap: Int,
        analyzer: SpectrumAnalyzer
    ) {
        let outList = UnsafeMutableAudioBufferListPointer(output)
        guard outList.count > 0 else { return }

        let firstOut = outList[0]
        let outChans = Int(firstOut.mNumberChannels)
        guard outChans > 0 else { return }
        let frames = Int(firstOut.mDataByteSize) / (outChans * MemoryLayout<Float>.size)
        guard frames > 0, frames <= cap else {
            // Unexpected buffer size: emit silence rather than garbage.
            for i in 0..<outList.count {
                if let d = outList[i].mData { memset(d, 0, Int(outList[i].mDataByteSize)) }
            }
            return
        }

        // Zero all output first so unused channels stay silent.
        for i in 0..<outList.count {
            if let d = outList[i].mData { memset(d, 0, Int(outList[i].mDataByteSize)) }
        }

        for i in 0..<frames { mono[i] = 0 }
        let inList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        for ch in 0..<2 {
            guard let (inPtr, inStride) = channel(inList, ch),
                  let (outPtr, outStride) = channel(outList, ch) else { continue }
            for i in 0..<frames { scratch[i] = inPtr[i * inStride] }
            eq.process(channel: ch, samples: scratch, count: frames)
            for i in 0..<frames {
                outPtr[i * outStride] = scratch[i]
                mono[i] += scratch[i] * 0.5      // post-EQ mono mix for the meter
            }
        }
        analyzer.process(mono, frames)
    }

    /// Returns the (base pointer, stride) for a logical channel across the
    /// buffer list, handling both interleaved and deinterleaved layouts.
    private static func channel(
        _ list: UnsafeMutableAudioBufferListPointer, _ target: Int
    ) -> (UnsafeMutablePointer<Float>, Int)? {
        var seen = 0
        for i in 0..<list.count {
            let buf = list[i]
            let nc = Int(buf.mNumberChannels)
            if target < seen + nc {
                guard let base = buf.mData?.assumingMemoryBound(to: Float.self) else { return nil }
                return (base + (target - seen), nc)
            }
            seen += nc
        }
        return nil
    }

    // MARK: - Helpers

    private func currentProcessObjectID() -> AudioObjectID? {
        var pid = getpid()
        var addr = CoreAudioSystem.address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var obj = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            CoreAudioSystem.systemObject, &addr,
            UInt32(MemoryLayout<pid_t>.size), &pid, &size, &obj)
        return status == noErr && obj != 0 ? obj : nil
    }

    @discardableResult
    private func fail(_ message: String) -> Bool {
        lastError = message
        NSLog("Sound System EQ engine: \(message)")
        stop()
        return false
    }
}
