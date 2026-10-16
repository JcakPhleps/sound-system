import AVFoundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Plays local audio files (any AVFoundation-supported format) as a playlist.
/// Output goes to the system default device, so the system-wide EQ still
/// applies. Backs the "USB" source.
@MainActor
@Observable
final class LocalPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playlist: [URL] = []
    private(set) var currentIndex = 0
    private(set) var isPlaying = false
    private(set) var nowPlaying: NowPlaying?

    /// Called on any state change so the transport display can refresh.
    var onChange: (() -> Void)?

    private var player: AVAudioPlayer?

    var currentURL: URL? { playlist.indices.contains(currentIndex) ? playlist[currentIndex] : nil }

    func setPlaylist(_ urls: [URL], startAt index: Int = 0) {
        playlist = urls
        currentIndex = min(max(index, 0), max(0, urls.count - 1))
        loadCurrent()
        play()
    }

    func add(_ urls: [URL]) {
        let wasEmpty = playlist.isEmpty
        playlist.append(contentsOf: urls)
        if wasEmpty { currentIndex = 0; loadCurrent(); play() } else { onChange?() }
    }

    func playIndex(_ index: Int) {
        guard playlist.indices.contains(index) else { return }
        currentIndex = index
        loadCurrent()
        play()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func play() {
        if player == nil { loadCurrent() }
        player?.play()
        isPlaying = player?.isPlaying ?? false
        refreshNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        refreshNowPlaying()
    }

    func next() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        loadCurrent(); play()
    }

    func previous() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        loadCurrent(); play()
    }

    // MARK: - Private

    private func loadCurrent() {
        guard let url = currentURL else { player = nil; nowPlaying = nil; onChange?(); return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        refreshNowPlaying()
    }

    private func refreshNowPlaying() {
        guard let url = currentURL else { nowPlaying = nil; onChange?(); return }
        let title = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent().lastPathComponent
        nowPlaying = NowPlaying(title: title, artist: folder, isPlaying: isPlaying)
        onChange?()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.next() }
    }

    // MARK: - File picking & USB detection

    /// Presents an open panel for audio files, defaulting to a USB volume if
    /// one is mounted. Returns selected URLs (empty if cancelled).
    static func pickAudioFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Add"
        panel.message = "Choose audio files to play"
        if let usb = usbVolumeURL() { panel.directoryURL = usb }
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// The first mounted removable/ejectable (USB) volume, if any.
    static func usbVolumeURL() -> URL? {
        let keys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeIsEjectableKey]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.first { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            return (v?.volumeIsRemovable ?? false) || (v?.volumeIsEjectable ?? false)
        }
    }

    static var usbConnected: Bool { usbVolumeURL() != nil }
}
