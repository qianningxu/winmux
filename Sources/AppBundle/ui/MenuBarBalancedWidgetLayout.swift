import SwiftUI

/// Pins Period to the leading edge and the remaining widgets to the trailing
/// edge. If the two sides no longer fit, every widget shrinks proportionally.
struct MenuBarBalancedWidgetLayout: SwiftUI.Layout {
    let separation: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: proposal.width ?? sizes.reduce(0) { $0 + $1.width } + (subviews.count > 1 ? separation : 0),
            height: proposal.height ?? sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let idealWidths = subviews.map { $0.sizeThatFits(.unspecified).width }
        let placements = menuBarBalancedWidgetPlacements(
            idealWidths,
            availableWidth: bounds.width,
            separation: separation
        )
        for (subview, placement) in zip(subviews, placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: placement.width, height: bounds.height)
            )
        }
    }
}

struct MenuBarWidgetPlacement: Equatable {
    let x: CGFloat
    let width: CGFloat
}

func menuBarBalancedWidgetPlacements(
    _ idealWidths: [CGFloat],
    availableWidth: CGFloat,
    separation: CGFloat
) -> [MenuBarWidgetPlacement] {
    guard !idealWidths.isEmpty else { return [] }
    let widths = idealWidths.map { $0.isFinite ? max(0, $0) : 0 }
    let available = max(0, availableWidth)
    let gap = widths.count > 1 ? max(0, separation) : 0
    let contentWidth = max(0, available - gap)
    let total = widths.reduce(0, +)
    let resolvedWidths = total > contentWidth && total > 0
        ? widths.map { contentWidth * $0 / total }
        : widths

    if resolvedWidths.count == 1 {
        return [MenuBarWidgetPlacement(x: 0, width: resolvedWidths[0])]
    }

    let trailingWidth = resolvedWidths.dropFirst().reduce(0, +)
    var trailingX = available - trailingWidth
    var result = [MenuBarWidgetPlacement(x: 0, width: resolvedWidths[0])]
    for width in resolvedWidths.dropFirst() {
        result.append(MenuBarWidgetPlacement(x: trailingX, width: width))
        trailingX += width
    }
    return result
}
