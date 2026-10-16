import AppKit

/// Owns app lifecycle and the long-lived controllers so their Core Audio
/// listeners can be torn down cleanly on quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let deviceManager = AudioDeviceManager()
    let volumeController = VolumeController()
    let transportController = TransportController()
    let eqController = EQController()
    let permissions = PermissionsManager()
    let themeManager = ThemeManager()
    let spatialController = SpatialController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--eq-selftest") {
            runEQSelfTest()
            return
        }
        NSApp.setActivationPolicy(.regular)
        deviceManager.start()
        // Volume follows whichever device is currently the default output.
        volumeController.bind(to: deviceManager.currentDefaultDeviceID)
        // EQ engine routes to whatever the current default output is.
        eqController.physicalDeviceProvider = { [weak deviceManager] in
            deviceManager?.currentDefaultDeviceID ?? 0
        }
        deviceManager.onDefaultDeviceChanged = { [weak volumeController, weak eqController] id in
            volumeController?.bind(to: id)
            eqController?.handleDefaultDeviceChanged()
        }
        transportController.start()
        spatialController.configure(deviceManager: deviceManager)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Headless check of the EQ audio plumbing: create the tap + aggregate,
    /// report whether the IOProc started, then tear down. Run with
    /// `Conductor Pro --eq-selftest`.
    private func runEQSelfTest() {
        NSApp.setActivationPolicy(.prohibited)
        runEQDSPCheck()
        deviceManager.start()
        let dev = deviceManager.currentDefaultDeviceID
        let name = deviceManager.currentDefaultDevice?.name ?? "unknown"
        print("SELFTEST default output: \(name) (id \(dev)); devices=\(deviceManager.devices.count)")
        let engine = ProcessTapEngine()
        let ok = engine.start(physicalDeviceID: dev, gains: Array(repeating: 0, count: 10))
        print("SELFTEST engine.start -> \(ok); running=\(engine.isRunning); error=\(engine.lastError ?? "none")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("SELFTEST after 1s: running=\(engine.isRunning)")
            engine.stop()
            print("SELFTEST stopped cleanly")
            fflush(stdout)
            NSApp.terminate(nil)
        }
    }

    /// Offline proof that the biquad EQ actually equalizes: a 1 kHz tone through
    /// band 5 should get louder when boosted and quieter when cut.
    private func runEQDSPCheck() {
        let sr = 48_000.0, count = 8_192, freq = 1_000.0
        var input = [Float](repeating: 0, count: count)
        for i in 0..<count { input[i] = Float(sin(2 * Double.pi * freq * Double(i) / sr)) }

        func settledRMS(gainDB: Double) -> Float {
            let eq = BiquadEQ(sampleRate: sr, channels: 1)
            var gains = Array(repeating: 0.0, count: 10); gains[5] = gainDB
            eq.updateGains(gains)
            var buf = input
            buf.withUnsafeMutableBufferPointer { eq.process(channel: 0, samples: $0.baseAddress!, count: count) }
            var acc: Float = 0
            for i in (count / 2)..<count { acc += buf[i] * buf[i] }
            return sqrtf(acc / Float(count / 2))
        }

        let flat = settledRMS(gainDB: 0), boost = settledRMS(gainDB: 12), cut = settledRMS(gainDB: -12)
        print(String(format: "SELFTEST DSP @1kHz  flat=%.3f  boost=%.3f (×%.2f)  cut=%.3f (×%.2f)",
                     flat, boost, boost / flat, cut, cut / flat))
        let works = boost > flat * 1.5 && cut < flat * 0.75
        print("SELFTEST DSP equalization \(works ? "WORKS ✓" : "FAILED ✗")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        eqController.shutdown()
        transportController.stop()
        volumeController.unbind()
        deviceManager.stop()
    }
}
