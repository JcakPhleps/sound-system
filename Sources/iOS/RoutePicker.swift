import AVKit
import SwiftUI

/// Wraps the system AirPlay/Bluetooth route picker (the only iOS-sanctioned way
/// to change audio output).
struct RoutePicker: UIViewRepresentable {
    var tint: Color

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.backgroundColor = .clear
        view.activeTintColor = UIColor(tint)
        view.tintColor = UIColor(tint)
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = UIColor(tint)
        view.activeTintColor = UIColor(tint)
    }
}
