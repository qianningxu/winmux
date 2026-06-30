import SwiftUI

struct WorkspaceSidebarStatusCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
            .fill(palette.contrastingFill(darkOpacity: 0.06, lightOpacity: 0.055))
            .overlay {
                RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
                    .strokeBorder(palette.contrastingFill(darkOpacity: 0.08, lightOpacity: 0.10), lineWidth: 0.5)
            }
    }
}
