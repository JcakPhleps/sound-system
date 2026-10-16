import AppKit
import CoreServices
import Observation

enum PermissionStatus: Sendable {
    case granted, denied, undetermined, notRunning

    var label: String {
        switch self {
        case .granted: return "Allowed"
        case .denied: return "Denied"
        case .undetermined: return "Not asked"
        case .notRunning: return "App not open"
        }
    }

    var symbolName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .undetermined: return "questionmark.circle"
        case .notRunning: return "moon.zzz"
        }
    }
}

/// Reports Automation (Apple Events) permission for the controllable apps and
/// tracks first-run completion. The prompt itself is triggered lazily the first
/// time the user drives a control; this manager surfaces status and a shortcut
/// to the relevant System Settings pane.
@MainActor
@Observable
final class PermissionsManager {
    private(set) var musicStatus: PermissionStatus = .undetermined
    private(set) var spotifyStatus: PermissionStatus = .undetermined

    var hasCompletedFirstRun: Bool {
        get { UserDefaults.standard.bool(forKey: Self.firstRunKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.firstRunKey) }
    }

    private static let firstRunKey = "hasCompletedFirstRun"

    func refresh() {
        musicStatus = automationStatus(for: .appleMusic)
        spotifyStatus = automationStatus(for: .spotify)
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Non-intrusive probe (never prompts) of whether we may automate `source`.
    private func automationStatus(for source: PlaybackSource) -> PermissionStatus {
        guard let bundleID = source.bundleID else { return .granted }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .undetermined }
        let status = AEDeterminePermissionToAutomateTarget(
            desc, typeWildCard, typeWildCard, false)
        switch status {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .undetermined
        case OSStatus(procNotFound):
            return .notRunning
        default:
            return .undetermined
        }
    }
}
