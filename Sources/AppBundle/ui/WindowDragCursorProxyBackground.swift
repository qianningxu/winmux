import SwiftUI

struct WindowDragCursorProxyBackground: View {
    var isGroup: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
            .fill(isGroup
                ? palette.contrastingFill(darkOpacity: 0.14, lightOpacity: 0.10)
                : palette.contrastingFill(darkOpacity: 0.085, lightOpacity: 0.075)
            )
            .overlay {
                RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                    .strokeBorder(palette.contrastingFill(darkOpacity: 0.12, lightOpacity: 0.14), lineWidth: 0.7)
            }
            .shadow(color: palette.shadow(0.18, lightOpacity: 0.12), radius: 6, y: 2)
    }
}
