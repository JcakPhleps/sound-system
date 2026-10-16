import SwiftUI

struct OutputDevicePicker: View {
    @Environment(\.theme) private var theme
    @Environment(AudioDeviceManager.self) private var deviceManager

    var body: some View {
        MetalPanel(title: "Speakers / Output") {
            VStack(spacing: 6) {
                if deviceManager.devices.isEmpty {
                    Text(theme.text("No output devices"))
                        .font(theme.font(10))
                        .foregroundStyle(theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(deviceManager.devices) { device in
                    RetroSelectButton(
                        title: "\(device.name) · \(device.transport.label)",
                        systemImage: device.transport.symbolName,
                        isOn: device.id == deviceManager.currentDefaultDeviceID,
                        ledColor: theme.accentSecondary
                    ) {
                        deviceManager.selectDevice(device)
                    }
                }
            }
        }
    }
}
