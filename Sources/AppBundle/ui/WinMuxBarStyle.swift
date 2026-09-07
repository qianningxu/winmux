import SwiftUI

/// Shared visual rules for the tab bar, widget bar, and stack tabs.
enum WinMuxBarStyle {
    static let cornerRadius = standardGap * 4
    static let contentInset = standardGap * 2
    static let iconSpacing = standardGap * 1.5
    static let strokeWidth = standardGap * 0.25
    static let fontSize: CGFloat = 12.5
}

struct WinMuxBarDivider: View {
    let height: CGFloat
    let palette: WinMuxOverlayPalette

    var body: some View {
        Rectangle()
            .fill(palette.color(.gray, .color5))
            .frame(width: WinMuxBarStyle.strokeWidth, height: height)
            .allowsHitTesting(false)
    }
}

extension View {
    func winMuxBarSurface(_ palette: WinMuxOverlayPalette, joinedToWindow: Bool = false, cornerStyle: RoundedCornerStyle = .continuous) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: WinMuxBarStyle.cornerRadius,
            bottomLeadingRadius: joinedToWindow ? 0 : WinMuxBarStyle.cornerRadius,
            bottomTrailingRadius: joinedToWindow ? 0 : WinMuxBarStyle.cornerRadius,
            topTrailingRadius: WinMuxBarStyle.cornerRadius,
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
