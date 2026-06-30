import SwiftUI

extension WorkspaceSidebarBatterySnapshot {
    var tintColor: Color {
        switch state {
            case .charging:
                return Color(hue: 0.38, saturation: 0.28, brightness: 0.78)
            case .ac:
                return Color(hue: 0.38, saturation: 0.28, brightness: 0.78)
            case .discharging:
                return Color(hue: 0.10, saturation: 0.30, brightness: 0.82)
            case .unavailable:
                return winMuxOverlayForeground(0.45)
        }
    }
}

extension WorkspaceSidebarAudioSnapshot {
    var tintColor: Color {
        isMuted ? winMuxOverlayForeground(0.45) : Color(hue: 0.38, saturation: 0.28, brightness: 0.78)
    }
}

extension WorkspaceSidebarNetworkSnapshot {
    var tintColor: Color {
        interfaceName == nil ? winMuxOverlayForeground(0.45) : Color(hue: 0.58, saturation: 0.25, brightness: 0.78)
    }
}
