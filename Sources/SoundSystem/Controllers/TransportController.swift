import Observation
import SwiftUI

/// Tracks now-playing state and issues transport commands, routing them to the
/// selected source (Music/Spotify via Apple Events, or the system media keys).
@MainActor
@Observable
final class TransportController {
    private(set) var nowPlaying: NowPlaying?
    var currentSource: PlaybackSource {
        didSet {
            UserDefaults.standard.set(currentSource.rawValue, forKey: Self.sourceKey)
            refresh()
        }
    }

    var isPlaying: Bool { nowPlaying?.isPlaying ?? false }

    /// Backs the USB source: local audio-file playback.
    let localPlayer = LocalPlayer()

    private var timer: Timer?
    private static let sourceKey = "playbackSource"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.sourceKey),
           let saved = PlaybackSource(rawValue: raw) {
            currentSource = saved
        } else {
            currentSource = .system
        }
    }

    func start() {
        localPlayer.onChange = { [weak self] in self?.refresh() }
        autoDetectSource()
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setSource(_ source: PlaybackSource) {
        guard source != currentSource else { return }
        currentSource = source
    }

    func perform(_ command: TransportCommand) {
        switch currentSource {
        case .system:
            MediaKeyPoster.post(command)
        case .appleMusic, .spotify:
            AppleScriptBridge.send(command, to: currentSource)
        case .usb:
            switch command {
            case .playPause: localPlayer.togglePlayPause()
            case .next: localPlayer.next()
            case .previous: localPlayer.previous()
            }
        }
        // Reflect the new state quickly rather than waiting for the next tick.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - Private

    private func refresh() {
        switch currentSource {
        case .system:
            nowPlaying = AppleScriptBridge.nowPlaying(.spotify) ?? AppleScriptBridge.nowPlaying(.appleMusic)
        case .appleMusic, .spotify:
            nowPlaying = AppleScriptBridge.nowPlaying(currentSource)
        case .usb:
            nowPlaying = localPlayer.nowPlaying
        }
    }

    /// On first launch, prefer whichever known player is currently running.
    private func autoDetectSource() {
        guard currentSource == .system else { return }
        if AppleScriptBridge.isRunning(.spotify) {
            currentSource = .spotify
        } else if AppleScriptBridge.isRunning(.appleMusic) {
            currentSource = .appleMusic
        }
    }
}
