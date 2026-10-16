import AVFoundation
import Observation

/// Drives Conductor Lite's visuals from the microphone: since iOS forbids
/// reading other apps' audio, the meter reacts to whatever's audible in the
/// room. Also tracks the current input/output route.
@MainActor
@Observable
final class LiteAudioEngine {
    enum Permission { case unknown, granted, denied }

    private(set) var isRunning = false
    private(set) var levels: [Float] = Array(repeating: 0, count: 10)
    private(set) var outputName = "—"
    private(set) var inputName = "—"
    private(set) var permission: Permission = .unknown

    private let engine = AVAudioEngine()
    private var analyzer: SpectrumAnalyzer?
    private var timer: Timer?

    func start() {
        updateRoute()
        observeRoute()
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                self.permission = granted ? .granted : .denied
                if granted { self.beginListening() }
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    /// Available inputs the user can choose between (built-in, headset, …).
    func availableInputs() -> [AVAudioSessionPortDescription] {
        AVAudioSession.sharedInstance().availableInputs ?? []
    }

    func selectInput(_ port: AVAudioSessionPortDescription) {
        try? AVAudioSession.sharedInstance().setPreferredInput(port)
        updateRoute()
    }

    // MARK: - Private

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers so we listen without interrupting the music that's playing.
        try? session.setCategory(
            .playAndRecord, mode: .measurement,
            options: [.mixWithOthers, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker])
        try? session.setActive(true)
    }

    private func beginListening() {
        configureSession()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The simulator has no real input: format is 0-channel and installing a
        // tap on it would crash. Bail out (stays IDLE) — works on a real phone.
        guard format.channelCount > 0, format.sampleRate > 0 else { return }
        let spectrum = SpectrumAnalyzer(sampleRate: format.sampleRate)
        analyzer = spectrum

        input.removeTap(onBus: 0)
        Self.installTap(on: input, format: format, analyzer: spectrum)
        engine.prepare()
        do { try engine.start(); isRunning = true } catch { isRunning = false; return }
        updateRoute()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let analyzer = self.analyzer else { return }
                self.levels = analyzer.snapshot()
            }
        }
        self.timer = timer
    }

    /// Installs the mic tap from a nonisolated context so the render-thread
    /// callback isn't treated as main-actor isolated (which traps off-main).
    nonisolated private static func installTap(
        on node: AVAudioInputNode, format: AVAudioFormat, analyzer: SpectrumAnalyzer
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            analyzer.process(channel, Int(buffer.frameLength))
        }
    }

    private func updateRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        outputName = route.outputs.first?.portName ?? "—"
        inputName = route.inputs.first?.portName ?? "—"
    }

    private func observeRoute() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRoute() }
        }
    }
}
