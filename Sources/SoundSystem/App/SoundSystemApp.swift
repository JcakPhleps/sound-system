import SwiftUI

@main
struct SoundSystemApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistration.registerVT323()
    }

    var body: some Scene {
        Window("Conductor Pro", id: "main") {
            RootView()
                .environment(appDelegate.deviceManager)
                .environment(appDelegate.volumeController)
                .environment(appDelegate.transportController)
                .environment(appDelegate.eqController)
                .environment(appDelegate.permissions)
                .environment(appDelegate.themeManager)
                .environment(appDelegate.spatialController)
        }
        .windowResizability(.contentSize)
        .commands {
            // Trim the default menus down to the essentials for a single-window app.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {}
        }
    }
}
