import SwiftUI

/// Keeps Period and Projects together on the leading side while the remaining
/// status widgets stay on the trailing side.
struct MenuBarProjectLeadingWidgetLayout: SwiftUI.Layout {
    let separation: CGFloat
    let cameraSafeEdges: ClosedRange<CGFloat>?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: proposal.width ?? sizes.reduce(0) { $0 + $1.width }
                + CGFloat(max(subviews.count - 1, 0)) * separation,
            height: proposal.height ?? sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = menuBarProjectLeadingWidgetPlacements(
            subviews.map { $0.sizeThatFits(.unspecified).width },
            availableWidth: bounds.width,
            separation: separation,
            cameraSafeEdges: cameraSafeEdges
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

func menuBarProjectLeadingWidgetPlacements(
    _ idealWidths: [CGFloat],
    availableWidth: CGFloat,
    separation: CGFloat,
    cameraSafeEdges: ClosedRange<CGFloat>? = nil
) -> [MenuBarWidgetPlacement] {
    guard !idealWidths.isEmpty else { return [] }
    let widths = idealWidths.map { $0.isFinite ? max(0, $0) : 0 }
    let available = max(0, availableWidth)
    let gap = max(0, separation)
    let leadingCount = min(2, widths.count)
    var leading = Array(widths.prefix(leadingCount))
    var trailing = Array(widths.dropFirst(leadingCount))

    if let cameraSafeEdges {
        leading = menuBarWidthsFitting(leading, available: max(0, cameraSafeEdges.lowerBound), gap: gap)
        trailing = menuBarWidthsFitting(
            trailing,
            available: max(0, available - cameraSafeEdges.upperBound),
            gap: gap
        )
    } else {
        let fitted = menuBarWidthsFitting(widths, available: available, gap: gap)
        leading = Array(fitted.prefix(leadingCount))
        trailing = Array(fitted.dropFirst(leadingCount))
    }
    var leadingX: CGFloat = 0
    var trailingX = available - trailing.reduce(0, +) - CGFloat(max(trailing.count - 1, 0)) * gap
    var result: [MenuBarWidgetPlacement] = []

    for width in leading {
        result.append(MenuBarWidgetPlacement(x: leadingX, width: width))
        leadingX += width + gap
    }
    for width in trailing {
        result.append(MenuBarWidgetPlacement(x: trailingX, width: width))
        trailingX += width + gap
    }
    return result
}

private func menuBarWidthsFitting(_ widths: [CGFloat], available: CGFloat, gap: CGFloat) -> [CGFloat] {
    guard !widths.isEmpty else { return [] }
    let contentAvailable = max(0, available - CGFloat(max(widths.count - 1, 0)) * gap)
    let total = widths.reduce(0, +)
    guard total > contentAvailable, total > 0 else { return widths }
    return widths.map { contentAvailable * $0 / total }
}
