import SwiftUI

struct WindowTabGroupFrameView: View {
    let strip: WindowTabStripViewModel
    let groupSize: CGSize
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        RoundedRectangle(cornerRadius: windowTabStripCornerRadius + windowTabGroupShellHorizontalInset(), style: .continuous)
            .fill(palette.color(.gray, .color8))
            .overlay {
                RoundedRectangle(cornerRadius: windowTabStripCornerRadius + windowTabGroupShellHorizontalInset(), style: .continuous)
                    .strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
            }
            .frame(width: groupSize.width, height: groupSize.height)
            .allowsHitTesting(false)
    }
}
