import SwiftUI

struct SourcePickerView: View {
    @Environment(TransportController.self) private var transport

    var body: some View {
        MetalPanel(title: "Source") {
            VStack(spacing: 6) {
                ForEach(PlaybackSource.allCases) { source in
                    RetroSelectButton(
                        title: source.displayName,
                        systemImage: source.symbolName,
                        isOn: transport.currentSource == source
                    ) {
                        transport.setSource(source)
                    }
                }
            }
        }
    }
}
