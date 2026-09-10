import SwiftUI

/// Shared visual rules for project tabs, workspace tabs, and the widget bar.
enum WinMuxBarStyle {
    static let cornerRadius = standardGap * 4
    static let topBarCornerRadius = standardGap * 4
    static let topBarSurfaceCornerRadius = standardGap * 4
    static let workspaceTabBarCornerRadius = standardGap * 4
    static let containerInset = standardGap
    static let topBarContentInset = standardGap
    static let contentInset = standardGap * 3.5
    static let iconSpacing = standardGap * 2
    static let strokeWidth = standardGap * 0.25
    static let fontSize: CGFloat = 14
    static let maximumTabWidth = standardGap * 50
    static let projectBarHeight = standardGap * 9
    static let workspaceBarHeight = standardGap * 9
}

struct WinMuxBarDivider: View {
    let height: CGFloat
    let palette: WinMuxOverlayPalette

    var body: some View {
        Rectangle()
            .fill(palette.color(.gray, .color6).opacity(0.5))
            .frame(width: WinMuxBarStyle.strokeWidth, height: height)
            .allowsHitTesting(false)
    }
}

extension View {
    func winMuxBarSurface(
        _ palette: WinMuxOverlayPalette,
        joinedToWindow: Bool = false,
        joinsLeadingBar: Bool = false,
        joinsTrailingBar: Bool = false,
        cornerStyle: RoundedCornerStyle = .continuous,
        cornerRadius: CGFloat = WinMuxBarStyle.cornerRadius
    ) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: joinsLeadingBar ? 0 : cornerRadius,
            bottomLeadingRadius: joinedToWindow || joinsLeadingBar ? 0 : cornerRadius,
            bottomTrailingRadius: joinedToWindow || joinsTrailingBar ? 0 : cornerRadius,
            topTrailingRadius: joinsTrailingBar ? 0 : cornerRadius,
            style: cornerStyle
        )
        return self
            .background(palette.color(.gray, .color3))
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
                    .allowsHitTesting(false)
            }
    }

    func winMuxBarSegment(_ palette: WinMuxOverlayPalette, isSelected: Bool, isHovered: Bool) -> some View {
        background {
            if isSelected {
                Rectangle().fill(palette.geistBackground(.primary))
            } else if isHovered {
                Rectangle().fill(palette.color(.gray, .color2))
            }
        }
    }
}
