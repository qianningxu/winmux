import AppKit
import SwiftUI

var usesNativeLiquidGlass: Bool {
    if #available(macOS 26.0, *) {
        true
    } else {
        false
    }
}

@ViewBuilder
func liquidGlassBackground<S: Shape, Fallback: View>(
    in shape: S,
    isInteractive: Bool = true,
    @ViewBuilder fallback: () -> Fallback,
) -> some View {
    if #available(macOS 26.0, *) {
        Color.clear
            .glassEffect(.regular.interactive(isInteractive), in: shape)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    } else {
        fallback()
    }
}

struct LiquidGlassSurface<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    var tint: Color = Color(nsColor: .controlAccentColor)
    var tintOpacity: Double = 0.12
    var scrimOpacity: Double = 0.22
    var highlightOpacity: Double = 0.12
    var borderOpacity: Double = 0.18
    var glowOpacity: Double = 0
    var glowRadius: CGFloat = 0
    var lineWidth: CGFloat = 0.7
    var isInteractive: Bool = true
    var usesEvenOddFill: Bool = false

    var body: some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        ZStack {
            liquidGlassBackground(in: shape, isInteractive: isInteractive) {
                shape.fill(.ultraThinMaterial, style: fillStyle)
                    .environment(\.colorScheme, palette.materialFallbackColorScheme)
            }
            shape
                .fill(palette.background(scrimOpacity), style: fillStyle)
            shape
                .fill(tint.opacity(tintOpacity), style: fillStyle)
                .blendMode(palette.isDark ? .overlay : .multiply)
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            palette.foreground(highlightOpacity),
                            palette.foreground(highlightOpacity * 0.25),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                    style: fillStyle,
                )
                .blendMode(.screen)
            shape
                .stroke(palette.contrastingFill(darkOpacity: borderOpacity, lightOpacity: borderOpacity * 0.9), lineWidth: lineWidth)
        }
        .compositingGroup()
        .shadow(color: tint.opacity(glowOpacity), radius: glowRadius)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var fillStyle: FillStyle {
        FillStyle(eoFill: usesEvenOddFill)
    }
}
