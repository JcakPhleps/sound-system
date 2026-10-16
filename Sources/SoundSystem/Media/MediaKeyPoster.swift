import AppKit

/// Posts system media keys (play/pause, next, previous) to whatever app has
/// media focus. Blunt but dependency-free; requires the app to be unsandboxed.
@MainActor
enum MediaKeyPoster {
    // From IOKit `ev_keymap.h`.
    private static let playKey: Int32 = 16      // NX_KEYTYPE_PLAY
    private static let nextKey: Int32 = 17      // NX_KEYTYPE_NEXT
    private static let previousKey: Int32 = 18  // NX_KEYTYPE_PREVIOUS

    static func post(_ command: TransportCommand) {
        let key: Int32
        switch command {
        case .playPause: key = playKey
        case .next: key = nextKey
        case .previous: key = previousKey
        }
        sendKey(key, down: true)
        sendKey(key, down: false)
    }

    private static func sendKey(_ keyCode: Int32, down: Bool) {
        let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xA00)
                                                 : NSEvent.ModifierFlags(rawValue: 0xB00)
        let data1 = Int((keyCode << 16) | ((down ? 0xA : 0xB) << 8))
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,               // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
