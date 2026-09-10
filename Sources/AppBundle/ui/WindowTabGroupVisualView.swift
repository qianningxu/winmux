import SwiftUI

struct WindowTabGroupVisualView: View {
    let strip: WindowTabStripViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: WinMuxSpacing.none) {
                RoundedRectangle(
                    cornerRadius: WinMuxBarStyle.workspaceTabBarCornerRadius,
                    style: .continuous
                )
                .fill(WinMuxOverlayPalette.current.color(.gray, .color5))
                .frame(
                    width: geometry.size.width,
                    height: min(WinMuxBarStyle.workspaceBarHeight, geometry.size.height)
                )

                Spacer(minLength: WinMuxSpacing.none)
            }
        }
            .allowsHitTesting(false)
    }
}
