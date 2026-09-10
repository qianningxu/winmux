import SwiftUI

struct WindowTabGroupFrameView: View {
    let strip: WindowTabStripViewModel
    let groupSize: CGSize
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        let radius = strip.activeWindowCornerRadius + WinMuxSpacing.compact
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: WinMuxBarStyle.cornerRadius,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: WinMuxBarStyle.cornerRadius,
            style: .circular)
        shape
            .fill(palette.color(.gray, .color3))
            .overlay {
                shape.strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
            }
            .frame(width: groupSize.width, height: groupSize.height)
            .allowsHitTesting(false)
            .accessibilityLabel("Stacked window frame")
    }
}
