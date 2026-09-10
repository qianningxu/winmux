import SwiftUI

/// Shared visual rules for project tabs, workspace tabs, and the widget bar.
enum WinMuxBarStyle {
    static let glassTintOpacity = 0.42
    static let glassBarOpacity = 0.22
    static let glassSelectionOpacity = 0.72

    static let cornerRadius = standardGap * 4
    static let topBarCornerRadius = standardGap * 4
    static let topBarSurfaceCornerRadius = standardGap * 4
    static let innerSpacing = standardGap * 0.75
    // The outer bar sits 3pt beyond its 16pt tabs, so add that inset to keep
    // the nested continuous curves concentric.
    static let workspaceTabBarCornerRadius = cornerRadius + innerSpacing
    static let containerInset = WinMuxSpacing.comfortable
    static let topBarContentInset = WinMuxSpacing.comfortable
    static let contentInset = innerSpacing * 4
    static let iconSpacing = innerSpacing
    static let strokeWidth = standardGap * 0.25
    static let fontSize: CGFloat = 14
    static let maximumTabWidth = standardGap * 50
    static let projectTabsBarOuterInset = WinMuxSpacing.comfortable
    static let projectTabsBarSurfaceHeight = standardGap * 8 + innerSpacing * 2
    static let projectBarHeight = projectTabsBarSurfaceHeight + projectTabsBarOuterInset
    static let workspaceBarHeight = projectTabsBarSurfaceHeight
}

struct WinMuxBarDivider: View {
    let height: CGFloat
    let palette: WinMuxOverlayPalette

    var body: some View {
        Rectangle()
            .fill(palette.color(palette.activeGeistFamily, .color6).opacity(0.5))
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
            .background(palette.color(palette.activeGeistFamily, .color3))
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(palette.color(palette.activeGeistFamily, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
                    .allowsHitTesting(false)
            }
    }

    func winMuxBarSegment(_ palette: WinMuxOverlayPalette, isSelected: Bool, isHovered: Bool) -> some View {
        background {
            if isSelected {
                Rectangle().fill(palette.geistBackground(.primary))
            } else if isHovered {
                Rectangle().fill(palette.color(palette.activeGeistFamily, .color2))
            }
        }
    }
}

/// Workspace chrome shares the project frame's native glass backing.
/// Avoid an opaque surface or a second blur layer over that material.
struct WinMuxWorkspaceGlassBackground: View {
    let palette: WinMuxOverlayPalette
    var isSelected = false
    var isHovered = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let step: GeistColorStep = isSelected ? .color3 : (isHovered ? .color2 : .color1)
        palette.color(palette.activeGeistFamily, step)
            .opacity(reduceTransparency ? 1 : (isSelected ? WinMuxBarStyle.glassSelectionOpacity : WinMuxBarStyle.glassBarOpacity))
    }
}
