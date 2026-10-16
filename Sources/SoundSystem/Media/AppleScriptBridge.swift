import AppKit

/// Talks to Music / Spotify over Apple Events for now-playing state and
/// transport commands. NSAppleScript is main-thread affine, so this is
/// `@MainActor`. First use of each target triggers the Automation TCC prompt.
@MainActor
enum AppleScriptBridge {

    static func isRunning(_ source: PlaybackSource) -> Bool {
        guard let bundleID = source.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Reads now-playing state. Returns `nil` if the app isn't running or the
    /// script fails (e.g. permission not yet granted).
    static func nowPlaying(_ source: PlaybackSource) -> NowPlaying? {
        guard let app = source.scriptAppName, isRunning(source) else { return nil }
        let script = """
        tell application "\(app)"
        	set s to "stopped"
        	try
        		set s to (player state as text)
        	end try
        	set n to ""
        	set a to ""
        	try
        		set n to (name of current track as text)
        		set a to (artist of current track as text)
        	end try
        	return s & tab & n & tab & a
        end tell
        """
        guard let output = run(script) else { return nil }
        let parts = output.components(separatedBy: "\t")
        let state = parts.indices.contains(0) ? parts[0] : "stopped"
        let title = parts.indices.contains(1) ? parts[1] : ""
        let artist = parts.indices.contains(2) ? parts[2] : ""
        return NowPlaying(title: title, artist: artist, isPlaying: state == "playing")
    }

    /// Sends a transport command to `source`. No-op if the app isn't running so
    /// we never silently launch it.
    static func send(_ command: TransportCommand, to source: PlaybackSource) {
        guard let app = source.scriptAppName, isRunning(source) else { return }
        let verb: String
        switch command {
        case .playPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        }
        _ = run("tell application \"\(app)\" to \(verb)")
    }

    @discardableResult
    private static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            NSLog("Sound System: AppleScript error: \(error)")
            return nil
        }
        return descriptor.stringValue
    }
}
