import Foundation

/// A controllable playback source. `.system` targets whatever is currently
/// playing via synthesized media keys; the app-specific cases talk directly to
/// Music / Spotify over Apple Events.
enum PlaybackSource: String, CaseIterable, Identifiable, Sendable {
    case system
    case appleMusic
    case spotify
    case usb

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .usb: return "USB"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "waveform"
        case .appleMusic: return "music.note"
        case .spotify: return "music.note.list"
        case .usb: return "externaldrive.connected.to.line.below"
        }
    }

    /// Bundle identifier for the backing app, or `nil` for `.system`/`.usb`.
    var bundleID: String? {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .system, .usb: return nil
        }
    }

    /// The AppleScript application name used in `tell application "…"`.
    var scriptAppName: String? {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        case .system, .usb: return nil
        }
    }
}

/// A snapshot of what's currently playing.
struct NowPlaying: Equatable, Sendable {
    var title: String
    var artist: String
    var isPlaying: Bool

    var subtitle: String { artist.isEmpty ? "" : artist }
}

enum TransportCommand: Sendable {
    case playPause, next, previous
}
