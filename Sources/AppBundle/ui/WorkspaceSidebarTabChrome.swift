import SwiftUI

extension View {
    func workspaceSidebarIconStroke(
        _ palette: WinMuxOverlayPalette,
        cornerRadius: CGFloat = 4,
        isActive: Bool = false
    ) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(palette.iconStroke(active: isActive), lineWidth: 0.65)
        }
    }
}
