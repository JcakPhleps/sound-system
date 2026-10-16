import SwiftUI

@main
struct LiteApp: App {
    @State private var themeManager = ThemeManager()
    @State private var engine = LiteAudioEngine()

    init() { FontRegistration.registerVT323() }

    var body: some Scene {
        WindowGroup {
            LiteRootView()
                .environment(themeManager)
                .environment(engine)
        }
    }
}
