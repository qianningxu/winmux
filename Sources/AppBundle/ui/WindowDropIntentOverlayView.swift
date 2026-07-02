import SwiftUI

struct WindowDropIntentOverlayView: View {
    let model: WindowDropIntentOverlayModel

    @Environment(\.colorScheme) private var colorScheme

    private let borderLineWidth: CGFloat = 1
    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(gridBaseFill)

            inactiveCanvasFill

            if let projection = layoutProjection {
                displacedPaneView(projection.displaced)
                activePaneView(projection.active)
            } else {
                ForEach(localZones.filter { $0.zone == model.activeZone }) { zone in
                    activePaneView(zone.frame)
                }
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(gridOuterStroke, lineWidth: borderLineWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: model.targetFrame.width, height: model.targetFrame.height)
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat {
        model.cornerRadius ?? min(max(min(model.targetFrame.width, model.targetFrame.height) * 0.022, 12), 18)
    }

    private var localZones: [WindowIntentZone] {
        WindowIntentZoneBuilder.splitZones(in: Rect(
            topLeftX: 0,
            topLeftY: 0,
            width: model.targetFrame.width,
            height: model.targetFrame.height
        ))
    }

    private var layoutProjection: (active: Rect, displaced: Rect)? {
        guard let activeZone = model.activeZone,
              let position = activeZone.stackSplitPosition
        else { return nil }
        let frame = Rect(
            topLeftX: 0,
            topLeftY: 0,
            width: model.targetFrame.width,
            height: model.targetFrame.height
        )
        let active: Rect
        let displaced: Rect
        switch position {
            case .left:
                active = Rect(topLeftX: 0, topLeftY: 0, width: frame.width / 2, height: frame.height)
                displaced = Rect(topLeftX: frame.width / 2, topLeftY: 0, width: frame.width / 2, height: frame.height)
            case .right:
                active = Rect(topLeftX: frame.width / 2, topLeftY: 0, width: frame.width / 2, height: frame.height)
                displaced = Rect(topLeftX: 0, topLeftY: 0, width: frame.width / 2, height: frame.height)
            case .above:
                active = Rect(topLeftX: 0, topLeftY: 0, width: frame.width, height: frame.height / 2)
                displaced = Rect(topLeftX: 0, topLeftY: frame.height / 2, width: frame.width, height: frame.height / 2)
            case .below:
                active = Rect(topLeftX: 0, topLeftY: frame.height / 2, width: frame.width, height: frame.height / 2)
                displaced = Rect(topLeftX: 0, topLeftY: 0, width: frame.width, height: frame.height / 2)
        }
        guard active.width > 0, active.height > 0, displaced.width > 0, displaced.height > 0 else {
            return nil
        }
        return (active, displaced)
    }

    private func activePaneView(_ rect: Rect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: zoneCornerRadius(for: rect), style: .continuous)
                .fill(gridZoneFill)
                .overlay {
                    RoundedRectangle(cornerRadius: zoneCornerRadius(for: rect), style: .continuous)
                        .strokeBorder(activeZoneStroke, lineWidth: borderLineWidth)
                }
                .shadow(
                    color: palette.shadow(0.12, lightOpacity: 0.05),
                    radius: 10,
                    x: 0,
                    y: 2
                )
            if let activeZone = model.activeZone,
               let name = symbolName(for: activeZone)
            {
                Image(systemName: name)
                    .font(.system(size: iconSize(for: rect), weight: .semibold))
                    .foregroundStyle(gridSymbol)
            }
        }
        .padding(6)
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.center.x, y: rect.center.y)
    }

    private func displacedPaneView(_ rect: Rect) -> some View {
        RoundedRectangle(cornerRadius: zoneCornerRadius(for: rect), style: .continuous)
            .fill(displacedZoneFill)
            .overlay {
                RoundedRectangle(cornerRadius: zoneCornerRadius(for: rect), style: .continuous)
                    .strokeBorder(displacedZoneStroke, lineWidth: 0.8)
            }
            .padding(6)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.center.x, y: rect.center.y)
    }

    private func symbolName(for zone: WindowDropZone) -> String? {
        switch zone {
            case .left:
                "arrow.left"
            case .right:
                "arrow.right"
            case .top:
                "arrow.up"
            case .bottom:
                "arrow.down"
            case .middle:
                "arrow.left.arrow.right"
            case .tab:
                "rectangle.3.group"
        }
    }

    private func iconSize(for frame: Rect) -> CGFloat {
        min(max(min(frame.width, frame.height) * 0.45, 14), 48)
    }

    private var gridBaseFill: Color {
        palette.dropIntentBackdrop()
    }

    private var inactiveCanvasFill: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.dropIntentInactivePane())
    }

    private var gridOuterStroke: Color {
        palette.gray500(palette.isDark ? 0.44 : 0.52)
    }

    private var gridZoneFill: Color {
        palette.dropIntentSplitPlacementPane()
    }

    private var displacedZoneFill: Color {
        palette.dropIntentSplitExistingPane()
    }

    private var displacedZoneStroke: Color {
        palette.gray500(palette.isDark ? 0.32 : 0.38)
    }

    private var activeZoneStroke: Color {
        palette.gray500(palette.isDark ? 0.78 : 0.88)
    }

    private var gridSymbol: Color {
        palette.foreground(0.82)
    }

    private func zoneCornerRadius(for frame: Rect) -> CGFloat {
        return min(max(min(frame.width, frame.height) * 0.06, 8), 14)
    }
}
