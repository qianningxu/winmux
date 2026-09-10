import SwiftUI

struct WindowTabGroupVisualView: View {
    let strip: WindowTabStripViewModel

    @ObservedObject private var trayModel = TrayMenuModel.shared
    private var palette: WinMuxOverlayPalette { trayModel.projectPalette(workspaceName: strip.workspaceName) }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: WinMuxSpacing.none) {
                WinMuxWorkspaceGlassBackground(palette: palette)
                .clipShape(RoundedRectangle(
                    cornerRadius: WinMuxBarStyle.workspaceTabBarCornerRadius,
                    style: .continuous
                ))
                .frame(
                    width: max(geometry.size.width - windowTabGroupShellHorizontalInset() * 2, 0),
                    height: min(WinMuxBarStyle.workspaceBarHeight, geometry.size.height)
                )
                .padding(.top, windowTabBarOuterInset())

                Spacer(minLength: WinMuxSpacing.none)
            }
        }
            .allowsHitTesting(false)
    }
}
