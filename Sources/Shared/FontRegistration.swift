import CoreText
import Foundation

/// Registers the bundled VT323 pixel font. Called from each app's init so both
/// Conductor Pro (Mac) and Conductor Lite (iOS) get the retro font.
enum FontRegistration {
    static func registerVT323() {
        if let url = Bundle.main.url(forResource: "VT323-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
