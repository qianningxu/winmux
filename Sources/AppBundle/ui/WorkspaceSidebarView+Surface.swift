import AppKit
import SwiftUI

extension WorkspaceSidebarView {
    var sidebarShape: some Shape {
        RoundedRectangle(cornerRadius: workspaceSidebarPanelRightCornerRadius, style: .continuous)
    }

    func sidebarSurface<S: Shape>(in shape: S) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        return ZStack {
            sidebarGlassBase(in: shape, palette: palette)
            shape.fill(palette.background(sidebarGlassScrimOpacity(for: palette)))
            shape.fill(sidebarGlassTint(for: palette).opacity(sidebarGlassTintOpacity(for: palette)))
                .blendMode(palette.isDark ? .plusLighter : .multiply)
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: palette.foreground(sidebarGlassHighlightPeak(for: palette)), location: 0),
                        .init(color: palette.foreground(sidebarGlassHighlightPeak(for: palette) * 0.25), location: 0.12),
                        .init(color: Color.clear, location: 0.45),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)
            shape.stroke(palette.contrastingFill(darkOpacity: sidebarGlassBorderOpacity(for: palette)), lineWidth: 0.5)
        }
        .compositingGroup()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sidebarGlassBase<S: Shape>(in shape: S, palette: WinMuxOverlayPalette) -> some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.interactive(false), in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
                .environment(\.colorScheme, palette.materialFallbackColorScheme)
        }
    }

    func sidebarSwipeCaptureOverlay(expansionProgress: CGFloat) -> some View {
        WorkspaceSidebarProjectSwipeScrollCapture(
            isEnabled: workspaceSidebarProjectSwipeCaptureIsEnabled(
                projectsEnabled: projectsAreEnabled(),
                projectCount: snapshot.projects.count
            ),
            onChanged: { horizontalTranslation, verticalTranslation in
                handleProjectSwipeChanged(
                    horizontalTranslation: horizontalTranslation,
                    verticalTranslation: verticalTranslation,
                    expansionProgress: expansionProgress,
                )
            },
            onEnded: { horizontalTranslation, verticalTranslation in
                handleProjectSwipeEnded(
                    horizontalTranslation: horizontalTranslation,
                    verticalTranslation: verticalTranslation,
                    expansionProgress: expansionProgress,
                )
            },
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

func workspaceSidebarProjectSwipeCaptureIsEnabled(projectsEnabled: Bool, projectCount: Int) -> Bool {
    projectsEnabled && projectCount > 0
}

private func sidebarGlassTint(for palette: WinMuxOverlayPalette) -> Color {
    palette.muted()
}

private func sidebarGlassTintOpacity(for palette: WinMuxOverlayPalette) -> Double {
    palette.isDark ? 0.20 : 0.18
}

private func sidebarGlassScrimOpacity(for palette: WinMuxOverlayPalette) -> Double {
    palette.isDark ? 0.38 : 0.36
}

private func sidebarGlassHighlightPeak(for palette: WinMuxOverlayPalette) -> Double {
    palette.isDark ? 0.08 : 0.18
}

private func sidebarGlassBorderOpacity(for palette: WinMuxOverlayPalette) -> Double {
    palette.isDark ? 0.10 : 0.14
}

private func sideAreaBackground(for palette: WinMuxOverlayPalette) -> Color {
    palette.muted()
}
