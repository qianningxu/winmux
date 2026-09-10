import SwiftUI

struct WindowTabGroupFrameView: View {
    let strip: WindowTabStripViewModel
    let groupSize: CGSize
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        Rectangle()
            .fill(palette.color(.gray, .color3))
            .frame(width: groupSize.width, height: groupSize.height)
            .allowsHitTesting(false)
            .accessibilityLabel("Workspace frame")
    }
}
